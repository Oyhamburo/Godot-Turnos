extends CanvasLayer
class_name BattleHUD
##
## HUD de combate: timeline de turnos, menú de acciones, menú de ataques e ítems.
## Crea toda la UI por código para evitar problemas de escena/nodos.
##

signal action_selected(action: String)       # "attack", "move", "item", "equipo", "end_turn"
signal attack_selected(index: int)           # 0-3
signal item_selected(index: int)             # 0-2
signal back_from_attack()
signal back_from_item()
signal equip_weapon_requested(weapon: WeaponData, slot: int)  # slot: 0=derecha, 1=izquierda
signal unequip_weapon_requested(slot: int)
signal back_from_equipo()
signal return_to_main_menu()                 # emitida al pulsar "Menú Principal"
signal qte_completed(success: bool)          # true = perfect combo, false = fallo
signal def_qte_completed(success: bool)      # true = bloqueo exitoso, false = fallo

const _TurnSlotScene = preload("res://scenes/ui/TurnSlot.tscn")

var timeline_hbox: HBoxContainer
var turn_label: Label

var action_panel: PanelContainer
var attack_btn: Button
var move_btn: Button
var item_btn: Button
var equipo_btn: Button
var end_turn_btn: Button
var ap_label: Label
var sp_label: Label

## Panel de equipamiento personal (reemplaza al InventoryPanel en combate).
var equipo_panel: PersonalInventoryPanel = null
## El InventoryPanel legacy sigue disponible para compatibilidad con el sistema de armas.
var _legacy_inv_panel: InventoryPanel = null

var attack_panel: PanelContainer
var attack_btn_1: Button
var attack_btn_2: Button
var attack_btn_3: Button
var attack_btn_4: Button
var attack_back_btn: Button

var item_panel: PanelContainer
var item_back_btn: Button
var _item_buttons: Array[Button] = []   # botones dinámicos de pociones
var _item_vbox: VBoxContainer = null    # referencia al VBox del item_panel
var _root_control: Control = null       # referencia al control raíz para show_feedback

# ── Panel de resultado (victoria/derrota) ──
var _result_root: Control = null      # Control raíz semitransparente de fondo
var _detail_panel: PanelContainer = null   # Panel de detalles (oculto por defecto)

# ── Label de selección de objetivo ──
var _target_prompt_label: Label = null

# ── QTE (Quick Time Event) ──
var _qte_panel: PanelContainer = null
var _qte_key_boxes: Array[PanelContainer] = []
var _qte_key_labels: Array[Label] = []
var _qte_timer_bar: ProgressBar = null
var _qte_feedback_label: Label = null
var _qte_current_index: int = 0
var _qte_sequence: Array[String] = ["Q", "W", "E"]
var _qte_keycodes: Array[Key] = [KEY_Q, KEY_W, KEY_E]
var _qte_failed: bool = false
var _qte_active: bool = false
var _qte_timer: float = 0.0
var _qte_timeout: float = 1.0  # segundos por tecla

# ── QTE Defensivo (Escudo) ──
var _def_qte_panel: PanelContainer = null
var _def_qte_key_box: PanelContainer = null
var _def_qte_key_label: Label = null
var _def_qte_timer_bar: ProgressBar = null
var _def_qte_feedback_label: Label = null
var _def_qte_prompt_label: Label = null
var _def_qte_active: bool = false
var _def_qte_timer: float = 0.0
var _def_qte_timeout: float = 0.8  # ventana breve para bloquear


func _ready() -> void:
	layer = 10
	_build_ui()

	# Conectar botones del panel de acciones
	attack_btn.pressed.connect(func() -> void: _on_action("attack"))
	move_btn.pressed.connect(func() -> void: _on_action("move"))
	item_btn.pressed.connect(func() -> void: _on_action("item"))
	equipo_btn.pressed.connect(func() -> void: _on_action("equipo"))
	end_turn_btn.pressed.connect(func() -> void: _on_action("end_turn"))

	# Conectar botones de ataque
	attack_btn_1.pressed.connect(func() -> void: _on_attack(0))
	attack_btn_2.pressed.connect(func() -> void: _on_attack(1))
	attack_btn_3.pressed.connect(func() -> void: _on_attack(2))
	attack_btn_4.pressed.connect(func() -> void: _on_attack(3))
	attack_back_btn.pressed.connect(_on_attack_back)

	# Conectar botón volver de items (los botones de pociones se conectan dinámicamente)
	item_back_btn.pressed.connect(_on_item_back)

	# Todo oculto al inicio
	hide_all_menus()
	turn_label.text = ""
	print("[BattleHUD] _ready() - HUD inicializado por código")


# ── BUILD UI ───────────────────────────────────────────────

