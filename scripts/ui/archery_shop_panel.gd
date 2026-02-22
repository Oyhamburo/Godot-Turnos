extends PanelContainer
class_name ArcheryShopPanel
##
## Panel de la Arquería (Campo de Tiro): tienda de arcos y ballestas.
## Layout: Catálogo (izq) | Preview 3D + Stats (centro) | PersonalInventoryPanel real (der).
## Click en un arma del catálogo → muestra preview grande + stats + botón comprar.
## Construido 100% por código, sin .tscn.
##

signal panel_closed

const C_SEPARATOR := Color(0.25, 0.28, 0.40, 1.0)
const C_HEADER    := Color(0.70, 0.78, 0.95, 1.0)
const C_GOLD      := Color(1.0, 0.85, 0.3, 1.0)
const C_TEXT      := Color(0.92, 0.93, 0.98, 1.0)
const C_SUBTEXT   := Color(0.55, 0.58, 0.72, 1.0)
const C_MSG_OK    := Color(0.4, 0.9, 0.45, 1.0)
const C_MSG_ERR   := Color(1.0, 0.4, 0.4, 1.0)
const PANEL_SIZE  := Vector2(1100, 580)

const CATALOGO_PATHS := [
	"res://data/weapons/bow_simple.tres",
	"res://data/weapons/player_bow.tres",
	"res://data/weapons/bow_longbow.tres",
	"res://data/weapons/crossbow_1handed.tres",
	"res://data/weapons/crossbow_2handed.tres",
]

var _inventory: Inventory = null
var _selected_weapon: WeaponData = null
var _selected_row: WeaponShopRow = null

var _gold_label: Label
var _msg_label: Label
var _msg_timer: float = 0.0
var _weapon_list: VBoxContainer
var _preview_anchor: Node3D
var _nombre_label: Label
var _tipo_label: Label
var _stats_box: VBoxContainer
var _abilities_box: VBoxContainer
var _btn_comprar: Button

## El panel de inventario personal real (mismo que se abre con 'I')
var _inv_panel: PersonalInventoryPanel = null

var _dragging_preview: bool = false
var _preview_yaw: float = 0.0


func _init() -> void:
	custom_minimum_size = PANEL_SIZE
	_build_ui()
	_poblar_catalogo()


# ══════════════════════════════════════════════════════════════
# BUILD UI
# ══════════════════════════════════════════════════════════════

func _build_ui() -> void:
	var bg := StyleBoxTexture.new()
	const TEX_PANEL := "res://assets/kenney_ui-pack-rpg-expansion/PNG/panel_blue.png"
	if ResourceLoader.exists(TEX_PANEL):
		bg.texture = load(TEX_PANEL)
	bg.texture_margin_left = 16; bg.texture_margin_right = 16
	bg.texture_margin_top = 16; bg.texture_margin_bottom = 16
	add_theme_stylebox_override("panel", bg)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	add_child(vbox)

	# ── Cabecera ──
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	vbox.add_child(header)

	var titulo := Label.new()
	titulo.text = "🏹 CAMPO DE TIRO"
	titulo.add_theme_font_size_override("font_size", 18)
	titulo.add_theme_color_override("font_color", C_HEADER)
	titulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(titulo)

	_gold_label = Label.new()
	_gold_label.text = "🪙 Oro: 0"
	_gold_label.add_theme_font_size_override("font_size", 15)
	_gold_label.add_theme_color_override("font_color", C_GOLD)
	header.add_child(_gold_label)

	var btn_cerrar := _make_kenney_button("✕", 30, 30)
	btn_cerrar.pressed.connect(_on_cerrar)
	header.add_child(btn_cerrar)

	var sep := HSeparator.new()
	sep.add_theme_color_override("color", C_SEPARATOR)
	vbox.add_child(sep)

	_msg_label = Label.new()
	_msg_label.add_theme_font_size_override("font_size", 13)
	_msg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_msg_label.visible = false
	vbox.add_child(_msg_label)

	# ── Cuerpo: 3 secciones ──
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(body)

	_build_catalog_column(body)
	_build_center_column(body)
	_build_inventory_column(body)


