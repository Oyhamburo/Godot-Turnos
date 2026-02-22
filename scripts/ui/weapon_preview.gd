extends Node3D
## Escena de previsualización de armas y animaciones.
## Permite elegir personaje (Mannequin Medium o Large), seleccionar arma,
## editar stats del arma, probar animaciones de los ataques,
## ajustar posición/rotación del asset 3D y guardar cambios al .tres.

const MAIN_MENU_SCENE := "res://scenes/MainMenu.tscn"

# ── Personajes disponibles ────────────────────────────────────
const CHARACTERS := [
	{
		"label": "Mannequin Medium",
		"scene": "res://scenes/units/PlayerMannequin.tscn",
		"default_weapon": "res://data/weapons/mannequin_fists.tres",
	},
	{
		"label": "Mannequin Large",
		"scene": "res://scenes/units/EnemyMannequinLarge.tscn",
		"default_weapon": "res://data/weapons/mannequin_fists.tres",
	},
]

# ── Armas establecidas ────────────────────────────────────────
const WEAPONS := [
	{ "label": "Puños",            "path": "res://data/weapons/mannequin_fists.tres" },
	{ "label": "Espada 1H",        "path": "res://data/weapons/player_sword.tres" },
	{ "label": "Daga",             "path": "res://data/weapons/player_dagger.tres" },
	{ "label": "Hacha de Guerra",  "path": "res://data/weapons/player_axe_2h.tres" },
	{ "label": "Arco",             "path": "res://data/weapons/player_bow.tres" },
	{ "label": "Bastón Mágico",    "path": "res://data/weapons/player_staff.tres" },
	{ "label": "Escudo",           "path": "res://data/weapons/player_shield.tres" },
]

# Todas las animaciones disponibles para seleccionar en una ability.
# Incluye: animaciones base, melee, ranged y dodge.
# Las cadenas de arco aparecen como una sola entrada (draw guarda anim_name, release es implícita).
# Nota: ranged_bow_release / ranged_bow_release_up NO son abilities por sí solas (parte 2 de cadenas).
const SELECTABLE_ANIMS: Array[Dictionary] = [
	# ── Base ──────────────────────────────────────────────────────
	{ "label": "idle",                                        "anim": "idle",                  "chain": false, "group": "Base" },
	{ "label": "spawn_air",                                   "anim": "spawn_air",             "chain": false, "group": "Base" },
	{ "label": "death",                                       "anim": "death",                 "chain": false, "group": "Base" },
	{ "label": "hit",                                         "anim": "hit",                   "chain": false, "group": "Base" },
	{ "label": "attack  (interact)",                          "anim": "attack",                "chain": false, "group": "Base" },
	{ "label": "walk",                                        "anim": "walk",                  "chain": false, "group": "Base" },
	# ── Melee ─────────────────────────────────────────────────────
	{ "label": "melee_punch",                                 "anim": "melee_punch",           "chain": false, "group": "Melee" },
	{ "label": "melee_kick",                                  "anim": "melee_kick",            "chain": false, "group": "Melee" },
	{ "label": "melee_1h_chop",                               "anim": "melee_1h_chop",         "chain": false, "group": "Melee" },
	{ "label": "melee_1h_slice",                              "anim": "melee_1h_slice",        "chain": false, "group": "Melee" },
	{ "label": "melee_1h_stab",                               "anim": "melee_1h_stab",         "chain": false, "group": "Melee" },
	{ "label": "melee_2h_chop",                               "anim": "melee_2h_chop",         "chain": false, "group": "Melee" },
	{ "label": "melee_2h_spin",                               "anim": "melee_2h_spin",         "chain": false, "group": "Melee" },
	{ "label": "melee_block",                                 "anim": "melee_block",           "chain": false, "group": "Melee" },
	{ "label": "melee_blocking  [loop pose]",                 "anim": "melee_blocking",        "chain": false, "group": "Melee" },
	{ "label": "melee_block_hit",                             "anim": "melee_block_hit",       "chain": false, "group": "Melee" },
	{ "label": "melee_block_attack",                          "anim": "melee_block_attack",    "chain": false, "group": "Melee" },
	# ── Ranged ────────────────────────────────────────────────────
	{ "label": "ranged_bow_draw → release  [cadena]",         "anim": "ranged_bow_draw",       "chain": true,  "group": "Ranged" },
	{ "label": "ranged_bow_draw_up → release_up  [cadena]",   "anim": "ranged_bow_draw_up",    "chain": true,  "group": "Ranged" },
	{ "label": "ranged_magic_shoot",                          "anim": "ranged_magic_shoot",    "chain": false, "group": "Ranged" },
	{ "label": "ranged_magic_spellcast",                      "anim": "ranged_magic_spellcast","chain": false, "group": "Ranged" },
	{ "label": "ranged_magic_summon",                         "anim": "ranged_magic_summon",   "chain": false, "group": "Ranged" },
	{ "label": "ranged_1h_shoot",                             "anim": "ranged_1h_shoot",       "chain": false, "group": "Ranged" },
	# ── Dodge ─────────────────────────────────────────────────────
	{ "label": "dodge_backward",                              "anim": "dodge_backward",        "chain": false, "group": "Dodge" },
	{ "label": "dodge_forward",                               "anim": "dodge_forward",         "chain": false, "group": "Dodge" },
	{ "label": "dodge_left",                                  "anim": "dodge_left",            "chain": false, "group": "Dodge" },
	{ "label": "dodge_right",                                 "anim": "dodge_right",           "chain": false, "group": "Dodge" },
]

# ── Estado ───────────────────────────────────────────────────
var _unit: Node3D            = null
var _anim_player: AnimationPlayer = null
var _current_anim: String    = ""
var _loop_active: bool       = false
var _current_char_idx: int   = 0
var _current_weapon_path: String = ""
var _current_weapon_data: Resource = null

# Offset actual del arma (se aplica en tiempo real)
var _offset_pos: Vector3     = Vector3.ZERO
var _offset_rot: Vector3     = Vector3.ZERO
var _visual_hand: int        = 0   # 0=derecha, 1=izquierda
var _loading: bool           = false  # true mientras se actualizan sliders (evita callbacks)