func _build_ui() -> void:
	# Root control (full rect, no bloquea mouse)
	var root := Control.new()
	root.name = "Root"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_root_control = root

	# ── Timeline (arriba-izquierda) ──
	var timeline_panel := PanelContainer.new()
	timeline_panel.name = "TimelinePanel"
	timeline_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	timeline_panel.position = Vector2(16, 16)
	timeline_panel.custom_minimum_size = Vector2(600, 64)
	timeline_panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.08, 0.08, 0.12, 0.85), 8))
	root.add_child(timeline_panel)

	timeline_hbox = HBoxContainer.new()
	timeline_hbox.name = "TimelineHBox"
	timeline_hbox.add_theme_constant_override("separation", 6)
	timeline_panel.add_child(timeline_hbox)

	# ── Turn Label (arriba-centro) ──
	turn_label = Label.new()
	turn_label.name = "TurnLabel"
	turn_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	turn_label.offset_left = -200
	turn_label.offset_top = 16
	turn_label.offset_right = 200
	turn_label.offset_bottom = 56
	turn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	turn_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	turn_label.add_theme_font_size_override("font_size", 22)
	turn_label.add_theme_color_override("font_color", Color.WHITE)
	turn_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	turn_label.add_theme_constant_override("outline_size", 4)
	root.add_child(turn_label)

	# ── Action Panel (derecha-centro) — incluye AP/SP arriba ──
	action_panel = _make_menu_panel(root, "ActionPanel", Vector2(220, 340))
	var action_vbox := VBoxContainer.new()
	action_vbox.add_theme_constant_override("separation", 8)
	action_panel.add_child(action_vbox)

	# ── Labels AP/SP dentro del ActionPanel ──
	var stats_hbox := HBoxContainer.new()
	stats_hbox.add_theme_constant_override("separation", 12)
	stats_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	action_vbox.add_child(stats_hbox)

	ap_label = Label.new()
	ap_label.text = "⚡ AP: 1/1"
	ap_label.add_theme_font_size_override("font_size", 15)
	ap_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	ap_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	ap_label.add_theme_constant_override("outline_size", 3)
	stats_hbox.add_child(ap_label)

	sp_label = Label.new()
	sp_label.text = "👟 SP: 2/2"
	sp_label.add_theme_font_size_override("font_size", 15)
	sp_label.add_theme_color_override("font_color", Color(0.4, 0.85, 1.0))
	sp_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	sp_label.add_theme_constant_override("outline_size", 3)
	stats_hbox.add_child(sp_label)

	# Separador visual entre AP/SP y los botones
	var sep := HSeparator.new()
	action_vbox.add_child(sep)

	# Botones de acción
	attack_btn = _make_button("⚔ Atacar")
	move_btn = _make_button("👟 Mover")
	item_btn = _make_button("🧪 Item")
	equipo_btn = _make_button("🎒 Equipo")
	end_turn_btn = _make_button("⏭ Fin Turno")
	action_vbox.add_child(attack_btn)
	action_vbox.add_child(move_btn)
	action_vbox.add_child(item_btn)
	action_vbox.add_child(equipo_btn)
	action_vbox.add_child(end_turn_btn)

	# ── Attack Panel (derecha-centro) ──
	attack_panel = _make_menu_panel(root, "AttackPanel", Vector2(280, 280))
	var attack_vbox := VBoxContainer.new()
	attack_vbox.add_theme_constant_override("separation", 6)
	attack_panel.add_child(attack_vbox)
	attack_btn_1 = _make_button("Ataque 1")
	attack_btn_2 = _make_button("Ataque 2")
	attack_btn_3 = _make_button("Ataque 3")
	attack_btn_4 = _make_button("Ataque 4")
	attack_back_btn = _make_button("↩ Volver")
	attack_vbox.add_child(attack_btn_1)
	attack_vbox.add_child(attack_btn_2)
	attack_vbox.add_child(attack_btn_3)
	attack_vbox.add_child(attack_btn_4)
	attack_vbox.add_child(attack_back_btn)

	# ── Item Panel (derecha-centro) — contenido dinámico, se llena con setup_item_menu() ──
	item_panel = _make_menu_panel(root, "ItemPanel", Vector2(250, 260))
	_item_vbox = VBoxContainer.new()
	_item_vbox.add_theme_constant_override("separation", 6)
	item_panel.add_child(_item_vbox)
	item_back_btn = _make_button("↩ Volver")
	_item_vbox.add_child(item_back_btn)

	# ── Label de selección de objetivo (arriba-centro, oculto por defecto) ──
	_target_prompt_label = Label.new()
	_target_prompt_label.name = "TargetPromptLabel"
	_target_prompt_label.text = "🎯 Selecciona un objetivo"
	_target_prompt_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_target_prompt_label.offset_left = -280
	_target_prompt_label.offset_top = 18
	_target_prompt_label.offset_right = 280
	_target_prompt_label.offset_bottom = 54
	_target_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_target_prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_target_prompt_label.add_theme_font_size_override("font_size", 18)
	_target_prompt_label.add_theme_color_override("font_color", Color(1.0, 0.7, 0.2))
	_target_prompt_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
	_target_prompt_label.add_theme_constant_override("outline_size", 4)
	_target_prompt_label.visible = false
	root.add_child(_target_prompt_label)

	# ── QTE Panel (centro de la pantalla, oculto por defecto) ──
	_build_qte_panel(root)

	# ── QTE Defensivo (escudo, oculto por defecto) ──
	_build_def_qte_panel(root)


func _make_menu_panel(parent: Control, panel_name: String, size: Vector2) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = panel_name
	panel.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	panel.anchor_left = 1.0
	panel.anchor_top = 0.5
	panel.anchor_right = 1.0
	panel.anchor_bottom = 0.5
	panel.offset_left = -size.x - 16
	panel.offset_top = -size.y / 2.0
	panel.offset_right = -16
	panel.offset_bottom = size.y / 2.0
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.1, 0.1, 0.15, 0.9), 10))
	panel.visible = false
	parent.add_child(panel)
	return panel