func _build_catalog_column(parent: HBoxContainer) -> void:
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(210, 0)
	col.add_theme_constant_override("separation", 4)
	parent.add_child(col)

	var lbl := Label.new()
	lbl.text = "▼ Arcos y Ballestas"
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", C_HEADER)
	col.add_child(lbl)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(scroll)

	_weapon_list = VBoxContainer.new()
	_weapon_list.add_theme_constant_override("separation", 3)
	scroll.add_child(_weapon_list)


func _build_center_column(parent: HBoxContainer) -> void:
	var vsep1 := VSeparator.new()
	vsep1.add_theme_color_override("color", C_SEPARATOR)
	parent.add_child(vsep1)

	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2(320, 0)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 4)
	parent.add_child(col)

	# ── Preview 3D (parte superior) ──
	var preview_label := Label.new()
	preview_label.text = "Vista previa (arrastrá para rotar)"
	preview_label.add_theme_font_size_override("font_size", 11)
	preview_label.add_theme_color_override("font_color", C_SUBTEXT)
	preview_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(preview_label)

	var svc := SubViewportContainer.new()
	svc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	svc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	svc.stretch = true
	svc.mouse_filter = Control.MOUSE_FILTER_STOP
	svc.gui_input.connect(_on_preview_gui_input)
	col.add_child(svc)

	var sv := SubViewport.new()
	sv.size = Vector2i(280, 300)
	sv.transparent_bg = true
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	sv.world_3d = World3D.new()
	svc.add_child(sv)

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.08, 0.09, 0.15, 0.0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.85, 0.85, 0.95, 1.0)
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	sv.add_child(world_env)

	var cam := Camera3D.new()
	var cam_pos := Vector3(0, 0.3, 1.5)
	var cam_target := Vector3(0, 0.1, 0)
	var fwd := (cam_target - cam_pos).normalized()
	var right_vec := Vector3.UP.cross(fwd).normalized()
	var up_vec := fwd.cross(right_vec)
	cam.transform = Transform3D(Basis(right_vec, up_vec, -fwd), cam_pos)
	sv.add_child(cam)

	var dlight := DirectionalLight3D.new()
	dlight.rotation_degrees = Vector3(-40, 30, 0)
	dlight.light_energy = 2.0
	sv.add_child(dlight)

	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(30, -60, 0)
	fill.light_energy = 0.8
	fill.light_color = Color(0.85, 0.9, 1.0)
	sv.add_child(fill)

	_preview_anchor = Node3D.new()
	sv.add_child(_preview_anchor)

	# ── Panel de detalles (parte inferior del centro) ──
	var detail_sep := HSeparator.new()
	detail_sep.add_theme_color_override("color", C_SEPARATOR)
	col.add_child(detail_sep)

	_nombre_label = Label.new()
	_nombre_label.text = "Seleccioná un arma"
	_nombre_label.add_theme_font_size_override("font_size", 16)
	_nombre_label.add_theme_color_override("font_color", C_TEXT)
	_nombre_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_nombre_label)

	_tipo_label = Label.new()
	_tipo_label.add_theme_font_size_override("font_size", 12)
	_tipo_label.add_theme_color_override("font_color", C_SUBTEXT)
	_tipo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_tipo_label)

	# Stats + habilidades en un HBox debajo del nombre
	var detail_hbox := HBoxContainer.new()
	detail_hbox.add_theme_constant_override("separation", 14)
	col.add_child(detail_hbox)

	# Stats lado izq
	var stats_col := VBoxContainer.new()
	stats_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_hbox.add_child(stats_col)

	var lbl_stats := Label.new()
	lbl_stats.text = "⚔ Estadísticas"
	lbl_stats.add_theme_font_size_override("font_size", 13)
	lbl_stats.add_theme_color_override("font_color", C_HEADER)
	stats_col.add_child(lbl_stats)

	_stats_box = VBoxContainer.new()
	_stats_box.add_theme_constant_override("separation", 2)
	stats_col.add_child(_stats_box)

	# Habilidades lado der
	var abi_col := VBoxContainer.new()
	abi_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_hbox.add_child(abi_col)

	var lbl_abi := Label.new()
	lbl_abi.text = "✦ Habilidades"
	lbl_abi.add_theme_font_size_override("font_size", 13)
	lbl_abi.add_theme_color_override("font_color", C_HEADER)
	abi_col.add_child(lbl_abi)

	_abilities_box = VBoxContainer.new()
	_abilities_box.add_theme_constant_override("separation", 3)
	abi_col.add_child(_abilities_box)

	# Botón comprar
	_btn_comprar = _make_kenney_button("Comprar — 🪙 0", 0, 36)
	_btn_comprar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_comprar.disabled = true
	_btn_comprar.pressed.connect(_on_comprar)
	col.add_child(_btn_comprar)