# ── Referencias UI ───────────────────────────────────────────
var _ui_layer: CanvasLayer   = null
var _status_label: Label     = null
var _loop_button: Button     = null
var _char_option: OptionButton = null
var _weapon_option: OptionButton = null
var _anim_vbox: VBoxContainer  = null   # contenedor dinámico de ataques + anims
var _slot_option: OptionButton = null
var _copy_label: Label         = null
var _copy_title_label: Label   = null

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

# SpinBoxes de stats
var _spin_phys: SpinBox = null
var _spin_magic: SpinBox = null
var _spin_armor: SpinBox = null
var _spin_mr: SpinBox = null
var _spin_speed: SpinBox = null
var _spin_evasion: SpinBox = null
var _spin_crit: SpinBox = null
var _spin_buy: SpinBox = null
var _spin_sell: SpinBox = null

# Cámara orbital
var _cam_yaw: float   = 0.0
var _cam_pitch: float = 15.0
var _cam_dist: float  = 3.5
var _dragging: bool   = false

@onready var _camera: Camera3D = $Camera3D


func _ready() -> void:
	_build_ui()
	_spawn_unit(0)


# ── Spawn del personaje ───────────────────────────────────────

func _spawn_unit(char_idx: int) -> void:
	# Destruir unidad anterior
	if is_instance_valid(_unit):
		_unit.queue_free()
		_unit = null
	_anim_player = null

	_current_char_idx = char_idx
	var char_data: Dictionary = CHARACTERS[char_idx]
	var scene_path: String = char_data["scene"]

	if not ResourceLoader.exists(scene_path):
		push_error("WeaponPreview: escena no encontrada: %s" % scene_path)
		return

	var packed := load(scene_path) as PackedScene
	if not packed:
		return

	_unit = packed.instantiate() as Node3D
	if not _unit:
		return

	add_child(_unit)
	_unit.global_position = Vector3.ZERO
	_unit.global_rotation = Vector3(0.0, deg_to_rad(180.0), 0.0)

	# Esperar a que _ready() del unit termine (equipa arma por defecto)
	await get_tree().process_frame
	await get_tree().process_frame

	_anim_player = _find_anim_player(_unit)
	if _anim_player and _anim_player.has_animation("idle"):
		_anim_player.play("idle")

	# Cargar el arma por defecto del personaje
	var default_weapon_path: String = char_data["default_weapon"]
	await _load_weapon(default_weapon_path)

	_update_status("Listo")


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


# ── Carga de arma ────────────────────────────────────────────

func _load_weapon(weapon_path: String) -> void:
	_current_weapon_path = weapon_path

	if weapon_path.is_empty() or not ResourceLoader.exists(weapon_path):
		_current_weapon_data = null
		_refresh_stats()
		_refresh_anim_buttons()
		_refresh_copy_label()
		return

	# Usar CACHE_MODE_IGNORE para siempre leer del disco (evita caché tras ResourceSaver)
	var wd: Resource = ResourceLoader.load(weapon_path, "", ResourceLoader.CACHE_MODE_IGNORE)
	if not wd:
		_current_weapon_data = null
		_refresh_stats()
		_refresh_anim_buttons()
		return

	_current_weapon_data = wd

	# Leer offsets del .tres
	_offset_pos  = wd.get("hand_offset_pos") if wd.get("hand_offset_pos") != null else Vector3.ZERO
	_offset_rot  = wd.get("hand_offset_rot") if wd.get("hand_offset_rot") != null else Vector3.ZERO
	_visual_hand = wd.get("visual_hand")     if wd.get("visual_hand")     != null else 0

	# Actualizar sliders (con flag para evitar que callbacks sobreescriban _offset_pos/_offset_rot)
	_loading = true
	if _sl_px:
		_sl_px.value = _offset_pos.x
		_sl_py.value = _offset_pos.y
		_sl_pz.value = _offset_pos.z
		_sl_rx.value = rad_to_deg(_offset_rot.x)
		_sl_ry.value = rad_to_deg(_offset_rot.y)
		_sl_rz.value = rad_to_deg(_offset_rot.z)
	if _slot_option:
		_slot_option.selected = _visual_hand
	_loading = false
	_sync_pos_labels()
	_sync_rot_labels()

	# Equipar en el personaje (respetar el slot definido en el arma)
	if _unit and _unit.has_method("equip_weapon_data"):
		# Primero desequipar ambas manos para limpiar el estado
		if _unit.has_method("unequip_weapon_data"):
			_unit.call("unequip_weapon_data", 0)  # RIGHT_HAND
			_unit.call("unequip_weapon_data", 1)  # LEFT_HAND
		# Equipar en el slot que corresponde (2H usa RIGHT por defecto internamente)
		var equip_slot: int = 0  # RIGHT_HAND
		if wd.get("slot") == WeaponData.SlotMode.LEFT_HAND:
			equip_slot = 1  # LEFT_HAND
		_unit.call("equip_weapon_data", wd, equip_slot)
		await get_tree().process_frame
		_apply_weapon_transform()

	_refresh_stats()
	_refresh_anim_buttons()
	_refresh_copy_label()

	if _copy_title_label:
		_copy_title_label.text = "Resultado para %s:" % weapon_path.get_file()


# ══════════════════════════════════════════════════════════════
# ██  CONSTRUCCIÓN DE UI  █████████████████████████████████████
# ══════════════════════════════════════════════════════════════

func _build_ui() -> void:
	_ui_layer = CanvasLayer.new()
	_ui_layer.layer = 10
	add_child(_ui_layer)

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui_layer.add_child(root)

	_build_selector_bar(root)
	_build_transform_panel(root)   # izquierda
	_build_right_panel(root)       # derecha: stats + ataques + anims
	_build_bottom_bar(root)
	_build_hint(root)


# ── Barra superior: selector de personaje y arma ─────────────