func _make_button(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.add_theme_stylebox_override("normal", _make_btn_style(Color(0.18, 0.2, 0.28, 1.0)))
	btn.add_theme_stylebox_override("hover", _make_btn_style(Color(0.28, 0.32, 0.45, 1.0)))
	btn.add_theme_stylebox_override("pressed", _make_btn_style(Color(0.35, 0.45, 0.65, 1.0)))
	var focus_style := _make_btn_style(Color(0.22, 0.26, 0.38, 1.0))
	focus_style.border_width_left = 2
	focus_style.border_width_top = 2
	focus_style.border_width_right = 2
	focus_style.border_width_bottom = 2
	focus_style.border_color = Color(0.55, 0.7, 1.0, 0.8)
	btn.add_theme_stylebox_override("focus", focus_style)
	return btn


func _make_panel_style(color: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.content_margin_left = 16
	style.content_margin_top = 12
	style.content_margin_right = 16
	style.content_margin_bottom = 12
	return style


func _make_btn_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 16
	style.content_margin_top = 10
	style.content_margin_right = 16
	style.content_margin_bottom = 10
	return style


# ── QTE BUILD ──────────────────────────────────────────────

func _build_qte_panel(root: Control) -> void:
	_qte_panel = PanelContainer.new()
	_qte_panel.name = "QTEPanel"
	_qte_panel.set_anchors_preset(Control.PRESET_CENTER)
	_qte_panel.anchor_left = 0.5
	_qte_panel.anchor_top = 0.5
	_qte_panel.anchor_right = 0.5
	_qte_panel.anchor_bottom = 0.5
	_qte_panel.offset_left = -160
	_qte_panel.offset_top = 40
	_qte_panel.offset_right = 160
	_qte_panel.offset_bottom = 180
	_qte_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_qte_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_qte_panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.05, 0.05, 0.1, 0.92), 12))
	_qte_panel.visible = false
	_qte_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_qte_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_qte_panel.add_child(vbox)

	# Fila de cajas Q, W, E
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 14)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(hbox)

	_qte_key_boxes.clear()
	_qte_key_labels.clear()
	for key_text in _qte_sequence:
		var box := PanelContainer.new()
		box.custom_minimum_size = Vector2(72, 56)
		box.add_theme_stylebox_override("panel", _make_qte_box_style(Color(0.2, 0.2, 0.25), Color(0.35, 0.35, 0.4)))
		hbox.add_child(box)

		var lbl := Label.new()
		lbl.text = key_text
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 28)
		lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		lbl.add_theme_constant_override("outline_size", 3)
		box.add_child(lbl)

		_qte_key_boxes.append(box)
		_qte_key_labels.append(lbl)

	# Barra de timer
	_qte_timer_bar = ProgressBar.new()
	_qte_timer_bar.custom_minimum_size = Vector2(0, 10)
	_qte_timer_bar.max_value = 1.0
	_qte_timer_bar.value = 1.0
	_qte_timer_bar.show_percentage = false
	# Estilo de la barra
	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.15, 0.15, 0.2)
	bar_bg.corner_radius_top_left = 4
	bar_bg.corner_radius_top_right = 4
	bar_bg.corner_radius_bottom_left = 4
	bar_bg.corner_radius_bottom_right = 4
	_qte_timer_bar.add_theme_stylebox_override("background", bar_bg)
	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = Color(1.0, 0.85, 0.2)
	bar_fill.corner_radius_top_left = 4
	bar_fill.corner_radius_top_right = 4
	bar_fill.corner_radius_bottom_left = 4
	bar_fill.corner_radius_bottom_right = 4
	_qte_timer_bar.add_theme_stylebox_override("fill", bar_fill)
	vbox.add_child(_qte_timer_bar)

	# Label de feedback
	_qte_feedback_label = Label.new()
	_qte_feedback_label.text = ""
	_qte_feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_qte_feedback_label.add_theme_font_size_override("font_size", 18)
	_qte_feedback_label.add_theme_color_override("font_color", Color.WHITE)
	_qte_feedback_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_qte_feedback_label.add_theme_constant_override("outline_size", 3)
	vbox.add_child(_qte_feedback_label)


func _make_qte_box_style(bg_color: Color, border_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.border_color = border_color
	style.content_margin_left = 8
	style.content_margin_top = 4
	style.content_margin_right = 8
	style.content_margin_bottom = 4
	return style


# ── DEF QTE BUILD ─────────────────────────────────────────

func _build_def_qte_panel(root: Control) -> void:
	_def_qte_panel = PanelContainer.new()
	_def_qte_panel.name = "DefQTEPanel"
	_def_qte_panel.set_anchors_preset(Control.PRESET_CENTER)
	_def_qte_panel.anchor_left = 0.5
	_def_qte_panel.anchor_top = 0.5
	_def_qte_panel.anchor_right = 0.5
	_def_qte_panel.anchor_bottom = 0.5
	_def_qte_panel.offset_left = -120
	_def_qte_panel.offset_top = 40
	_def_qte_panel.offset_right = 120
	_def_qte_panel.offset_bottom = 190
	_def_qte_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_def_qte_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	# Panel azulado para defensa (diferente al púrpura ofensivo)
	_def_qte_panel.add_theme_stylebox_override("panel",
		_make_panel_style(Color(0.05, 0.08, 0.15, 0.92), 12))
	_def_qte_panel.visible = false
	_def_qte_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_def_qte_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_def_qte_panel.add_child(vbox)

	# Prompt: "¡Bloquea!"
	_def_qte_prompt_label = Label.new()
	_def_qte_prompt_label.text = "¡Bloquea!"
	_def_qte_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_def_qte_prompt_label.add_theme_font_size_override("font_size", 18)
	_def_qte_prompt_label.add_theme_color_override("font_color", Color(0.4, 0.75, 1.0))
	_def_qte_prompt_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_def_qte_prompt_label.add_theme_constant_override("outline_size", 3)
	vbox.add_child(_def_qte_prompt_label)

	# Caja grande con tecla "Q"
	var key_hbox := HBoxContainer.new()
	key_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(key_hbox)

	_def_qte_key_box = PanelContainer.new()
	_def_qte_key_box.custom_minimum_size = Vector2(90, 64)
	_def_qte_key_box.add_theme_stylebox_override("panel",
		_make_qte_box_style(Color(0.1, 0.15, 0.3), Color(0.3, 0.6, 1.0)))
	key_hbox.add_child(_def_qte_key_box)

	_def_qte_key_label = Label.new()
	_def_qte_key_label.text = "Q"
	_def_qte_key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_def_qte_key_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_def_qte_key_label.add_theme_font_size_override("font_size", 32)
	_def_qte_key_label.add_theme_color_override("font_color", Color(0.5, 0.8, 1.0))
	_def_qte_key_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_def_qte_key_label.add_theme_constant_override("outline_size", 3)
	_def_qte_key_box.add_child(_def_qte_key_label)

	# Barra de timer (azul)
	_def_qte_timer_bar = ProgressBar.new()
	_def_qte_timer_bar.custom_minimum_size = Vector2(0, 10)
	_def_qte_timer_bar.max_value = 1.0
	_def_qte_timer_bar.value = 1.0
	_def_qte_timer_bar.show_percentage = false
	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.1, 0.1, 0.2)
	bar_bg.corner_radius_top_left = 4
	bar_bg.corner_radius_top_right = 4
	bar_bg.corner_radius_bottom_left = 4
	bar_bg.corner_radius_bottom_right = 4
	_def_qte_timer_bar.add_theme_stylebox_override("background", bar_bg)
	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = Color(0.3, 0.65, 1.0)  # Azul para defensa
	bar_fill.corner_radius_top_left = 4
	bar_fill.corner_radius_top_right = 4
	bar_fill.corner_radius_bottom_left = 4
	bar_fill.corner_radius_bottom_right = 4
	_def_qte_timer_bar.add_theme_stylebox_override("fill", bar_fill)
	vbox.add_child(_def_qte_timer_bar)

	# Label de feedback
	_def_qte_feedback_label = Label.new()
	_def_qte_feedback_label.text = ""
	_def_qte_feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_def_qte_feedback_label.add_theme_font_size_override("font_size", 16)
	_def_qte_feedback_label.add_theme_color_override("font_color", Color.WHITE)
	_def_qte_feedback_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_def_qte_feedback_label.add_theme_constant_override("outline_size", 3)
	vbox.add_child(_def_qte_feedback_label)


