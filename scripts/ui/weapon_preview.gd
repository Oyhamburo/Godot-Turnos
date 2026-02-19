extends Node3D
## Escena de previsualización de armas y animaciones del Ranger.
## Permite reproducir animaciones de arco, ajustar posición/rotación/mano
## del arma en tiempo real y copiar los valores finales al portapapeles.

const PREVIEW_SCENE    := "res://scenes/units/PlayerRanger.tscn"
const MAIN_MENU_SCENE  := "res://scenes/MainMenu.tscn"
const BOW_WEAPON_PATH  := "res://data/weapons/player_bow.tres"

# Animaciones de arco disponibles
const BOW_ANIMS: Array[String] = [
	"ranged_bow_draw",
	"ranged_bow_draw_up",
	"ranged_bow_release",
	"ranged_bow_release_up",
	"ranged_1h_shoot",
	"ranged_magic_shoot",
]

# ── Estado ───────────────────────────────────────────────────
var _unit: Node3D          = null
var _anim_player: AnimationPlayer = null
var _current_anim: String  = ""
var _loop_active: bool     = false

# Offset actual del arma (se aplica en tiempo real)
var _offset_pos: Vector3   = Vector3.ZERO
var _offset_rot: Vector3   = Vector3.ZERO
var _current_slot: int     = 2   # 0=derecha, 1=izquierda, 2=dos manos

# ── Referencias UI ───────────────────────────────────────────
var _ui_layer: CanvasLayer = null
var _status_label: Label   = null
var _loop_button: Button   = null

# Sliders posición
var _sl_px: HSlider = null
var _sl_py: HSlider = null
var _sl_pz: HSlider = null
# Sliders rotación
var _sl_rx: HSlider = null
var _sl_ry: HSlider = null
var _sl_rz: HSlider = null
# Labels de valor
var _lbl_px: Label = null
var _lbl_py: Label = null
var _lbl_pz: Label = null
var _lbl_rx: Label = null
var _lbl_ry: Label = null
var _lbl_rz: Label = null
# Selector de mano
var _slot_option: OptionButton = null
# Label de resultado para copiar
var _copy_label: Label = null

# visual_hand actual: 0=derecha, 1=izquierda (independiente del slot de stats 2H)
var _visual_hand: int = 1

# Cámara orbital
var _cam_yaw: float   = 0.0
var _cam_pitch: float = 15.0
var _cam_dist: float  = 3.5
var _dragging: bool   = false

@onready var _camera: Camera3D = $Camera3D


func _ready() -> void:
	_build_ui()
	_spawn_unit()


# ── Spawn del Ranger ─────────────────────────────────────────

func _spawn_unit() -> void:
	if not ResourceLoader.exists(PREVIEW_SCENE):
		push_error("WeaponPreview: escena no encontrada: %s" % PREVIEW_SCENE)
		return
	var packed := load(PREVIEW_SCENE) as PackedScene
	if not packed:
		return
	_unit = packed.instantiate() as Node3D
	if not _unit:
		return
	add_child(_unit)
	_unit.global_position = Vector3.ZERO
	_unit.global_rotation = Vector3(0.0, deg_to_rad(180.0), 0.0)

	# Esperar a que _ready() del unit termine (equipa el arco)
	await get_tree().process_frame
	await get_tree().process_frame

	_anim_player = _find_anim_player(_unit)
	if _anim_player and _anim_player.has_animation("idle"):
		_anim_player.play("idle")

	# Leer los offsets actuales del .tres y volcarlos a los sliders
	if ResourceLoader.exists(BOW_WEAPON_PATH):
		var wd := load(BOW_WEAPON_PATH)
		if wd:
			_offset_pos   = wd.get("hand_offset_pos") if wd.get("hand_offset_pos") != null else Vector3.ZERO
			_offset_rot   = wd.get("hand_offset_rot") if wd.get("hand_offset_rot") != null else Vector3.ZERO
			_current_slot = wd.get("slot")            if wd.get("slot")            != null else 2
			_visual_hand  = wd.get("visual_hand")     if wd.get("visual_hand")     != null else 0
			# Actualizar sliders con los valores reales (ya existen porque _build_ui corrió antes)
			if _sl_px:
				_sl_px.value = _offset_pos.x
				_sl_py.value = _offset_pos.y
				_sl_pz.value = _offset_pos.z
				_sl_rx.value = rad_to_deg(_offset_rot.x)
				_sl_ry.value = rad_to_deg(_offset_rot.y)
				_sl_rz.value = rad_to_deg(_offset_rot.z)
			if _slot_option:
				_slot_option.selected = _visual_hand
			_sync_pos_labels()
			_sync_rot_labels()
			_refresh_copy_label()

	_update_status("Listo — ajustá posición o reproducí una animación")