func _build_selector_bar(root: Control) -> void:
	var bar := PanelContainer.new()
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.custom_minimum_size = Vector2(0, 52)
	bar.offset_top    = 0.0
	bar.offset_bottom = 52.0
	bar.mouse_filter  = Control.MOUSE_FILTER_STOP
	root.add_child(bar)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	bar.add_child(hbox)

	# ── Personaje ──
	var char_lbl := Label.new()
	char_lbl.text = "Personaje:"
	char_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	char_lbl.custom_minimum_size = Vector2(80, 0)
	hbox.add_child(char_lbl)

	_char_option = OptionButton.new()
	_char_option.custom_minimum_size = Vector2(200, 38)
	for ch in CHARACTERS:
		_char_option.add_item(ch["label"])
	_char_option.selected = 0
	_char_option.item_selected.connect(_on_char_changed)
	hbox.add_child(_char_option)

	# Separador
	var sep := VSeparator.new()
	hbox.add_child(sep)

	# ── Arma ──
	var weapon_lbl := Label.new()
	weapon_lbl.text = "Arma:"
	weapon_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	weapon_lbl.custom_minimum_size = Vector2(50, 0)
	hbox.add_child(weapon_lbl)

	_weapon_option = OptionButton.new()
	_weapon_option.custom_minimum_size = Vector2(200, 38)
	_weapon_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for w in WEAPONS:
		_weapon_option.add_item(w["label"])
	_weapon_option.selected = 0
	_weapon_option.item_selected.connect(_on_weapon_changed)
	hbox.add_child(_weapon_option)


# ── Panel derecho: stats + ataques + selector de animaciones ─

func _build_right_panel(root: Control) -> void:
	# PanelContainer con MOUSE_FILTER_STOP para que la rueda del ratón
	# no atraviese el panel y llegue a la cámara 3D orbital.
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	panel.custom_minimum_size = Vector2(300, 0)
	panel.offset_left   = -312.0
	panel.offset_top    = 60.0
	panel.offset_right  = -0.0
	panel.offset_bottom = -52.0
	panel.mouse_filter  = Control.MOUSE_FILTER_STOP
	root.add_child(panel)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# STOP en el scroll también: consume la rueda antes de que llegue a _input
	scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_child(scroll)

	var outer_vbox := VBoxContainer.new()
	outer_vbox.add_theme_constant_override("separation", 4)
	outer_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(outer_vbox)

	# ── Sección A: Stats del arma ──
	_build_stats_section(outer_vbox)

	outer_vbox.add_child(HSeparator.new())

	# ── Sección B: Controles de reproducción ──
	var playback_title := Label.new()
	playback_title.text = "Reproducción"
	playback_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	playback_title.add_theme_font_size_override("font_size", 13)
	playback_title.modulate = Color(0.75, 0.9, 1.0)
	outer_vbox.add_child(playback_title)

	_loop_button = Button.new()
	_loop_button.text = "Loop: OFF"
	_loop_button.custom_minimum_size = Vector2(280, 32)
	_loop_button.pressed.connect(_on_loop_toggled)
	outer_vbox.add_child(_loop_button)

	var idle_btn := Button.new()
	idle_btn.text = "Idle (reset)"
	idle_btn.custom_minimum_size = Vector2(280, 30)
	idle_btn.pressed.connect(_on_idle_pressed)
	outer_vbox.add_child(idle_btn)

	outer_vbox.add_child(HSeparator.new())

	# ── Sección C: Ataques del arma (dinámico, se refresca al cambiar arma) ──
	var attacks_title := Label.new()
	attacks_title.text = "Ataques del arma"
	attacks_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	attacks_title.add_theme_font_size_override("font_size", 14)
	outer_vbox.add_child(attacks_title)

	_anim_vbox = VBoxContainer.new()
	_anim_vbox.add_theme_constant_override("separation", 4)
	_anim_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer_vbox.add_child(_anim_vbox)


# ── Stats del arma (SpinBoxes) ───────────────────────────────

func _build_stats_section(parent: VBoxContainer) -> void:
	var title := Label.new()
	title.text = "Stats del arma"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 14)
	parent.add_child(title)

	_spin_phys   = _make_stat_spin(parent, "Daño Físico",    "bonus_physical_damage", -10, 50, 1)
	_spin_magic  = _make_stat_spin(parent, "Daño Mágico",    "bonus_magic_damage",    -10, 50, 1)
	_spin_armor  = _make_stat_spin(parent, "Armadura",        "bonus_armor",           -10, 50, 1)
	_spin_mr     = _make_stat_spin(parent, "Resist. Mágica",  "bonus_magic_resist",   -10, 50, 1)
	_spin_speed  = _make_stat_spin(parent, "Velocidad",       "bonus_speed",          -10, 50, 1)
	_spin_evasion = _make_stat_spin(parent, "Evasión",        "bonus_evasion",         0.0, 1.0, 0.01)
	_spin_crit   = _make_stat_spin(parent, "Crit. Chance",    "bonus_crit_chance",     0.0, 1.0, 0.01)

	parent.add_child(HSeparator.new())

	var price_lbl := Label.new()
	price_lbl.text = "Precios"
	price_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	price_lbl.add_theme_font_size_override("font_size", 12)
	parent.add_child(price_lbl)

	_spin_buy  = _make_stat_spin(parent, "Precio compra", "buy_price",  0, 999, 1)
	_spin_sell = _make_stat_spin(parent, "Precio venta",  "sell_price", 0, 999, 1)

	parent.add_child(HSeparator.new())

	# ── Botones de acción ──
	var save_btn := Button.new()
	save_btn.text = "Guardar .tres"
	save_btn.custom_minimum_size = Vector2(280, 36)
	save_btn.modulate = Color(0.3, 1.0, 0.3)
	save_btn.pressed.connect(_on_save_tres_pressed)
	parent.add_child(save_btn)

	var copy_stats_btn := Button.new()
	copy_stats_btn.text = "Copiar stats al portapapeles"
	copy_stats_btn.custom_minimum_size = Vector2(280, 34)
	copy_stats_btn.modulate = Color(1.0, 0.85, 0.3)
	copy_stats_btn.pressed.connect(_on_copy_stats_pressed)
	parent.add_child(copy_stats_btn)