# ── QTE PUBLIC API ─────────────────────────────────────────

## Baraja el orden de las teclas QTE al azar para cada ataque.
func _randomize_qte_sequence() -> void:
	var pairs: Array = []
	for i in range(_qte_sequence.size()):
		pairs.append([_qte_sequence[i], _qte_keycodes[i]])
	pairs.shuffle()
	for i in range(pairs.size()):
		_qte_sequence[i] = pairs[i][0]
		_qte_keycodes[i] = pairs[i][1]


## Muestra el panel QTE y comienza la secuencia.
func show_qte() -> void:
	_qte_current_index = 0
	_qte_failed = false
	_qte_active = true
	_qte_timer = _qte_timeout
	_qte_feedback_label.text = ""

	# Randomizar el orden de las teclas
	_randomize_qte_sequence()

	# Actualizar labels con el nuevo orden
	for i in range(_qte_key_labels.size()):
		_qte_key_labels[i].text = _qte_sequence[i]

	# Reset visual de todas las cajas
	for i in range(_qte_key_boxes.size()):
		_qte_key_boxes[i].add_theme_stylebox_override("panel",
			_make_qte_box_style(Color(0.2, 0.2, 0.25), Color(0.35, 0.35, 0.4)))
		_qte_key_labels[i].add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))

	# Resaltar la primera caja como activa (borde amarillo)
	_set_qte_box_active(0)

	_qte_timer_bar.value = 1.0
	_qte_panel.visible = true
	print("[BattleHUD] QTE iniciado: %s" % str(_qte_sequence))


## Oculta el panel QTE.
func hide_qte() -> void:
	_qte_active = false
	_qte_panel.visible = false


## Actualiza el timer del QTE. Llamado desde battle_flow._process().
func qte_process(delta: float) -> void:
	if not _qte_active:
		return
	_qte_timer -= delta
	_qte_timer_bar.value = clampf(_qte_timer / _qte_timeout, 0.0, 1.0)
	if _qte_timer <= 0.0:
		# Timeout: fallo automático
		_qte_mark_fail(_qte_current_index)
		_qte_finish(false)


## Procesa input de QTE (teclas Q, W, E). Llamado desde battle_flow._input().
func qte_handle_input(event: InputEvent) -> void:
	if not _qte_active:
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return

	var key: Key = event.keycode
	var expected_key: Key = _qte_keycodes[_qte_current_index]

	if key == expected_key:
		# Tecla correcta
		_qte_mark_success(_qte_current_index)
		_qte_current_index += 1
		if _qte_current_index >= _qte_sequence.size():
			# Todas las teclas correctas: ¡Perfecto!
			_qte_finish(true)
		else:
			# Siguiente tecla
			_qte_timer = _qte_timeout
			_set_qte_box_active(_qte_current_index)
	else:
		# Tecla incorrecta: fallo
		_qte_mark_fail(_qte_current_index)
		_qte_finish(false)


func _set_qte_box_active(index: int) -> void:
	if index < 0 or index >= _qte_key_boxes.size():
		return
	_qte_key_boxes[index].add_theme_stylebox_override("panel",
		_make_qte_box_style(Color(0.25, 0.25, 0.1), Color(1.0, 0.85, 0.2)))
	_qte_key_labels[index].add_theme_color_override("font_color", Color(1.0, 0.95, 0.6))


func _qte_mark_success(index: int) -> void:
	if index < 0 or index >= _qte_key_boxes.size():
		return
	_qte_key_boxes[index].add_theme_stylebox_override("panel",
		_make_qte_box_style(Color(0.1, 0.4, 0.1), Color(0.2, 0.9, 0.3)))
	_qte_key_labels[index].add_theme_color_override("font_color", Color(0.3, 1.0, 0.4))


func _qte_mark_fail(index: int) -> void:
	if index < 0 or index >= _qte_key_boxes.size():
		return
	_qte_key_boxes[index].add_theme_stylebox_override("panel",
		_make_qte_box_style(Color(0.4, 0.1, 0.1), Color(0.9, 0.2, 0.2)))
	_qte_key_labels[index].add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))