func _build_inventory_column(parent: HBoxContainer) -> void:
	var vsep2 := VSeparator.new()
	vsep2.add_theme_color_override("color", C_SEPARATOR)
	parent.add_child(vsep2)

	# Incrustar el PersonalInventoryPanel real
	_inv_panel = PersonalInventoryPanel.new()
	_inv_panel.set_embedded_mode(true)
	_inv_panel.custom_minimum_size = Vector2(460, 0)
	_inv_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_inv_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(_inv_panel)


# ══════════════════════════════════════════════════════════════
# CATÁLOGO
# ══════════════════════════════════════════════════════════════

func _poblar_catalogo() -> void:
	for path in CATALOGO_PATHS:
		if not ResourceLoader.exists(path):
			continue
		var weapon: WeaponData = load(path) as WeaponData
		if weapon == null:
			continue
		var row := WeaponShopRow.new(weapon)
		row.seleccionado.connect(_on_catalogo_seleccionado)
		_weapon_list.add_child(row)

	if _weapon_list.get_child_count() > 0:
		var first_row := _weapon_list.get_child(0) as WeaponShopRow
		if first_row:
			_on_catalogo_seleccionado(first_row.weapon)
			first_row.set_selected(true)
			_selected_row = first_row


# ══════════════════════════════════════════════════════════════
# SETUP
# ══════════════════════════════════════════════════════════════

func setup(inv: Inventory) -> void:
	_inventory = inv
	if inv and not inv.inventory_changed.is_connected(_on_inventory_changed):
		inv.inventory_changed.connect(_on_inventory_changed)
	_refresh_gold()
	# Vincular el inventario al panel personal incrustado
	if _inv_panel:
		_inv_panel.setup(inv)


func _on_inventory_changed() -> void:
	_refresh_gold()


# ══════════════════════════════════════════════════════════════
# SELECCIÓN DEL CATÁLOGO
# ══════════════════════════════════════════════════════════════

func _on_catalogo_seleccionado(weapon: WeaponData) -> void:
	# Deseleccionar row anterior
	if _selected_row:
		_selected_row.set_selected(false)
		_selected_row = null

	# Seleccionar fila del catálogo
	for child in _weapon_list.get_children():
		var row := child as WeaponShopRow
		if row and row.weapon == weapon:
			row.set_selected(true)
			_selected_row = row
			break

	_selected_weapon = weapon

	# ── Preview 3D ──
	for c in _preview_anchor.get_children():
		c.queue_free()
	if weapon.scene_3d_path != "" and ResourceLoader.exists(weapon.scene_3d_path):
		var packed: PackedScene = load(weapon.scene_3d_path)
		if packed:
			var inst: Node3D = packed.instantiate()
			inst.scale = Vector3.ONE * 0.45
			_preview_anchor.add_child(inst)

	_preview_yaw = 0.0
	_preview_anchor.rotation.y = 0.0

	# ── Nombre y tipo ──
	_nombre_label.text = weapon.display_name
	_tipo_label.text = "%s · %s" % [_get_type_name(weapon), _get_slot_name(weapon)]

	# ── Stats ──
	_refresh_stats(weapon)

	# ── Habilidades ──
	_refresh_abilities(weapon)

	# ── Botón comprar ──
	_btn_comprar.text = "Comprar — 🪙 %d" % weapon.buy_price
	_btn_comprar.disabled = false