func _make_stat_spin(parent: VBoxContainer, label_text: String, property: String,
		min_v: float, max_v: float, step_v: float) -> SpinBox:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	parent.add_child(row)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(120, 0)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 11)
	row.add_child(lbl)

	var spin := SpinBox.new()
	spin.min_value = min_v
	spin.max_value = max_v
	spin.step = step_v
	spin.value = 0
	spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spin.custom_minimum_size = Vector2(80, 0)
	spin.value_changed.connect(_on_stat_changed.bind(property))
	row.add_child(spin)

	return spin


func _refresh_stats() -> void:
	if not _current_weapon_data:
		# Resetear todos los spins a 0
		if _spin_phys:
			_spin_phys.value = 0
			_spin_magic.value = 0
			_spin_armor.value = 0
			_spin_mr.value = 0
			_spin_speed.value = 0
			_spin_evasion.value = 0.0
			_spin_crit.value = 0.0
			_spin_buy.value = 0
			_spin_sell.value = 0
		return

	var wd := _current_weapon_data
	# Bloquear señales temporalmente para no triggerear _on_stat_changed
	if _spin_phys:
		_spin_phys.set_value_no_signal(wd.get("bonus_physical_damage") if wd.get("bonus_physical_damage") != null else 0)
		_spin_magic.set_value_no_signal(wd.get("bonus_magic_damage") if wd.get("bonus_magic_damage") != null else 0)
		_spin_armor.set_value_no_signal(wd.get("bonus_armor") if wd.get("bonus_armor") != null else 0)
		_spin_mr.set_value_no_signal(wd.get("bonus_magic_resist") if wd.get("bonus_magic_resist") != null else 0)
		_spin_speed.set_value_no_signal(wd.get("bonus_speed") if wd.get("bonus_speed") != null else 0)
		_spin_evasion.set_value_no_signal(wd.get("bonus_evasion") if wd.get("bonus_evasion") != null else 0.0)
		_spin_crit.set_value_no_signal(wd.get("bonus_crit_chance") if wd.get("bonus_crit_chance") != null else 0.0)
		_spin_buy.set_value_no_signal(wd.get("buy_price") if wd.get("buy_price") != null else 0)
		_spin_sell.set_value_no_signal(wd.get("sell_price") if wd.get("sell_price") != null else 0)


func _on_stat_changed(value: float, property: String) -> void:
	if not _current_weapon_data:
		return
	_current_weapon_data.set(property, value)
	_refresh_copy_label()


func _on_save_tres_pressed() -> void:
	if not _current_weapon_data or _current_weapon_path.is_empty():
		_update_status("No hay arma para guardar")
		return

	# Sincronizar offsets actuales al resource antes de guardar
	_current_weapon_data.set("hand_offset_pos", _offset_pos)
	_current_weapon_data.set("hand_offset_rot", _offset_rot)
	_current_weapon_data.set("visual_hand", _visual_hand)

	var err := ResourceSaver.save(_current_weapon_data, _current_weapon_path)
	if err == OK:
		_update_status("Guardado (stats + posicion): %s" % _current_weapon_path.get_file())
	else:
		_update_status("Error al guardar: %s (code %d)" % [_current_weapon_path.get_file(), err])


func _on_save_position_pressed() -> void:
	if not _current_weapon_data or _current_weapon_path.is_empty():
		_update_status("No hay arma para guardar")
		return

	# Sincronizar offsets al resource
	_current_weapon_data.set("hand_offset_pos", _offset_pos)
	_current_weapon_data.set("hand_offset_rot", _offset_rot)
	_current_weapon_data.set("visual_hand", _visual_hand)

	var err := ResourceSaver.save(_current_weapon_data, _current_weapon_path)
	if err == OK:
		_update_status("Posicion guardada: %s" % _current_weapon_path.get_file())
	else:
		_update_status("Error al guardar: %s (code %d)" % [_current_weapon_path.get_file(), err])


func _on_copy_stats_pressed() -> void:
	var text := _build_stats_text()
	DisplayServer.clipboard_set(text)
	_update_status("Stats copiados al portapapeles")


func _build_stats_text() -> String:
	var lines: PackedStringArray = []

	if _current_weapon_data:
		var wname: String = _current_weapon_data.get("display_name") if _current_weapon_data.get("display_name") != null else "?"
		lines.append("# Arma: %s" % wname)
		lines.append("# Archivo: %s" % _current_weapon_path.get_file())
		lines.append("")
		lines.append("bonus_physical_damage = %d" % int(_current_weapon_data.get("bonus_physical_damage")))
		lines.append("bonus_magic_damage = %d" % int(_current_weapon_data.get("bonus_magic_damage")))
		lines.append("bonus_armor = %d" % int(_current_weapon_data.get("bonus_armor")))
		lines.append("bonus_magic_resist = %d" % int(_current_weapon_data.get("bonus_magic_resist")))
		lines.append("bonus_speed = %d" % int(_current_weapon_data.get("bonus_speed")))
		lines.append("bonus_evasion = %.2f" % float(_current_weapon_data.get("bonus_evasion")))
		lines.append("bonus_crit_chance = %.2f" % float(_current_weapon_data.get("bonus_crit_chance")))
		lines.append("buy_price = %d" % int(_current_weapon_data.get("buy_price")))
		lines.append("sell_price = %d" % int(_current_weapon_data.get("sell_price")))

		var abilities = _current_weapon_data.get("abilities")
		if abilities and abilities is Array and abilities.size() > 0:
			lines.append("")
			lines.append("# Abilities (%d):" % abilities.size())
			for ab in abilities:
				if ab is Dictionary:
					var aname: String = ab.get("display_name", "?")
					var anim: String  = ab.get("anim_name", "")
					var phys: int     = ab.get("physical", 0)
					var mag: int      = ab.get("magic", 0)
					var hit: float    = ab.get("hit_chance", 0.0)
					var rng: int      = ab.get("range", 1)
					lines.append("#   [%s] phys=%d  mag=%d  hit=%.0f%%  range=%d  anim=%s" % [aname, phys, mag, hit * 100, rng, anim])
	else:
		lines.append("# (sin arma seleccionada)")

	return "\n".join(lines)