func _qte_finish(success: bool) -> void:
	_qte_active = false
	if success:
		_qte_feedback_label.text = "¡Perfecto!"
		_qte_feedback_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.4))
	else:
		_qte_feedback_label.text = "¡Fallaste!"
		_qte_feedback_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
	print("[BattleHUD] QTE finalizado: %s" % ("PERFECTO" if success else "FALLO"))
	# Pequeño delay para que el jugador vea el feedback antes de continuar
	await get_tree().create_timer(0.5).timeout
	qte_completed.emit(success)


# ── DEFENSIVE QTE PUBLIC API ──────────────────────────────

## Muestra el panel de QTE defensivo (escudo) e inicia el timer.
func show_def_qte() -> void:
	_def_qte_active = true
	_def_qte_timer = _def_qte_timeout
	_def_qte_feedback_label.text = ""
	_def_qte_prompt_label.text = "¡Bloquea!"
	_def_qte_timer_bar.value = 1.0
	# Reset visual de la caja Q
	_def_qte_key_box.add_theme_stylebox_override("panel",
		_make_qte_box_style(Color(0.1, 0.15, 0.3), Color(0.3, 0.6, 1.0)))
	_def_qte_key_label.add_theme_color_override("font_color", Color(0.5, 0.8, 1.0))
	_def_qte_panel.visible = true
	print("[BattleHUD] QTE Defensivo iniciado: pulsa Q para bloquear")


## Oculta el panel de QTE defensivo.
func hide_def_qte() -> void:
	_def_qte_active = false
	_def_qte_panel.visible = false


## Actualiza el timer del QTE defensivo. Llamado desde battle_flow._process().
func def_qte_process(delta: float) -> void:
	if not _def_qte_active:
		return
	_def_qte_timer -= delta
	_def_qte_timer_bar.value = clampf(_def_qte_timer / _def_qte_timeout, 0.0, 1.0)
	if _def_qte_timer <= 0.0:
		# Timeout: fallo automático
		_def_qte_finish(false)


## Procesa input del QTE defensivo (tecla Q). Llamado desde battle_flow._input().
func def_qte_handle_input(event: InputEvent) -> void:
	if not _def_qte_active:
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return

	var key: Key = event.keycode
	if key == KEY_Q:
		# Tecla correcta: bloqueo exitoso
		_def_qte_key_box.add_theme_stylebox_override("panel",
			_make_qte_box_style(Color(0.1, 0.3, 0.4), Color(0.2, 0.8, 1.0)))
		_def_qte_key_label.add_theme_color_override("font_color", Color(0.3, 0.9, 1.0))
		_def_qte_finish(true)
	else:
		# Tecla incorrecta: fallo
		_def_qte_key_box.add_theme_stylebox_override("panel",
			_make_qte_box_style(Color(0.4, 0.1, 0.1), Color(0.9, 0.2, 0.2)))
		_def_qte_key_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		_def_qte_finish(false)


func _def_qte_finish(success: bool) -> void:
	_def_qte_active = false
	if success:
		_def_qte_feedback_label.text = "¡Bloqueado!"
		_def_qte_feedback_label.add_theme_color_override("font_color", Color(0.3, 0.85, 1.0))
	else:
		_def_qte_feedback_label.text = "¡Fallaste!"
		_def_qte_feedback_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
	print("[BattleHUD] QTE Defensivo finalizado: %s" % ("BLOQUEADO" if success else "FALLO"))
	# Breve delay para ver el feedback
	await get_tree().create_timer(0.4).timeout
	def_qte_completed.emit(success)


# ── PUBLIC API ─────────────────────────────────────────────

## Construye/actualiza la timeline con el orden de turnos.
func update_timeline(turn_order: Array, current_index: int) -> void:
	for child in timeline_hbox.get_children():
		child.queue_free()

	for i in range(turn_order.size()):
		var unit: Unit = turn_order[i] as Unit
		if not unit or not unit.alive:
			continue
		var slot: PanelContainer = _TurnSlotScene.instantiate()
		timeline_hbox.add_child(slot)
		slot.setup(unit, i == current_index)

	print("[BattleHUD] Timeline actualizada: %d unidades, turno actual: %d" % [turn_order.size(), current_index])


func show_turn_label(unit_name: String) -> void:
	turn_label.text = "Turno: %s" % unit_name
	print("[BattleHUD] Turno: %s" % unit_name)


func show_action_menu() -> void:
	hide_all_menus()
	action_panel.visible = true
	attack_btn.grab_focus()
	print("[BattleHUD] Mostrando menú de acciones")


func show_attack_menu(unit: Unit, melee_available: bool = false) -> void:
	hide_all_menus()
	attack_panel.visible = true

	var buttons: Array[Button] = [attack_btn_1, attack_btn_2, attack_btn_3, attack_btn_4]

	# Determinar cuántas habilidades hay combinando ambas manos (mín. 1 para golpe básico)
	var all_abilities: Array[Dictionary] = Unit.get_all_abilities(unit)
	var ability_count: int = maxi(1, all_abilities.size())

	for i in range(4):
		if i >= ability_count:
			buttons[i].visible = false
			continue
		buttons[i].visible = true

		var ab: Dictionary = Unit.get_ability(unit, i)
		var phys: int = ab.get("physical", 0)
		var mag: int = ab.get("magic", 0)
		var hit: float = ab.get("hit_chance", 1.0)
		var atk_range: int = ab.get("range", 99)
		var ab_effect: String = ab.get("effect", "")
		var is_defensive: bool = ab_effect != ""  # Defender u otros efectos especiales
		var is_melee: bool = atk_range <= 1 and not is_defensive
		var ab_name: String = ab.get("display_name", "Ataque %d" % (i + 1))

		if is_defensive:
			# Habilidad defensiva: icono escudo, sin stats de daño
			buttons[i].text = "🛡 %s" % ab_name
		else:
			var type_str: String = "Fís" if phys > 0 else "Mág"
			var dmg: int = phys if phys > 0 else mag
			var range_icon: String = "⚔" if is_melee else "🏹"
			buttons[i].text = "%s %s %s %d, %d%%" % [range_icon, ab_name, type_str, dmg, int(hit * 100)]

		# Deshabilitar ataques melee si no hay enemigo adyacente (defensivas siempre disponibles)
		if is_melee and not melee_available:
			buttons[i].disabled = true
			buttons[i].modulate = Color(0.5, 0.5, 0.5, 0.7)
			buttons[i].text += " (fuera de rango)"
		else:
			buttons[i].disabled = false
			buttons[i].modulate = Color.WHITE

	attack_btn_1.grab_focus()
	print("[BattleHUD] Mostrando menú de ataques para %s (melee: %s)" % [unit.display_name, melee_available])