func _find_anim_player(node: Node) -> AnimationPlayer:
	for c in node.get_children():
		if c is AnimationPlayer:
			return c as AnimationPlayer
	var vis := node.find_child("Visual", true, false)
	if vis:
		for c in vis.get_children():
			if c is AnimationPlayer:
				return c as AnimationPlayer
	return null


# ── Construcción de UI ───────────────────────────────────────

func _build_ui() -> void:
	_ui_layer = CanvasLayer.new()
	_ui_layer.layer = 10
	add_child(_ui_layer)

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui_layer.add_child(root)

	_build_anim_panel(root)
	_build_transform_panel(root)
	_build_bottom_bar(root)
	_build_hint(root)


# ── Panel derecho: animaciones ───────────────────────────────

func _build_anim_panel(root: Control) -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	panel.custom_minimum_size = Vector2(250, 0)
	panel.offset_left   = -262.0
	panel.offset_top    = 8.0
	panel.offset_right  = -8.0
	panel.offset_bottom = 520.0
	root.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "Animaciones"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 14)
	vbox.add_child(title)
	vbox.add_child(HSeparator.new())

	for anim_name in BOW_ANIMS:
		var btn := Button.new()
		btn.text = anim_name.replace("ranged_", "").replace("_", " ").capitalize()
		btn.tooltip_text = anim_name
		btn.custom_minimum_size = Vector2(230, 38)
		btn.pressed.connect(_on_anim_button_pressed.bind(anim_name))
		vbox.add_child(btn)

	vbox.add_child(HSeparator.new())

	var chain_btn := Button.new()
	chain_btn.text = "▶ Draw → Release"
	chain_btn.custom_minimum_size = Vector2(230, 38)
	chain_btn.modulate = Color(0.4, 1.0, 0.6)
	chain_btn.pressed.connect(_on_chain_pressed.bind("ranged_bow_draw", "ranged_bow_release"))
	vbox.add_child(chain_btn)

	var chain_up_btn := Button.new()
	chain_up_btn.text = "▲ Draw Up → Release Up"
	chain_up_btn.custom_minimum_size = Vector2(230, 38)
	chain_up_btn.modulate = Color(0.4, 0.8, 1.0)
	chain_up_btn.pressed.connect(_on_chain_pressed.bind("ranged_bow_draw_up", "ranged_bow_release_up"))
	vbox.add_child(chain_up_btn)

	vbox.add_child(HSeparator.new())

	_loop_button = Button.new()
	_loop_button.text = "🔁 Loop: OFF"
	_loop_button.custom_minimum_size = Vector2(230, 36)
	_loop_button.pressed.connect(_on_loop_toggled)
	vbox.add_child(_loop_button)

	var idle_btn := Button.new()
	idle_btn.text = "⏹ Idle (reset)"
	idle_btn.custom_minimum_size = Vector2(230, 36)
	idle_btn.pressed.connect(_on_idle_pressed)
	vbox.add_child(idle_btn)


# ── Panel izquierdo: transform + mano + copiar ───────────────