# ── Ataques del arma (dinámico) ──────────────────────────────

func _refresh_anim_buttons() -> void:
	if not _anim_vbox:
		return

	# Limpiar botones anteriores
	for child in _anim_vbox.get_children():
		child.queue_free()

	if not _current_weapon_data:
		var no_weapon_lbl := Label.new()
		no_weapon_lbl.text = "(sin arma)"
		no_weapon_lbl.modulate = Color(0.5, 0.5, 0.5)
		_anim_vbox.add_child(no_weapon_lbl)
		return

	var abilities = _current_weapon_data.get("abilities")
	if not abilities or not abilities is Array or abilities.size() == 0:
		var no_ab_lbl := Label.new()
		no_ab_lbl.text = "(sin ataques)"
		no_ab_lbl.modulate = Color(0.5, 0.5, 0.5)
		_anim_vbox.add_child(no_ab_lbl)
		return

	for ab_idx in range(abilities.size()):
		var ab = abilities[ab_idx]
		if not ab is Dictionary:
			continue

		var ab_name: String = ab.get("display_name", "Ataque")
		var anim_name: String = ab.get("anim_name", "")
		var phys: int = ab.get("physical", 0)
		var mag: int = ab.get("magic", 0)
		var hit: float = ab.get("hit_chance", 0.0)
		var rng: int = ab.get("range", 1)
		var aoe: int = ab.get("aoe_radius", 0)

		# Nombre del ataque (dorado)
		var name_lbl := Label.new()
		name_lbl.text = ab_name
		name_lbl.add_theme_font_size_override("font_size", 13)
		name_lbl.modulate = Color(1.0, 0.85, 0.4)
		_anim_vbox.add_child(name_lbl)

		# Descripción
		var desc_parts: PackedStringArray = []
		if phys > 0:
			desc_parts.append("Fisico: %d" % phys)
		if mag > 0:
			desc_parts.append("Magico: %d" % mag)
		desc_parts.append("Precision: %d%%" % int(hit * 100))
		if rng == 1:
			desc_parts.append("Melee")
		elif rng >= 99:
			desc_parts.append("A distancia")
		else:
			desc_parts.append("Rango: %d" % rng)
		if aoe > 0:
			desc_parts.append("AoE: %d" % aoe)

		var desc_lbl := Label.new()
		desc_lbl.text = "  " + " | ".join(desc_parts)
		desc_lbl.add_theme_font_size_override("font_size", 10)
		desc_lbl.modulate = Color(0.8, 0.8, 0.8)
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_anim_vbox.add_child(desc_lbl)

		# Botón probar animación
		if not anim_name.is_empty():
			var btn := Button.new()
			btn.custom_minimum_size = Vector2(280, 32)

			# Cadenas de arco: el botón ejecuta draw→release completo
			var is_bow_chain := anim_name in ["ranged_bow_draw", "ranged_bow_draw_up"]
			# Bloqueo con tween de escudo
			var has_block_offsets: bool = ab.has("block_offset_pos")

			if is_bow_chain:
				var release_anim := "ranged_bow_release" if anim_name == "ranged_bow_draw" else "ranged_bow_release_up"
				btn.text = "Probar: %s (cadena)" % ab_name
				btn.tooltip_text = "%s -> %s" % [anim_name, release_anim]
				btn.modulate = Color(0.4, 1.0, 0.6)
				if _anim_player and not _anim_player.has_animation(anim_name):
					btn.modulate = Color(0.4, 0.4, 0.4)
					btn.disabled = true
				btn.pressed.connect(_on_chain_pressed.bind(anim_name, release_anim))
			elif has_block_offsets:
				var b_pos: Vector3 = ab.get("block_offset_pos", Vector3.ZERO)
				var b_rot: Vector3 = ab.get("block_offset_rot", Vector3.ZERO)
				btn.text = "Probar: %s (bloqueo)" % ab_name
				btn.tooltip_text = "%s → tween a offsets" % anim_name
				btn.modulate = Color(0.3, 0.7, 1.0)
				if _anim_player and not _anim_player.has_animation(anim_name):
					btn.modulate = Color(0.4, 0.4, 0.4)
					btn.disabled = true
				btn.pressed.connect(_on_block_pressed.bind(anim_name, b_pos, b_rot))
			else:
				btn.text = "Probar: %s" % ab_name
				btn.tooltip_text = anim_name
				if _anim_player and not _anim_player.has_animation(anim_name):
					btn.modulate = Color(0.4, 0.4, 0.4)
					btn.disabled = true
					btn.tooltip_text = anim_name + " (no disponible)"
				btn.pressed.connect(_on_anim_button_pressed.bind(anim_name))

			_anim_vbox.add_child(btn)

		# ── Selector de animación con buscador ──
		_build_anim_selector(_anim_vbox, ab_idx, anim_name)

		# Separador entre ataques
		_anim_vbox.add_child(HSeparator.new())


# ── Selector de animación por ability ───────────────────────

func _build_anim_selector(parent: VBoxContainer, ability_idx: int, current_anim: String) -> void:
	var section_lbl := Label.new()
	section_lbl.text = "Cambiar animacion:"
	section_lbl.add_theme_font_size_override("font_size", 10)
	section_lbl.modulate = Color(0.6, 0.6, 0.6)
	parent.add_child(section_lbl)

	# LineEdit de búsqueda
	var search := LineEdit.new()
	search.placeholder_text = "Buscar animacion..."
	search.custom_minimum_size = Vector2(280, 28)
	search.add_theme_font_size_override("font_size", 11)
	parent.add_child(search)

	# ItemList con todas las opciones
	var item_list := ItemList.new()
	item_list.custom_minimum_size = Vector2(280, 118)
	item_list.add_theme_font_size_override("font_size", 11)
	parent.add_child(item_list)

	# Poblar lista inicial
	_populate_anim_list(item_list, "", current_anim)

	# Filtrar al escribir
	search.text_changed.connect(func(query: String) -> void:
		_populate_anim_list(item_list, query, current_anim)
	)

	# Botón aplicar
	var apply_btn := Button.new()
	apply_btn.text = "Aplicar animacion"
	apply_btn.custom_minimum_size = Vector2(280, 28)
	apply_btn.modulate = Color(0.7, 0.9, 1.0)
	apply_btn.pressed.connect(_on_apply_anim_change.bind(item_list, ability_idx))
	parent.add_child(apply_btn)


