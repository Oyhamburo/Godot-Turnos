extends Node3D
class_name FloatingHUD
##
## HUD flotante 3D profesional: SubViewport + Sprite3D.
## Barra HP con ghost bar, gradiente de color, shake, fade al morir,
## texto HP numérico, nombre y borde por equipo.
## Conectado a UnitStats.hp_changed.
##

@onready var sprite: Sprite3D = $Sprite3D
@onready var viewport: SubViewport = $SubViewport
@onready var border: PanelContainer = $SubViewport/Border
@onready var name_label: Label = $SubViewport/Border/VBox/NameLabel
@onready var bar_container: Control = $SubViewport/Border/VBox/BarContainer
@onready var bar_bg: ColorRect = $SubViewport/Border/VBox/BarContainer/BarBackground
@onready var ghost_fill: ColorRect = $SubViewport/Border/VBox/BarContainer/GhostFill
@onready var hp_fill: ColorRect = $SubViewport/Border/VBox/BarContainer/HPFill
@onready var hp_text: Label = $SubViewport/Border/VBox/BarContainer/HPText
@onready var status_hbox: HBoxContainer = $SubViewport/Border/VBox/StatusIcons

var _stats: UnitStats
var _current_hp: int = 0
var _max_hp: int = 0
var _border_style: StyleBoxFlat

var _hp_tween: Tween
var _ghost_tween: Tween
var _shake_tween: Tween

## Labels de emojis de efectos de estado activos. Clave: StatusEffect.Tipo → Label
var _status_labels: Dictionary = {}

# Dimensiones internas de la barra (viewport 200px - 2px borde cada lado)
const BAR_WIDTH: float = 196.0

# Colores HP
const COLOR_HIGH: Color = Color(0.2, 0.85, 0.2, 1.0)     # Verde
const COLOR_MID: Color = Color(0.95, 0.85, 0.1, 1.0)      # Amarillo
const COLOR_LOW: Color = Color(0.9, 0.15, 0.1, 1.0)       # Rojo
const THRESHOLD_MID: float = 0.5
const THRESHOLD_LOW: float = 0.25

# Ghost bar
const COLOR_GHOST: Color = Color(1.0, 1.0, 1.0, 0.3)

# Colores por equipo (borde)
const TEAM_PLAYER_COLOR: Color = Color(0.3, 0.5, 1.0, 0.8)
const TEAM_ENEMY_COLOR: Color = Color(1.0, 0.3, 0.3, 0.8)

# Tiempos de animación
const TWEEN_HP_DURATION: float = 0.35
const TWEEN_GHOST_DELAY: float = 0.5
const TWEEN_GHOST_DURATION: float = 0.6
const TWEEN_FADE_DURATION: float = 0.8
const SHAKE_MAGNITUDE: float = 3.0
const SHAKE_DURATION: float = 0.3


func _ready() -> void:
	sprite.texture = viewport.get_texture()


func setup(stats: UnitStats, unit_name: String = "", team: int = 0) -> void:
	_stats = stats
	if not _stats:
		return

	_stats.hp_changed.connect(_on_hp_changed)
	_current_hp = _stats.hp
	_max_hp = _stats.max_hp

	# Nombre
	if unit_name != "":
		name_label.text = unit_name
	else:
		_set_name_from_parent()

	# Borde por equipo
	_border_style = border.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	if _border_style:
		_border_style.border_color = TEAM_PLAYER_COLOR if team == 0 else TEAM_ENEMY_COLOR
		border.add_theme_stylebox_override("panel", _border_style)

	# Inicializar barras
	var ratio: float = clampf(float(_current_hp) / float(maxi(_max_hp, 1)), 0.0, 1.0)
	var width: float = BAR_WIDTH * ratio
	hp_fill.size.x = width
	ghost_fill.size.x = width
	hp_fill.color = _color_for_ratio(ratio)
	ghost_fill.color = COLOR_GHOST
	hp_text.text = "%d/%d" % [_current_hp, _max_hp]

	_request_render()


func _set_name_from_parent() -> void:
	var p: Node = get_parent()
	if p == null:
		name_label.text = "Unit"
		return
	if "display_name" in p:
		name_label.text = str(p.get("display_name"))
	else:
		name_label.text = p.name