func _build_transform_panel(root: Control) -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.custom_minimum_size = Vector2(310, 0)
	panel.offset_left   = 8.0
	panel.offset_top    = 8.0
	panel.offset_right  = 320.0
	panel.offset_bottom = 560.0
	root.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 5)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "Ajuste del arma en mano"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 14)
	vbox.add_child(title)
	vbox.add_child(HSeparator.new())

	# ── Selector de mano ──
	var hand_hbox := HBoxContainer.new()
	vbox.add_child(hand_hbox)
	var hand_lbl := Label.new()
	hand_lbl.text = "Mano:"
	hand_lbl.custom_minimum_size = Vector2(70, 0)
	hand_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hand_hbox.add_child(hand_lbl)

	_slot_option = OptionButton.new()
	_slot_option.add_item("Derecha  (visual_hand = 0)", 0)
	_slot_option.add_item("Izquierda (visual_hand = 1)", 1)
	_slot_option.selected = _visual_hand
	_slot_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_slot_option.item_selected.connect(_on_slot_changed)
	hand_hbox.add_child(_slot_option)

	vbox.add_child(HSeparator.new())

	# ── Posición ──
	var pos_title := Label.new()
	pos_title.text = "Posición (hand_offset_pos)"
	pos_title.add_theme_font_size_override("font_size", 12)
	vbox.add_child(pos_title)

	_sl_px = _make_slider(vbox, "X", _offset_pos.x, _on_pos_changed)
	_sl_py = _make_slider(vbox, "Y", _offset_pos.y, _on_pos_changed)
	_sl_pz = _make_slider(vbox, "Z", _offset_pos.z, _on_pos_changed)
	_lbl_px = _get_last_value_label(vbox)
	_lbl_py = _get_last_value_label(vbox)
	_lbl_pz = _get_last_value_label(vbox)
	_sync_pos_labels()

	vbox.add_child(HSeparator.new())

	# ── Rotación ──
	var rot_title := Label.new()
	rot_title.text = "Rotación en grados (hand_offset_rot)"
	rot_title.add_theme_font_size_override("font_size", 12)
	vbox.add_child(rot_title)

	var rot_note := Label.new()
	rot_note.text = "  (se guarda en radianes internamente)"
	rot_note.add_theme_font_size_override("font_size", 10)
	rot_note.modulate = Color(0.7, 0.7, 0.7)
	vbox.add_child(rot_note)

	_sl_rx = _make_slider(vbox, "X", rad_to_deg(_offset_rot.x), _on_rot_changed, -180.0, 180.0)
	_sl_ry = _make_slider(vbox, "Y", rad_to_deg(_offset_rot.y), _on_rot_changed, -180.0, 180.0)
	_sl_rz = _make_slider(vbox, "Z", rad_to_deg(_offset_rot.z), _on_rot_changed, -180.0, 180.0)
	_lbl_rx = _get_last_value_label(vbox)
	_lbl_ry = _get_last_value_label(vbox)
	_lbl_rz = _get_last_value_label(vbox)
	_sync_rot_labels()

	vbox.add_child(HSeparator.new())

	# ── Copiar al portapapeles ──
	var copy_title := Label.new()
	copy_title.text = "Resultado para player_bow.tres:"
	copy_title.add_theme_font_size_override("font_size", 12)
	vbox.add_child(copy_title)

	_copy_label = Label.new()
	_copy_label.add_theme_font_size_override("font_size", 10)
	_copy_label.modulate = Color(0.9, 1.0, 0.6)
	_copy_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_copy_label.custom_minimum_size = Vector2(290, 0)
	vbox.add_child(_copy_label)
	_refresh_copy_label()

	var copy_btn := Button.new()
	copy_btn.text = "📋 Copiar al portapapeles"
	copy_btn.custom_minimum_size = Vector2(290, 38)
	copy_btn.modulate = Color(1.0, 0.85, 0.3)
	copy_btn.pressed.connect(_on_copy_pressed)
	vbox.add_child(copy_btn)

	var reset_btn := Button.new()
	reset_btn.text = "↺ Resetear a cero"
	reset_btn.custom_minimum_size = Vector2(290, 34)
	reset_btn.pressed.connect(_on_reset_pressed)
	vbox.add_child(reset_btn)


# Helper: crea una fila  "Label | Slider | ValueLabel" y retorna el Slider
func _make_slider(parent: VBoxContainer, axis: String, initial: float,
		callback: Callable, min_v: float = -1.0, max_v: float = 1.0) -> HSlider:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	parent.add_child(row)

	var lbl := Label.new()
	lbl.text = axis
	lbl.custom_minimum_size = Vector2(14, 0)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(lbl)

	var sl := HSlider.new()
	sl.min_value = min_v
	sl.max_value = max_v
	sl.step = 0.01
	sl.value = initial
	sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sl.value_changed.connect(callback)
	row.add_child(sl)

	var val_lbl := Label.new()
	val_lbl.text = "%.3f" % initial
	val_lbl.custom_minimum_size = Vector2(52, 0)
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	val_lbl.add_theme_font_size_override("font_size", 10)
	row.add_child(val_lbl)

	return sl