func _populate_anim_list(item_list: ItemList, query: String, current_anim: String) -> void:
	item_list.clear()
	var q := query.to_lower()
	var last_group := ""

	for entry in SELECTABLE_ANIMS:
		var label: String  = entry["label"]
		var anim: String   = entry["anim"]
		var is_chain: bool = entry["chain"]
		var group: String  = entry.get("group", "")

		# Filtrar por búsqueda (busca en label Y en anim_name)
		if not q.is_empty() and not label.to_lower().contains(q) and not anim.to_lower().contains(q):
			continue

		# Encabezado de grupo (separador visual) sólo cuando NO hay búsqueda activa
		if group != last_group and q.is_empty():
			last_group = group
			var sep_idx := item_list.add_item("── %s ──" % group)
			item_list.set_item_selectable(sep_idx, false)
			item_list.set_item_custom_fg_color(sep_idx, Color(0.55, 0.55, 0.55))

		var item_idx := item_list.add_item(label)
		item_list.set_item_metadata(item_idx, anim)

		# Color: actual = cyan, cadena = verde, normal = blanco
		if anim == current_anim:
			item_list.set_item_custom_fg_color(item_idx, Color(0.3, 1.0, 0.9))
		elif is_chain:
			item_list.set_item_custom_fg_color(item_idx, Color(0.5, 1.0, 0.5))


func _on_apply_anim_change(item_list: ItemList, ability_idx: int) -> void:
	var selected := item_list.get_selected_items()
	if selected.is_empty():
		_update_status("Selecciona una animacion primero")
		return
	if not _current_weapon_data:
		return

	var new_anim: String = item_list.get_item_metadata(selected[0])
	var abilities: Array = _current_weapon_data.get("abilities")
	if ability_idx >= abilities.size():
		return

	var ab: Dictionary = abilities[ability_idx].duplicate()
	ab["anim_name"] = new_anim
	abilities[ability_idx] = ab
	_current_weapon_data.set("abilities", abilities)

	_update_status("Animacion cambiada: %s" % new_anim)
	_refresh_anim_buttons()
	_refresh_copy_label()


# ── Panel izquierdo: transform + mano + copiar ───────────────

func _build_transform_panel(root: Control) -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	panel.custom_minimum_size = Vector2(320, 0)
	panel.offset_left   = 0.0
	panel.offset_top    = 60.0
	panel.offset_right  = 320.0
	panel.offset_bottom = -52.0
	panel.mouse_filter  = Control.MOUSE_FILTER_STOP
	root.add_child(panel)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 5)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)

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
	_lbl_px = _get_last_value_label(vbox)
	_sl_py = _make_slider(vbox, "Y", _offset_pos.y, _on_pos_changed)
	_lbl_py = _get_last_value_label(vbox)
	_sl_pz = _make_slider(vbox, "Z", _offset_pos.z, _on_pos_changed)
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
	_lbl_rx = _get_last_value_label(vbox)
	_sl_ry = _make_slider(vbox, "Y", rad_to_deg(_offset_rot.y), _on_rot_changed, -180.0, 180.0)
	_lbl_ry = _get_last_value_label(vbox)
	_sl_rz = _make_slider(vbox, "Z", rad_to_deg(_offset_rot.z), _on_rot_changed, -180.0, 180.0)
	_lbl_rz = _get_last_value_label(vbox)
	_sync_rot_labels()

	vbox.add_child(HSeparator.new())

	# ── Copiar al portapapeles ──
	_copy_title_label = Label.new()
	_copy_title_label.text = "Resultado para el arma:"
	_copy_title_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(_copy_title_label)

	_copy_label = Label.new()
	_copy_label.add_theme_font_size_override("font_size", 10)
	_copy_label.modulate = Color(0.9, 1.0, 0.6)
	_copy_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_copy_label.custom_minimum_size = Vector2(290, 160)
	vbox.add_child(_copy_label)
	_refresh_copy_label()

	var copy_btn := Button.new()
	copy_btn.text = "Copiar al portapapeles"
	copy_btn.custom_minimum_size = Vector2(290, 38)
	copy_btn.modulate = Color(1.0, 0.85, 0.3)
	copy_btn.pressed.connect(_on_copy_pressed)
	vbox.add_child(copy_btn)

	var save_pos_btn := Button.new()
	save_pos_btn.text = "Guardar posicion al .tres"
	save_pos_btn.custom_minimum_size = Vector2(290, 36)
	save_pos_btn.modulate = Color(0.3, 1.0, 0.3)
	save_pos_btn.pressed.connect(_on_save_position_pressed)
	vbox.add_child(save_pos_btn)

	var reset_btn := Button.new()
	reset_btn.text = "Resetear offsets a cero"
	reset_btn.custom_minimum_size = Vector2(290, 34)
	reset_btn.pressed.connect(_on_reset_pressed)
	vbox.add_child(reset_btn)


# Helper: crea una fila "Label | Slider | ValueLabel" y retorna el Slider
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
	bar.offset_top   = -52.0
	bar.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(bar)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	bar.add_child(hbox)

	var back_btn := Button.new()
	back_btn.text = "<- Menu principal"
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
	panel.offset_left   = -220.0
	panel.offset_top    = 60.0
	panel.offset_right  = 220.0
	panel.offset_bottom = 96.0
	root.add_child(panel)

	var lbl := Label.new()
	lbl.text = "Click derecho + arrastrar: rotar camara   |   Rueda: zoom   |   ESC: volver"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 11)
	panel.add_child(lbl)


# ══════════════════════════════════════════════════════════════
# ██  CALLBACKS  ██████████████████████████████████████████████
# ══════════════════════════════════════════════════════════════

# ── Callbacks de selección ───────────────────────────────────