func show_item_menu() -> void:
	hide_all_menus()
	item_panel.visible = true
	if _item_buttons.size() > 0:
		_item_buttons[0].grab_focus()
	else:
		item_back_btn.grab_focus()
	print("[BattleHUD] Mostrando menú de ítems (%d disponibles)" % _item_buttons.size())


## Rellena el panel de ítems con los consumibles actuales del inventario.
## Llamar antes de show_item_menu() cada vez que se abre el panel.
func setup_item_menu(items: Array[ItemData]) -> void:
	# Limpiar botones dinámicos anteriores
	for btn in _item_buttons:
		btn.queue_free()
	_item_buttons.clear()

	if items.is_empty():
		var lbl := Label.new()
		lbl.text = "Sin ítems disponibles"
		lbl.add_theme_font_size_override("font_size", 14)
		lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_item_vbox.add_child(lbl)
		_item_vbox.move_child(lbl, 0)
		_item_buttons  # vacío, no hay botones de pociones
		return

	for i in items.size():
		var item: ItemData = items[i]
		var emoji: String = _emoji_for_item(item)
		var btn := _make_button("%s %s" % [emoji, item.display_name])
		var idx := i  # captura local para el closure
		btn.pressed.connect(func() -> void: _on_item(idx))
		_item_buttons.append(btn)
		_item_vbox.add_child(btn)
		_item_vbox.move_child(btn, i)  # antes del botón ↩ Volver


## Devuelve el emoji correspondiente al tipo de ítem.
func _emoji_for_item(item: ItemData) -> String:
	match item.item_type:
		ItemData.ItemType.HEAL_HP:   return "🧪"
		ItemData.ItemType.HEAL_MANA: return "💧"
		ItemData.ItemType.ANTIDOTE:  return "🌿"
		_:                           return "⭐"


## Muestra un mensaje flotante temporal que desaparece con fade-out.
func show_feedback(msg: String) -> void:
	if not _root_control:
		return
	var lbl := Label.new()
	lbl.text = msg
	lbl.set_anchors_preset(Control.PRESET_CENTER)
	lbl.offset_top = -60
	lbl.offset_bottom = -20
	lbl.offset_left = -200
	lbl.offset_right = 200
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 24)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.3))
	lbl.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
	lbl.add_theme_constant_override("outline_size", 5)
	_root_control.add_child(lbl)
	var tw := lbl.create_tween()
	tw.tween_interval(0.6)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.9)
	tw.tween_callback(lbl.queue_free)


func show_equipo_panel(unit: Unit) -> void:
	hide_all_menus()

	# ── PersonalInventoryPanel (nuevo sistema RPG) ──
	if not equipo_panel:
		equipo_panel = PersonalInventoryPanel.new()
		# Centrar en pantalla
		equipo_panel.anchor_left   = 0.5
		equipo_panel.anchor_top    = 0.5
		equipo_panel.anchor_right  = 0.5
		equipo_panel.anchor_bottom = 0.5
		equipo_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
		equipo_panel.grow_vertical   = Control.GROW_DIRECTION_BOTH
		var pw: float = PersonalInventoryPanel.PANEL_SIZE.x
		var ph: float = PersonalInventoryPanel.PANEL_SIZE.y
		equipo_panel.offset_left   = -pw * 0.5
		equipo_panel.offset_right  =  pw * 0.5
		equipo_panel.offset_top    = -ph * 0.5
		equipo_panel.offset_bottom =  ph * 0.5
		equipo_panel.panel_closed.connect(func() -> void: back_from_equipo.emit())
		get_child(0).add_child(equipo_panel)

		# Crear inventario del unit si no tiene uno
		var inv: Inventory = unit.inventory if unit.get("inventory") != null else Inventory.new()
		equipo_panel.setup(inv)

	# ── InventoryPanel legacy: sigue manejando armas de batalla ──
	if not _legacy_inv_panel:
		_legacy_inv_panel = InventoryPanel.new()
		_legacy_inv_panel.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
		_legacy_inv_panel.anchor_left   = 1.0
		_legacy_inv_panel.anchor_top    = 0.5
		_legacy_inv_panel.anchor_right  = 1.0
		_legacy_inv_panel.anchor_bottom = 0.5
		_legacy_inv_panel.offset_left   = -256
		_legacy_inv_panel.offset_right  = -16
		_legacy_inv_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		_legacy_inv_panel.grow_vertical   = Control.GROW_DIRECTION_BOTH
		_legacy_inv_panel.weapon_equip_requested.connect(func(w: WeaponData, s: int) -> void: equip_weapon_requested.emit(w, s))
		_legacy_inv_panel.weapon_unequip_requested.connect(func(s: int) -> void: unequip_weapon_requested.emit(s))
		_legacy_inv_panel.panel_closed.connect(func() -> void: back_from_equipo.emit())
		get_child(0).add_child(_legacy_inv_panel)

	_legacy_inv_panel.setup(unit)
	_legacy_inv_panel.visible = true

	equipo_panel.visible = true
	print("[BattleHUD] Mostrando panel de equipo para %s" % unit.display_name)