# Truco: recupera el último Label de valor creado en el último hijo HBox
func _get_last_value_label(parent: VBoxContainer) -> Label:
	var last_row := parent.get_child(parent.get_child_count() - 1)
	if last_row is HBoxContainer:
		return last_row.get_child(last_row.get_child_count() - 1) as Label
	return null


# ── Barra inferior ───────────────────────────────────────────

func _build_bottom_bar(root: Control) -> void:
	var bar := PanelContainer.new()
	bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bar.custom_minimum_size = Vector2(0, 48)
	bar.offset_top = -52.0
	root.add_child(bar)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	bar.add_child(hbox)

	var back_btn := Button.new()
	back_btn.text = "← Menú principal"
	back_btn.custom_minimum_size = Vector2(200, 36)
	back_btn.pressed.connect(_on_back_pressed)
	hbox.add_child(back_btn)

	_status_label = Label.new()
	_status_label.text = "Cargando..."
	_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(_status_label)


func _build_hint(root: Control) -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	panel.offset_left   = -160.0
	panel.offset_top    = 8.0
	panel.offset_right  = 160.0
	panel.offset_bottom = 56.0
	root.add_child(panel)

	var lbl := Label.new()
	lbl.text = "Click derecho + arrastrar: rotar cámara   |   Rueda: zoom   |   ESC: volver"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 11)
	panel.add_child(lbl)


# ── Callbacks de animación ───────────────────────────────────

func _on_anim_button_pressed(anim_name: String) -> void:
	if not _anim_player:
		_update_status("Error: AnimationPlayer no encontrado")
		return
	if not _anim_player.has_animation(anim_name):
		_update_status("⚠ '%s' no disponible" % anim_name)
		return
	_current_anim = anim_name
	_loop_active = false
	_update_loop_button()
	_play_anim(anim_name)


func _on_chain_pressed(draw_anim: String, release_anim: String) -> void:
	if not _anim_player:
		return
	_play_chain(draw_anim, release_anim)


func _on_loop_toggled() -> void:
	_loop_active = not _loop_active
	_update_loop_button()
	if _loop_active and not _current_anim.is_empty():
		_play_anim_loop(_current_anim)
	elif not _loop_active:
		if _anim_player and _anim_player.is_playing():
			_anim_player.stop()
		_update_status("Loop desactivado")


func _on_idle_pressed() -> void:
	_loop_active = false
	_update_loop_button()
	_current_anim = ""
	if _anim_player and _anim_player.has_animation("idle"):
		_anim_player.play("idle")
	_update_status("Idle")


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


# ── Callbacks de transform ───────────────────────────────────

func _on_pos_changed(_v: float) -> void:
	_offset_pos = Vector3(_sl_px.value, _sl_py.value, _sl_pz.value)
	_sync_pos_labels()
	_apply_weapon_transform()
	_refresh_copy_label()


func _on_rot_changed(_v: float) -> void:
	_offset_rot = Vector3(
		deg_to_rad(_sl_rx.value),
		deg_to_rad(_sl_ry.value),
		deg_to_rad(_sl_rz.value)
	)
	_sync_rot_labels()
	_apply_weapon_transform()
	_refresh_copy_label()


func _on_slot_changed(idx: int) -> void:
	_visual_hand = idx   # 0=derecha, 1=izquierda
	_reequip_weapon()
	_refresh_copy_label()


func _on_copy_pressed() -> void:
	var text := _build_copy_text()
	DisplayServer.clipboard_set(text)
	_update_status("✓ Copiado al portapapeles")