func _on_char_changed(idx: int) -> void:
	_update_status("Cargando personaje...")
	# Seleccionar el arma por defecto del personaje nuevo
	var default_weapon: String = CHARACTERS[idx]["default_weapon"]
	# Buscar su índice en WEAPONS
	var weapon_idx := 0
	for i in range(WEAPONS.size()):
		if WEAPONS[i]["path"] == default_weapon:
			weapon_idx = i
			break
	if _weapon_option:
		_weapon_option.selected = weapon_idx

	await _spawn_unit(idx)


func _on_weapon_changed(idx: int) -> void:
	var weapon_path: String = WEAPONS[idx]["path"]
	_update_status("Cargando arma: %s" % WEAPONS[idx]["label"])
	await _load_weapon(weapon_path)
	_update_status("Arma cargada: %s" % WEAPONS[idx]["label"])


# ── Callbacks de animación ───────────────────────────────────

func _on_anim_button_pressed(anim_name: String) -> void:
	if not _anim_player:
		_update_status("Error: AnimationPlayer no encontrado")
		return
	if not _anim_player.has_animation(anim_name):
		_update_status("'%s' no disponible en este personaje" % anim_name)
		return
	_current_anim = anim_name
	_loop_active = false
	_update_loop_button()
	_play_anim(anim_name)


func _on_block_pressed(anim_name: String, target_pos: Vector3, target_rot: Vector3) -> void:
	if not _unit or not _unit.has_method("play_block_animation"):
		return
	_loop_active = false
	_update_loop_button()
	_current_anim = anim_name

	# Desconectar señales previas para evitar conflictos
	if _anim_player and _anim_player.animation_finished.is_connected(_on_anim_ended_once):
		_anim_player.animation_finished.disconnect(_on_anim_ended_once)
	if _anim_player and _anim_player.animation_finished.is_connected(_on_anim_ended_loop):
		_anim_player.animation_finished.disconnect(_on_anim_ended_loop)

	# Método unificado en Unit.gd (mismo que usa battle_flow.gd)
	await _unit.play_block_animation(anim_name, target_pos, target_rot)

	# Volver a idle manteniendo posición final del escudo
	if _anim_player and _anim_player.has_animation("idle"):
		_anim_player.play("idle")
	_update_status("Block completo: %s" % anim_name)


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
	if _loading:
		return
	_offset_pos = Vector3(_sl_px.value, _sl_py.value, _sl_pz.value)
	_sync_pos_labels()
	_apply_weapon_transform()
	_refresh_copy_label()


func _on_rot_changed(_v: float) -> void:
	if _loading:
		return
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
	_update_status("Copiado al portapapeles")


func _on_reset_pressed() -> void:
	_offset_pos = Vector3.ZERO
	_offset_rot = Vector3.ZERO
	if _sl_px:
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
	_update_status("Offsets reseteados a cero")


# ══════════════════════════════════════════════════════════════
# ██  LÓGICA INTERNA  █████████████████████████████████████████
# ══════════════════════════════════════════════════════════════

# ── Aplicar transform al arma en tiempo real ─────────────────

func _apply_weapon_transform() -> void:
	if not is_instance_valid(_unit):
		return
	# Determinar en qué mano está el modelo 3D
	var hand: int = _get_weapon_visual_slot()
	var weapon_node: Node3D = null
	if hand == 1:
		weapon_node = _unit.get("_equipped_weapon_l") as Node3D
	else:
		weapon_node = _unit.get("_equipped_weapon_r") as Node3D

	if not is_instance_valid(weapon_node):
		return

	weapon_node.position = _offset_pos
	weapon_node.rotation = _offset_rot


## Retorna en qué mano (0=der, 1=izq) está el modelo visual del arma actual.
func _get_weapon_visual_slot() -> int:
	if not _current_weapon_data:
		return 0
	var slot_mode = _current_weapon_data.get("slot")
	if slot_mode == WeaponData.SlotMode.TWO_HANDED:
		# 2H: visual_hand decide la mano del modelo
		return _visual_hand
	elif slot_mode == WeaponData.SlotMode.LEFT_HAND:
		return 1
	else:
		return 0


func _reequip_weapon() -> void:
	if not is_instance_valid(_unit) or not _unit.has_method("equip_weapon_data"):
		return
	if not _current_weapon_data:
		return
	# Cambiar visual_hand en memoria y re-equipar
	_current_weapon_data.set("visual_hand", _visual_hand)
	# Limpiar ambas manos
	if _unit.has_method("unequip_weapon_data"):
		_unit.call("unequip_weapon_data", 0)
		_unit.call("unequip_weapon_data", 1)
	var equip_slot: int = 0
	if _current_weapon_data.get("slot") == WeaponData.SlotMode.LEFT_HAND:
		equip_slot = 1
	_unit.call("equip_weapon_data", _current_weapon_data, equip_slot)
	await get_tree().process_frame
	_apply_weapon_transform()


# ── Helpers de UI ────────────────────────────────────────────

func _sync_pos_labels() -> void:
	if _lbl_px: _lbl_px.text = "%.3f" % _offset_pos.x
	if _lbl_py: _lbl_py.text = "%.3f" % _offset_pos.y
	if _lbl_pz: _lbl_pz.text = "%.3f" % _offset_pos.z


func _sync_rot_labels() -> void:
	if _sl_rx and _lbl_rx: _lbl_rx.text = "%.1f" % _sl_rx.value
	if _sl_ry and _lbl_ry: _lbl_ry.text = "%.1f" % _sl_ry.value
	if _sl_rz and _lbl_rz: _lbl_rz.text = "%.1f" % _sl_rz.value


func _refresh_copy_label() -> void:
	if _copy_label:
		_copy_label.text = _build_copy_text()