func _refresh_stats(weapon: WeaponData) -> void:
	for c in _stats_box.get_children():
		c.queue_free()

	var stat_entries: Array[Array] = [
		["⚔ Atq fís", weapon.bonus_physical_damage, false],
		["✨ Atq mág", weapon.bonus_magic_damage, false],
		["🛡 Armadura", weapon.bonus_armor, false],
		["🔮 Res mág", weapon.bonus_magic_resist, false],
		["💨 Velocidad", weapon.bonus_speed, false],
		["🌀 Evasión", weapon.bonus_evasion, true],
		["💥 Crítico", weapon.bonus_crit_chance, true],
	]
	for entry in stat_entries:
		var val = entry[1]
		if val == 0 or val == 0.0:
			continue
		var lbl := Label.new()
		var sign_txt: String = "+" if val > 0 else ""
		if entry[2]:  # is_float (porcentaje)
			lbl.text = "%s: %s%d%%" % [entry[0], sign_txt, int(val * 100)]
		else:
			lbl.text = "%s: %s%d" % [entry[0], sign_txt, val]
		lbl.add_theme_font_size_override("font_size", 12)
		lbl.add_theme_color_override("font_color", C_TEXT)
		_stats_box.add_child(lbl)

	if _stats_box.get_child_count() == 0:
		var lbl := Label.new()
		lbl.text = "Sin bonificaciones"
		lbl.add_theme_font_size_override("font_size", 12)
		lbl.add_theme_color_override("font_color", C_SUBTEXT)
		_stats_box.add_child(lbl)


func _refresh_abilities(weapon: WeaponData) -> void:
	for c in _abilities_box.get_children():
		c.queue_free()

	for abi in weapon.abilities:
		var lbl := Label.new()
		var abi_name: String = abi.get("display_name", "Habilidad")
		var phys: int = abi.get("physical", 0)
		var mag: int = abi.get("magic", 0)
		var hit: float = abi.get("hit_chance", 1.0)
		var rng: int = abi.get("range", 1)
		var aoe: int = abi.get("aoe_radius", 0)

		var dmg_txt: String = ""
		if phys > 0 and mag > 0:
			dmg_txt = "%dfís+%dmág" % [phys, mag]
		elif phys > 0:
			dmg_txt = "%d fís" % phys
		elif mag > 0:
			dmg_txt = "%d mág" % mag
		else:
			dmg_txt = "—"

		var rng_txt: String = "CaC" if rng <= 1 else ("Dist" if rng >= 99 else "R%d" % rng)
		var aoe_txt: String = " AoE%d" % aoe if aoe > 0 else ""
		lbl.text = "• %s: %s %d%% %s%s" % [abi_name, dmg_txt, int(hit * 100), rng_txt, aoe_txt]
		lbl.add_theme_font_size_override("font_size", 12)
		lbl.add_theme_color_override("font_color", C_TEXT)
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		_abilities_box.add_child(lbl)

	if _abilities_box.get_child_count() == 0:
		var lbl := Label.new()
		lbl.text = "Sin habilidades"
		lbl.add_theme_font_size_override("font_size", 12)
		lbl.add_theme_color_override("font_color", C_SUBTEXT)
		_abilities_box.add_child(lbl)


# ══════════════════════════════════════════════════════════════
# COMPRAR
# ══════════════════════════════════════════════════════════════