func _on_reset_pressed() -> void:
	_offset_pos = Vector3.ZERO
	_offset_rot = Vector3.ZERO
	_sl_px.value = 0.0
	_sl_py.value = 0.0
	_sl_pz.value = 0.0
	_sl_rx.value = 0.0
	_sl_ry.value = 0.0
	_sl_rz.value = 0.0
	_sync_pos_labels()
	_sync_rot_labels()
	_apply_weapon_transform()
	_refresh_copy_label()
	_update_status("↺ Offsets reseteados a cero")


# ── Aplicar transform al arma en tiempo real ─────────────────

func _apply_weapon_transform() -> void:
	if not _unit:
		return
	# Usar visual_hand para saber en qué variable del unit está el nodo del arma
	var weapon_node: Node3D = null
	if _visual_hand == 1:
		weapon_node = _unit.get("_equipped_weapon_l") as Node3D
	else:
		weapon_node = _unit.get("_equipped_weapon_r") as Node3D

	if not is_instance_valid(weapon_node):
		return

	weapon_node.position = _offset_pos
	weapon_node.rotation = _offset_rot


func _reequip_weapon() -> void:
	if not _unit or not _unit.has_method("equip_weapon_data"):
		return
	if not ResourceLoader.exists(BOW_WEAPON_PATH):
		return
	var wd: Resource = load(BOW_WEAPON_PATH)
	if not wd:
		return
	# Cambiar visual_hand en memoria (no en disco) y re-equipar
	wd.set("visual_hand", _visual_hand)
	_unit.call("equip_weapon_data", wd)
	# Esperar un frame para que el nodo del arma se instancie
	await get_tree().process_frame
	_apply_weapon_transform()


# ── Helpers de UI ────────────────────────────────────────────

func _sync_pos_labels() -> void:
	if _lbl_px: _lbl_px.text = "%.3f" % _offset_pos.x
	if _lbl_py: _lbl_py.text = "%.3f" % _offset_pos.y
	if _lbl_pz: _lbl_pz.text = "%.3f" % _offset_pos.z


func _sync_rot_labels() -> void:
	if _lbl_rx: _lbl_rx.text = "%.1f°" % _sl_rx.value
	if _lbl_ry: _lbl_ry.text = "%.1f°" % _sl_ry.value
	if _lbl_rz: _lbl_rz.text = "%.1f°" % _sl_rz.value


func _refresh_copy_label() -> void:
	if _copy_label:
		_copy_label.text = _build_copy_text()


func _build_copy_text() -> String:
	var hand_names := ["RIGHT_HAND", "LEFT_HAND"]
	return (
		"visual_hand = %d  # %s\n" % [_visual_hand, hand_names[_visual_hand]] +
		"hand_offset_pos = Vector3(%.4f, %.4f, %.4f)\n" % [_offset_pos.x, _offset_pos.y, _offset_pos.z] +
		"hand_offset_rot = Vector3(%.4f, %.4f, %.4f)" % [_offset_rot.x, _offset_rot.y, _offset_rot.z]
	)


func _update_status(msg: String) -> void:
	if _status_label:
		_status_label.text = msg


func _update_loop_button() -> void:
	if _loop_button:
		_loop_button.text = "🔁 Loop: %s" % ("ON" if _loop_active else "OFF")
		_loop_button.modulate = Color(0.4, 1.0, 0.4) if _loop_active else Color.WHITE


# ── Reproducción de animaciones ──────────────────────────────

func _play_anim(anim_name: String) -> void:
	if not _anim_player or not _anim_player.has_animation(anim_name):
		return
	_anim_player.stop()
	_anim_player.play(anim_name)
	_update_status("▶ %s" % anim_name)
	if _loop_active:
		_anim_player.animation_finished.connect(_on_anim_ended_loop, CONNECT_ONE_SHOT)
	else:
		_anim_player.animation_finished.connect(_on_anim_ended_once, CONNECT_ONE_SHOT)


func _on_anim_ended_once(_n: StringName) -> void:
	if _anim_player and _anim_player.has_animation("idle"):
		_anim_player.play("idle")
	_update_status("✓ Terminó — '%s'" % _current_anim)


func _on_anim_ended_loop(_n: StringName) -> void:
	if _loop_active and not _current_anim.is_empty():
		_play_anim_loop(_current_anim)