## Habilita/deshabilita el botón Equipo.
func set_equipo_enabled(enabled: bool) -> void:
	if equipo_btn:
		equipo_btn.disabled = not enabled
		equipo_btn.modulate = Color.WHITE if enabled else Color(0.5, 0.5, 0.5, 0.7)


## Muestra el label de selección de objetivo con el nombre del ataque activo.
func show_target_selection_prompt(ability_name: String) -> void:
	hide_all_menus()
	if _target_prompt_label:
		_target_prompt_label.text = "🎯 '%s' — Selecciona un objetivo  (ESC para cancelar)" % ability_name
		_target_prompt_label.visible = true
	print("[BattleHUD] Mostrando prompt de selección de objetivo: '%s'" % ability_name)


func hide_all_menus() -> void:
	action_panel.visible = false
	attack_panel.visible = false
	item_panel.visible = false
	if equipo_panel:
		equipo_panel.visible = false
	if _legacy_inv_panel:
		_legacy_inv_panel.visible = false
	if _target_prompt_label:
		_target_prompt_label.visible = false
	if _qte_panel:
		_qte_active = false
		_qte_panel.visible = false
	if _def_qte_panel:
		_def_qte_active = false
		_def_qte_panel.visible = false


func hide_hud() -> void:
	hide_all_menus()
	turn_label.text = ""
	for child in timeline_hbox.get_children():
		child.queue_free()


## Actualiza los labels de AP y SP (ahora dentro del ActionPanel).
func update_ap_sp(ap: int, max_ap: int, sp: int, max_sp: int) -> void:
	if ap_label:
		ap_label.text = "⚡ AP: %d/%d" % [ap, max_ap]
	if sp_label:
		sp_label.text = "👟 SP: %d/%d" % [sp, max_sp]


## Habilita/deshabilita el botón Atacar (AP > 0).
func set_attack_enabled(enabled: bool) -> void:
	if attack_btn:
		attack_btn.disabled = not enabled
		attack_btn.modulate = Color.WHITE if enabled else Color(0.5, 0.5, 0.5, 0.7)


## Habilita/deshabilita el botón Mover (SP > 0).
func set_move_enabled(enabled: bool) -> void:
	if move_btn:
		move_btn.disabled = not enabled
		move_btn.modulate = Color.WHITE if enabled else Color(0.5, 0.5, 0.5, 0.7)


## Muestra el cartel de resultado final (victoria o derrota).
## units: Array de Unit (todas las unidades de la batalla, vivas y muertas).
func show_result_screen(won: bool, units: Array, oro_ganado: int = 0) -> void:
	hide_all_menus()
	turn_label.text = ""

	# Fondo semitransparente que cubre toda la pantalla
	if not _result_root:
		_result_root = Control.new()
		_result_root.name = "ResultRoot"
		_result_root.set_anchors_preset(Control.PRESET_FULL_RECT)
		_result_root.mouse_filter = Control.MOUSE_FILTER_STOP
		get_child(0).add_child(_result_root)  # Root Control

	# Limpiar contenido previo
	for c in _result_root.get_children():
		c.queue_free()
	_detail_panel = null

	# ── Fondo oscurecido ──
	var backdrop := ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.0, 0.0, 0.0, 0.55)
	_result_root.add_child(backdrop)

	# ── Panel principal centrado ──
	var main_panel := PanelContainer.new()
	main_panel.set_anchors_preset(Control.PRESET_CENTER)
	main_panel.anchor_left = 0.5
	main_panel.anchor_top = 0.5
	main_panel.anchor_right = 0.5
	main_panel.anchor_bottom = 0.5
	main_panel.offset_left = -240
	main_panel.offset_top = -160
	main_panel.offset_right = 240
	main_panel.offset_bottom = 160
	main_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	main_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var panel_color: Color = Color(0.06, 0.14, 0.06, 0.97) if won else Color(0.14, 0.05, 0.05, 0.97)
	main_panel.add_theme_stylebox_override("panel", _make_panel_style(panel_color, 14))
	_result_root.add_child(main_panel)

	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 16)
	main_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	main_panel.add_child(main_vbox)

	# ── Título VICTORIA / DERROTA ──
	var title := Label.new()
	title.text = "✨ VICTORIA ✨" if won else "💀 DERROTA 💀"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	var title_color: Color = Color(0.9, 1.0, 0.4) if won else Color(1.0, 0.35, 0.35)
	title.add_theme_color_override("font_color", title_color)
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1.0))
	title.add_theme_constant_override("outline_size", 5)
	main_vbox.add_child(title)

	# ── Subtítulo ──
	var subtitle := Label.new()
	subtitle.text = "¡Los aventureros triunfaron!" if won else "El grupo fue derrotado..."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 15)
	subtitle.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	main_vbox.add_child(subtitle)

	# ── Recompensa de oro (solo victoria) ──
	if won and oro_ganado > 0:
		var gold_label := Label.new()
		gold_label.text = "Oro ganado: +%d" % oro_ganado
		gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		gold_label.add_theme_font_size_override("font_size", 20)
		gold_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
		gold_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		gold_label.add_theme_constant_override("outline_size", 4)
		main_vbox.add_child(gold_label)

	main_vbox.add_child(HSeparator.new())

	# ── Botones de acción ──
	var btn_hbox := HBoxContainer.new()
	btn_hbox.add_theme_constant_override("separation", 12)
	btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	main_vbox.add_child(btn_hbox)

	var detail_btn := _make_button("📊 Ver Detalles")
	detail_btn.custom_minimum_size = Vector2(160, 0)
	btn_hbox.add_child(detail_btn)

	var gm: Node = Engine.get_main_loop().root.get_node_or_null("GameManager")
	var tiene_retorno: bool = gm != null and not gm.return_scene_after_battle.is_empty()
	var menu_btn := _make_button("Continuar" if tiene_retorno else "Menu Principal")
	menu_btn.custom_minimum_size = Vector2(160, 0)
	btn_hbox.add_child(menu_btn)

	# ── Panel de detalles (oculto por defecto) ──
	_detail_panel = _build_detail_panel(units)
	_detail_panel.visible = false
	_result_root.add_child(_detail_panel)

	# ── Conexiones de botones ──
	detail_btn.pressed.connect(func() -> void:
		_detail_panel.visible = not _detail_panel.visible
		detail_btn.text = "📊 Ocultar Detalles" if _detail_panel.visible else "📊 Ver Detalles"
	)
	menu_btn.pressed.connect(func() -> void:
		return_to_main_menu.emit()
	)

	_result_root.visible = true
	detail_btn.grab_focus()
	print("[BattleHUD] Pantalla de resultado mostrada: %s" % ("VICTORIA" if won else "DERROTA"))