func _on_hp_changed(current: int, max_val: int) -> void:
	if not hp_fill:
		return

	var old_hp := _current_hp
	_current_hp = current
	_max_hp = max_val

	var ratio: float = clampf(float(current) / float(maxi(max_val, 1)), 0.0, 1.0)
	var new_width: float = BAR_WIDTH * ratio
	var target_color: Color = _color_for_ratio(ratio)

	# Texto HP
	hp_text.text = "%d/%d" % [current, max_val]

	# Matar tweens anteriores
	if _hp_tween and _hp_tween.is_running():
		_hp_tween.kill()
	if _ghost_tween and _ghost_tween.is_running():
		_ghost_tween.kill()

	# Tween suave de la barra principal
	_hp_tween = create_tween()
	_hp_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_hp_tween.tween_property(hp_fill, "size:x", new_width, TWEEN_HP_DURATION)
	_hp_tween.parallel().tween_property(hp_fill, "color", target_color, TWEEN_HP_DURATION)

	# Ghost bar: solo al recibir daño
	if current < old_hp:
		_ghost_tween = create_tween()
		_ghost_tween.tween_interval(TWEEN_GHOST_DELAY)
		_ghost_tween.tween_property(ghost_fill, "size:x", new_width, TWEEN_GHOST_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		# Shake al recibir daño
		_play_shake()
	else:
		# Curación: ghost se ajusta inmediatamente
		ghost_fill.size.x = new_width

	# Renderizar durante las animaciones
	_start_render_during_tweens()

	# Muerte: fade out
	if current <= 0:
		_play_fade_out()


func _color_for_ratio(ratio: float) -> Color:
	if ratio <= THRESHOLD_LOW:
		return COLOR_LOW
	elif ratio <= THRESHOLD_MID:
		var t: float = (ratio - THRESHOLD_LOW) / (THRESHOLD_MID - THRESHOLD_LOW)
		return COLOR_LOW.lerp(COLOR_MID, t)
	else:
		var t: float = (ratio - THRESHOLD_MID) / (1.0 - THRESHOLD_MID)
		return COLOR_MID.lerp(COLOR_HIGH, t)


func _play_shake() -> void:
	if _shake_tween and _shake_tween.is_running():
		_shake_tween.kill()
	bar_container.position = Vector2.ZERO

	_shake_tween = create_tween()
	var steps: int = 6
	var step_time: float = SHAKE_DURATION / float(steps)
	for i in range(steps):
		var decay: float = 1.0 - float(i) / float(steps)
		var offset_x: float = randf_range(-SHAKE_MAGNITUDE, SHAKE_MAGNITUDE) * decay
		var offset_y: float = randf_range(-SHAKE_MAGNITUDE * 0.5, SHAKE_MAGNITUDE * 0.5) * decay
		_shake_tween.tween_property(bar_container, "position", Vector2(offset_x, offset_y), step_time)
	_shake_tween.tween_property(bar_container, "position", Vector2.ZERO, step_time)


func _play_fade_out() -> void:
	var t := create_tween()
	t.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_property(sprite, "modulate:a", 0.0, TWEEN_FADE_DURATION)
	t.tween_callback(func(): visible = false)


func _request_render() -> void:
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE


func _start_render_during_tweens() -> void:
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var max_duration: float = maxf(TWEEN_HP_DURATION, TWEEN_GHOST_DELAY + TWEEN_GHOST_DURATION) + SHAKE_DURATION + 0.1
	get_tree().create_timer(max_duration).timeout.connect(
		func(): viewport.render_target_update_mode = SubViewport.UPDATE_ONCE,
		CONNECT_ONE_SHOT
	)


# ── STATUS EFFECTS: íconos emoji debajo de la barra de HP ──

## Conecta el StatusEffectManager para mostrar/ocultar emojis de estado.
## Llamar desde Unit._ready() después de add_floating_hud().
func conectar_efectos(manager: StatusEffectManager) -> void:
	if not manager:
		return
	manager.efecto_aplicado.connect(_on_efecto_aplicado)
	manager.efecto_removido.connect(_on_efecto_removido)


func _on_efecto_aplicado(efecto: StatusEffect) -> void:
	if not status_hbox:
		return
	# Si ya existe un label para este tipo, no duplicar
	if _status_labels.has(efecto.tipo):
		_request_render()
		return
	var lbl := Label.new()
	lbl.text = efecto.obtener_emoji()
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_hbox.add_child(lbl)
	_status_labels[efecto.tipo] = lbl
	_request_render()


func _on_efecto_removido(efecto: StatusEffect) -> void:
	if not status_hbox:
		return
	if _status_labels.has(efecto.tipo):
		var lbl: Label = _status_labels[efecto.tipo]
		if is_instance_valid(lbl):
			lbl.queue_free()
		_status_labels.erase(efecto.tipo)
		_request_render()