func _play_anim_loop(anim_name: String) -> void:
	if not _anim_player or not _anim_player.has_animation(anim_name):
		return
	_anim_player.stop()
	_anim_player.play(anim_name)
	_update_status("🔁 %s (loop)" % anim_name)
	_anim_player.animation_finished.connect(_on_anim_ended_loop, CONNECT_ONE_SHOT)


## Devuelve el MeshInstance3D del arco instanciado en la mano del personaje de preview.
## Busca en el nodo raíz del arma equipada (izquierda o derecha según visual_hand).
func _get_preview_bow_mesh() -> MeshInstance3D:
	if not is_instance_valid(_unit):
		return null
	var bow_root: Node3D = null
	if _visual_hand == 1:
		bow_root = _unit.get("_equipped_weapon_l")
	else:
		bow_root = _unit.get("_equipped_weapon_r")
	if not is_instance_valid(bow_root):
		return null
	if bow_root is MeshInstance3D:
		return bow_root as MeshInstance3D
	return bow_root.find_child("*", true, false) as MeshInstance3D


func _play_chain(draw_anim: String, release_anim: String) -> void:
	if not _anim_player:
		return
	_loop_active = false
	_update_loop_button()
	_current_anim = draw_anim
	_anim_player.stop()

	# Obtener el MeshInstance3D del arco para animar la cuerda
	var bow_mesh: MeshInstance3D = _get_preview_bow_mesh()
	var bs_idx: int = -1
	if bow_mesh:
		bs_idx = bow_mesh.find_blend_shape_by_name("Draw")

	if _anim_player.has_animation(draw_anim):
		var draw_len: float = _anim_player.get_animation(draw_anim).length
		if bs_idx >= 0:
			bow_mesh.set_blend_shape_value(bs_idx, 0.0)
			var t_draw := create_tween()
			t_draw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			t_draw.tween_method(func(v: float) -> void:
				if is_instance_valid(bow_mesh):
					bow_mesh.set_blend_shape_value(bs_idx, v),
				0.0, 1.0, draw_len)
		_anim_player.play(draw_anim)
		_update_status("▶ %s" % draw_anim)
		await _anim_player.animation_finished

	if _anim_player.has_animation(release_anim):
		var release_len: float = _anim_player.get_animation(release_anim).length
		if bs_idx >= 0:
			var t_release := create_tween()
			t_release.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			t_release.tween_method(func(v: float) -> void:
				if is_instance_valid(bow_mesh):
					bow_mesh.set_blend_shape_value(bs_idx, v),
			1.0, 0.0, release_len)
		_anim_player.play(release_anim)
		_update_status("▶ %s" % release_anim)
		await _anim_player.animation_finished

	# Asegurar que la cuerda quede en reposo al terminar
	if bs_idx >= 0 and is_instance_valid(bow_mesh):
		bow_mesh.set_blend_shape_value(bs_idx, 0.0)
	if _anim_player.has_animation("idle"):
		_anim_player.play("idle")
	_update_status("✓ Secuencia completa")


# ── Cámara orbital ───────────────────────────────────────────

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			_dragging = mb.pressed
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			_cam_dist = clampf(_cam_dist - 0.25, 1.2, 8.0)
			_update_camera()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_cam_dist = clampf(_cam_dist + 0.25, 1.2, 8.0)
			_update_camera()
	elif event is InputEventMouseMotion and _dragging:
		var delta := (event as InputEventMouseMotion).relative
		_cam_yaw   -= delta.x * 0.4
		_cam_pitch  = clampf(_cam_pitch - delta.y * 0.3, -20.0, 70.0)
		_update_camera()
	elif event is InputEventKey:
		var ke := event as InputEventKey
		if ke.pressed and ke.keycode == KEY_ESCAPE:
			_on_back_pressed()


func _update_camera() -> void:
	if not _camera:
		return
	var yr := deg_to_rad(_cam_yaw)
	var pr := deg_to_rad(_cam_pitch)
	var offset := Vector3(
		_cam_dist * cos(pr) * sin(yr),
		_cam_dist * sin(pr),
		_cam_dist * cos(pr) * cos(yr)
	)
	_camera.global_position = Vector3(0.0, 1.0, 0.0) + offset
	_camera.look_at(Vector3(0.0, 1.0, 0.0), Vector3.UP)