## Construye el panel de detalles de batalla con una tabla por unidad.
func _build_detail_panel(units: Array) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -380
	panel.offset_top = -260
	panel.offset_right = 380
	panel.offset_bottom = 260
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.z_index = 1
	panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.07, 0.07, 0.12, 0.97), 12))

	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	scroll.add_child(vbox)

	# ── Título del panel ──
	var header := Label.new()
	header.text = "📊 Registro de Batalla"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", 20)
	header.add_theme_color_override("font_color", Color(0.9, 0.9, 1.0))
	vbox.add_child(header)
	vbox.add_child(HSeparator.new())

	# ── Tabla: columnas ──
	var col_headers := ["Unidad", "HP", "Daño\nInfligido", "Daño\nRecibido", "Golpes", "Fallos", "Crít.", "Bloqueos", "Esquivas", "Bajas"]
	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 0)
	vbox.add_child(header_row)
	for col in col_headers:
		var lbl := _make_table_cell(col, true)
		header_row.add_child(lbl)

	vbox.add_child(HSeparator.new())

	# ── Filas por unidad ──
	# Primero jugadores, luego enemigos
	var players: Array = []
	var enemies: Array = []
	for u in units:
		if u is Unit:
			if (u as Unit).team == Unit.Team.PLAYER:
				players.append(u)
			else:
				enemies.append(u)

	if not players.is_empty():
		var team_lbl := Label.new()
		team_lbl.text = "⚔ Jugadores"
		team_lbl.add_theme_color_override("font_color", Color(0.5, 0.8, 1.0))
		team_lbl.add_theme_font_size_override("font_size", 13)
		vbox.add_child(team_lbl)
	for u in players:
		vbox.add_child(_build_unit_row(u as Unit))

	if not enemies.is_empty():
		vbox.add_child(HSeparator.new())
		var team_lbl2 := Label.new()
		team_lbl2.text = "💀 Enemigos"
		team_lbl2.add_theme_color_override("font_color", Color(1.0, 0.5, 0.5))
		team_lbl2.add_theme_font_size_override("font_size", 13)
		vbox.add_child(team_lbl2)
	for u in enemies:
		vbox.add_child(_build_unit_row(u as Unit))

	# ── Botón cerrar ──
	vbox.add_child(HSeparator.new())
	var close_btn := _make_button("✕ Cerrar Detalles")
	close_btn.pressed.connect(func() -> void: panel.visible = false)
	vbox.add_child(close_btn)

	return panel


## Construye una fila de la tabla de detalles para una unidad.
func _build_unit_row(unit: Unit) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)

	var s: UnitStats = unit.stats
	var hp_text: String = "%d/%d" % [s.hp if unit.alive else 0, s.max_hp]
	var status: String = "" if unit.alive else " ☠"

	var cells: Array[String] = [
		unit.display_name + status,
		hp_text,
		str(s.battle_damage_dealt),
		str(s.battle_damage_taken),
		str(s.battle_hits),
		str(s.battle_misses),
		str(s.battle_crits),
		str(s.battle_blocks),
		str(s.battle_evades),
		str(s.battle_kills),
	]

	var is_player: bool = unit.team == Unit.Team.PLAYER
	var row_color: Color = Color(0.5, 0.8, 1.0) if is_player else Color(1.0, 0.6, 0.6)
	if not unit.alive:
		row_color = row_color.darkened(0.4)

	for i in range(cells.size()):
		var cell := _make_table_cell(cells[i], false)
		if i == 0:
			cell.add_theme_color_override("font_color", row_color)
		row.add_child(cell)

	return row


## Crea una celda de tabla con ancho mínimo fijo para mantener el alineamiento.
func _make_table_cell(text: String, is_header: bool) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.custom_minimum_size = Vector2(62, 0)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.clip_text = false
	lbl.add_theme_font_size_override("font_size", 12 if is_header else 13)
	if is_header:
		lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.6))
	else:
		lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	return lbl


# ── SIGNAL HANDLERS ────────────────────────────────────────

func _on_action(action: String) -> void:
	print("[BattleHUD] Acción seleccionada: %s" % action)
	action_selected.emit(action)


func _on_attack(index: int) -> void:
	print("[BattleHUD] Ataque seleccionado: %d" % index)
	attack_selected.emit(index)


func _on_item(index: int) -> void:
	print("[BattleHUD] Item seleccionado: %d" % index)
	item_selected.emit(index)


func _on_attack_back() -> void:
	print("[BattleHUD] Volver desde ataques")
	back_from_attack.emit()


func _on_item_back() -> void:
	print("[BattleHUD] Volver desde ítems")
	back_from_item.emit()