func _build_copy_text() -> String:
	var hand_names := ["RIGHT_HAND", "LEFT_HAND"]
	var lines: PackedStringArray = []

	# ── Encabezado con info del arma ──────────────────────────
	if _current_weapon_data:
		var wname: String = _current_weapon_data.get("display_name") if _current_weapon_data.get("display_name") != null else "?"
		lines.append("# Arma: %s" % wname)
		lines.append("# Archivo: %s" % _current_weapon_path.get_file())
	else:
		lines.append("# (sin arma seleccionada)")

	lines.append("")

	# ── Offsets (lo que se pega en el .tres) ──────────────────
	lines.append("visual_hand = %d  # %s" % [_visual_hand, hand_names[_visual_hand]])
	lines.append("hand_offset_pos = Vector3(%.4f, %.4f, %.4f)" % [_offset_pos.x, _offset_pos.y, _offset_pos.z])
	lines.append("hand_offset_rot = Vector3(%.4f, %.4f, %.4f)" % [_offset_rot.x, _offset_rot.y, _offset_rot.z])

	# ── Datos extra del arma ──────────────────────────────────
	if _current_weapon_data:
		lines.append("")
		lines.append("# --- Stats ---")
		lines.append("bonus_physical_damage = %d" % int(_current_weapon_data.get("bonus_physical_damage")))
		lines.append("bonus_magic_damage = %d" % int(_current_weapon_data.get("bonus_magic_damage")))
		lines.append("bonus_armor = %d" % int(_current_weapon_data.get("bonus_armor")))
		lines.append("bonus_magic_resist = %d" % int(_current_weapon_data.get("bonus_magic_resist")))
		lines.append("bonus_speed = %d" % int(_current_weapon_data.get("bonus_speed")))
		lines.append("bonus_evasion = %.2f" % float(_current_weapon_data.get("bonus_evasion")))
		lines.append("bonus_crit_chance = %.2f" % float(_current_weapon_data.get("bonus_crit_chance")))
		lines.append("buy_price = %d" % int(_current_weapon_data.get("buy_price")))
		lines.append("sell_price = %d" % int(_current_weapon_data.get("sell_price")))

		var scene_path: String = _current_weapon_data.get("scene_3d_path") if _current_weapon_data.get("scene_3d_path") != null else ""
		if not scene_path.is_empty():
			lines.append("scene_3d_path = \"%s\"" % scene_path)

		var abilities = _current_weapon_data.get("abilities")
		if abilities and abilities is Array and abilities.size() > 0:
			lines.append("")
			lines.append("# Abilities (%d):" % abilities.size())
			for ab in abilities:
				if ab is Dictionary:
					var aname: String = ab.get("display_name", "?")
					var anim: String  = ab.get("anim_name", "")
					var phys: int     = ab.get("physical", 0)
					var mag: int      = ab.get("magic", 0)
					var hit: float    = ab.get("hit_chance", 0.0)
					var rng: int      = ab.get("range", 1)
					lines.append("#   [%s] phys=%d  mag=%d  hit=%.0f%%  range=%d  anim=%s" % [aname, phys, mag, hit * 100, rng, anim])

	return "\n".join(lines)


func _update_status(msg: String) -> void:
	if _status_label:
		_status_label.text = msg


func _update_loop_button() -> void:
	if _loop_button:
		_loop_button.text = "Loop: %s" % ("ON" if _loop_active else "OFF")
		_loop_button.modulate = Color(0.4, 1.0, 0.4) if _loop_active else Color.WHITE


# ── Reproducción de animaciones ──────────────────────────────

func _play_anim(anim_name: String) -> void:
	if not _anim_player or not _anim_player.has_animation(anim_name):
		return
	_anim_player.stop()
	_anim_player.play(anim_name)
	_update_status("Playing: %s" % anim_name)

	# FIX: desconectar señal anterior antes de reconectar (evita ERR_INVALID_PARAMETER)
	if _anim_player.animation_finished.is_connected(_on_anim_ended_once):
		_anim_player.animation_finished.disconnect(_on_anim_ended_once)
	if _anim_player.animation_finished.is_connected(_on_anim_ended_loop):
		_anim_player.animation_finished.disconnect(_on_anim_ended_loop)

	if _loop_active:
		_anim_player.animation_finished.connect(_on_anim_ended_loop, CONNECT_ONE_SHOT)
	else:
		_anim_player.animation_finished.connect(_on_anim_ended_once, CONNECT_ONE_SHOT)


func _on_anim_ended_once(_n: StringName) -> void:
	if _anim_player and _anim_player.has_animation("idle"):
		_anim_player.play("idle")
	_update_status("Terminó: '%s'" % _current_anim)


func _on_anim_ended_loop(_n: StringName) -> void:
	if _loop_active and not _current_anim.is_empty():
		_play_anim_loop(_current_anim)


func _play_anim_loop(anim_name: String) -> void:
	if not _anim_player or not _anim_player.has_animation(anim_name):
		return
	_anim_player.stop()
	_anim_player.play(anim_name)
	_update_status("Loop: %s" % anim_name)

	# FIX: asegurar que no haya conexiones duplicadas
	if _anim_player.animation_finished.is_connected(_on_anim_ended_once):
		_anim_player.animation_finished.disconnect(_on_anim_ended_once)
	if _anim_player.animation_finished.is_connected(_on_anim_ended_loop):
		_anim_player.animation_finished.disconnect(_on_anim_ended_loop)

	_anim_player.animation_finished.connect(_on_anim_ended_loop, CONNECT_ONE_SHOT)


## Devuelve el MeshInstance3D del arma equipada (para blend shapes de arco).
func _get_preview_bow_mesh() -> MeshInstance3D:
	if not is_instance_valid(_unit):
		return null
	var hand: int = _get_weapon_visual_slot()
	var bow_root: Node3D = null
	if hand == 1:
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

	# Desconectar señales previas
	if _anim_player.animation_finished.is_connected(_on_anim_ended_once):
		_anim_player.animation_finished.disconnect(_on_anim_ended_once)
	if _anim_player.animation_finished.is_connected(_on_anim_ended_loop):
		_anim_player.animation_finished.disconnect(_on_anim_ended_loop)

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
		_update_status("Playing: %s" % draw_anim)
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
		_update_status("Playing: %s" % release_anim)
		await _anim_player.animation_finished

	if bs_idx >= 0 and is_instance_valid(bow_mesh):
		bow_mesh.set_blend_shape_value(bs_idx, 0.0)
	if _anim_player.has_animation("idle"):
		_anim_player.play("idle")
	_update_status("Secuencia completa")


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