func _on_comprar() -> void:
	if _selected_weapon == null or _inventory == null:
		return
	if _inventory.gold < _selected_weapon.buy_price:
		_mostrar_mensaje("Sin oro suficiente", false)
		return
	_inventory.spend_gold(_selected_weapon.buy_price)
	_inventory.add_weapon(_selected_weapon.duplicate())
	_mostrar_mensaje("¡%s comprado!" % _selected_weapon.display_name, true)
	_refresh_gold()


# ══════════════════════════════════════════════════════════════
# AUXILIARES
# ══════════════════════════════════════════════════════════════

func _refresh_gold() -> void:
	if _inventory and _gold_label:
		_gold_label.text = "🪙 Oro: %d" % _inventory.gold


func _mostrar_mensaje(txt: String, ok: bool) -> void:
	_msg_label.text = txt
	_msg_label.add_theme_color_override("font_color", C_MSG_OK if ok else C_MSG_ERR)
	_msg_label.visible = true
	_msg_timer = 3.0


func _process(delta: float) -> void:
	if _msg_timer > 0.0:
		_msg_timer -= delta
		if _msg_timer <= 0.0:
			_msg_label.visible = false


func _on_preview_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_dragging_preview = event.pressed
	elif event is InputEventMouseMotion and _dragging_preview:
		_preview_yaw += event.relative.x * 0.01
		if _preview_anchor:
			_preview_anchor.rotation.y = _preview_yaw


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		_on_cerrar()
		get_viewport().set_input_as_handled()


func _on_cerrar() -> void:
	visible = false
	panel_closed.emit()


func _get_type_name(weapon: WeaponData) -> String:
	match weapon.weapon_type:
		WeaponData.WeaponType.BOW:     return "Arco"
		WeaponData.WeaponType.SWORD:   return "Espada"
		WeaponData.WeaponType.AXE:     return "Hacha"
		WeaponData.WeaponType.DAGGER:  return "Daga"
		WeaponData.WeaponType.SHIELD:  return "Escudo"
		WeaponData.WeaponType.STAFF:   return "Bastón"
		WeaponData.WeaponType.WAND:    return "Varita"
		_: return "Arma"


func _get_slot_name(weapon: WeaponData) -> String:
	match weapon.slot:
		WeaponData.SlotMode.RIGHT_HAND:  return "Una mano"
		WeaponData.SlotMode.LEFT_HAND:   return "Mano izquierda"
		WeaponData.SlotMode.TWO_HANDED:  return "Dos manos"
		_: return ""


static func _make_kenney_button(txt: String, min_w: int, min_h: int) -> Button:
	const TEX_NORMAL  := "res://assets/kenney_ui-pack-rpg-expansion/PNG/buttonLong_blue.png"
	const TEX_PRESSED := "res://assets/kenney_ui-pack-rpg-expansion/PNG/buttonLong_blue_pressed.png"
	var btn := Button.new()
	btn.text = txt
	btn.add_theme_font_size_override("font_size", 13)
	btn.add_theme_color_override("font_color", Color(0.10, 0.12, 0.20, 1.0))
	btn.custom_minimum_size = Vector2(min_w, min_h)
	if ResourceLoader.exists(TEX_NORMAL):
		var sn := StyleBoxTexture.new()
		sn.texture = load(TEX_NORMAL)
		sn.texture_margin_left = 6; sn.texture_margin_right = 6
		sn.texture_margin_top = 4; sn.texture_margin_bottom = 4
		btn.add_theme_stylebox_override("normal", sn)
		btn.add_theme_stylebox_override("hover", sn)
		btn.add_theme_stylebox_override("focus", sn)
	if ResourceLoader.exists(TEX_PRESSED):
		var sp := StyleBoxTexture.new()
		sp.texture = load(TEX_PRESSED)
		sp.texture_margin_left = 6; sp.texture_margin_right = 6
		sp.texture_margin_top = 4; sp.texture_margin_bottom = 4
		btn.add_theme_stylebox_override("pressed", sp)
	return btn
