extends PanelContainer
class_name PersonalInventoryPanel
##
## Panel principal del inventario personal del jugador.
## TabContainer con dos pestañas: "Items" y "Personaje".
## Se instancia por código desde ThirdPersonMap y BattleHUD.
## Soporta modo "embedded" (sin cabecera/cerrar) para uso dentro de WeaponShopPanel.
## No requiere .tscn.
##

## Emitido al cerrar el panel (ESC o botón Cerrar).
signal panel_closed

## Pestaña "Items"
const TAB_ITEMS     := 0
## Pestaña "Personaje"
const TAB_PERSONAJE := 1

const C_BG          := Color(0.05, 0.06, 0.10, 0.96)
const C_PANEL_BG    := Color(0.07, 0.08, 0.14, 0.98)
const C_HEADER      := Color(0.70, 0.78, 0.95, 1.0)
const C_BTN_BG      := Color(0.18, 0.20, 0.28, 1.0)
const C_BTN_HOVER   := Color(0.28, 0.32, 0.45, 1.0)
const C_SEPARATOR   := Color(0.25, 0.28, 0.40, 1.0)
const C_TEXT        := Color(0.92, 0.93, 0.98, 1.0)
const C_GOLD        := Color(1.0, 0.85, 0.3, 1.0)
const PANEL_SIZE    := Vector2(720, 500)

# ── Datos ──────────────────────────────────────────────────────
var _inventory: Inventory = null
var _player_stats: PlayerStats = null

# ── Modo embedded (dentro de tienda) ──────────────────────────
var _embedded: bool = false
var _header_row: HBoxContainer = null

# ── UI principal ───────────────────────────────────────────────
var _tab_container: TabContainer
var _gold_label: Label

# ── Tab Items ──────────────────────────────────────────────────
var _item_grid: ItemGridPanel
var _detail_panel: VBoxContainer
var _detail_nombre: Label
var _detail_desc: Label
var _detail_stats: Label
var _btn_equipar: Button
var _btn_descartar: Button
var _slot_seleccionado: ItemSlot = null

# ── Tab Personaje ──────────────────────────────────────────────
var _character_preview: CharacterPreview
var _model_selector: OptionButton
var _equipment_panel: EquipmentPanel
var _stats_panel: StatsPanel


func _init() -> void:
	custom_minimum_size = PANEL_SIZE
	_build_ui()


## Activa/desactiva modo embedded (oculta cabecera y botón cerrar).
## Llamar ANTES de agregar al árbol.
func set_embedded_mode(on: bool) -> void:
	_embedded = on
	if _header_row:
		_header_row.visible = not on
	# En modo embedded no necesitamos tamaño mínimo propio — lo controla el padre
	if on:
		custom_minimum_size = Vector2(0, 0)


func _build_ui() -> void:
	# Fondo principal — usa panel_blue.png de Kenney si existe, si no StyleBoxFlat
	const TEX_PANEL := "res://assets/kenney_ui-pack-rpg-expansion/PNG/panel_blue.png"
	if ResourceLoader.exists(TEX_PANEL):
		var style_tex := StyleBoxTexture.new()
		style_tex.texture = load(TEX_PANEL)
		style_tex.texture_margin_left = 12; style_tex.texture_margin_right = 12
		style_tex.texture_margin_top = 12; style_tex.texture_margin_bottom = 12
		add_theme_stylebox_override("panel", style_tex)
	else:
		var bg := StyleBoxFlat.new()
		bg.bg_color = C_PANEL_BG
		bg.border_color = C_SEPARATOR
		bg.border_width_left = 2; bg.border_width_right  = 2
		bg.border_width_top  = 2; bg.border_width_bottom = 2
		bg.corner_radius_top_left     = 10; bg.corner_radius_top_right    = 10
		bg.corner_radius_bottom_left  = 10; bg.corner_radius_bottom_right = 10
		add_theme_stylebox_override("panel", bg)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	add_child(vbox)

	# ── Cabecera ──
	_header_row = HBoxContainer.new()
	vbox.add_child(_header_row)

	var titulo := Label.new()
	titulo.text = "⚔ INVENTARIO"
	titulo.add_theme_font_size_override("font_size", 18)
	titulo.add_theme_color_override("font_color", C_HEADER)
	titulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_header_row.add_child(titulo)

	_gold_label = Label.new()
	_gold_label.text = "Oro: 0"
	_gold_label.add_theme_font_size_override("font_size", 15)
	_gold_label.add_theme_color_override("font_color", C_GOLD)
	_gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_header_row.add_child(_gold_label)

	var btn_cerrar := _make_button("✕", 30, 30)
	btn_cerrar.pressed.connect(_on_cerrar)
	_header_row.add_child(btn_cerrar)

	var sep := HSeparator.new()
	sep.add_theme_color_override("color", C_SEPARATOR)
	vbox.add_child(sep)

	# ── TabContainer ──
	_tab_container = TabContainer.new()
	_tab_container.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	_tab_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(_tab_container)

	_build_tab_items()
	_build_tab_personaje()


# ──────────────────────────────────────────────────────────────
# TAB ITEMS
# ──────────────────────────────────────────────────────────────

func _build_tab_items() -> void:
	var root := HBoxContainer.new()
	root.name = "Items"
	root.add_theme_constant_override("separation", 10)
	_tab_container.add_child(root)

	# Grid de ítems (izquierda)
	_item_grid = ItemGridPanel.new()
	_item_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_item_grid.slot_selected.connect(_on_item_slot_selected)
	root.add_child(_item_grid)

	# Panel de detalles (derecha)
	var detail_bg := PanelContainer.new()
	detail_bg.custom_minimum_size = Vector2(220, 0)
	detail_bg.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var dbg := StyleBoxFlat.new()
	dbg.bg_color = C_BG
	dbg.corner_radius_top_left     = 6
	dbg.corner_radius_top_right    = 6
	dbg.corner_radius_bottom_left  = 6
	dbg.corner_radius_bottom_right = 6
	detail_bg.add_theme_stylebox_override("panel", dbg)
	root.add_child(detail_bg)

	_detail_panel = VBoxContainer.new()
	_detail_panel.add_theme_constant_override("separation", 6)
	detail_bg.add_child(_detail_panel)

	var detalle_titulo := Label.new()
	detalle_titulo.text = "DETALLES"
	detalle_titulo.add_theme_font_size_override("font_size", 13)
	detalle_titulo.add_theme_color_override("font_color", C_HEADER)
	detalle_titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail_panel.add_child(detalle_titulo)

	var sep2 := HSeparator.new()
	_detail_panel.add_child(sep2)

	_detail_nombre = Label.new()
	_detail_nombre.text = "—"
	_detail_nombre.add_theme_font_size_override("font_size", 15)
	_detail_nombre.add_theme_color_override("font_color", C_TEXT)
	_detail_nombre.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_panel.add_child(_detail_nombre)

	_detail_desc = Label.new()
	_detail_desc.text = ""
	_detail_desc.add_theme_font_size_override("font_size", 13)
	_detail_desc.add_theme_color_override("font_color", Color(0.7, 0.72, 0.8, 1))
	_detail_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_panel.add_child(_detail_desc)

	_detail_stats = Label.new()
	_detail_stats.text = ""
	_detail_stats.add_theme_font_size_override("font_size", 13)
	_detail_stats.add_theme_color_override("font_color", Color(0.5, 0.92, 0.55, 1))
	_detail_stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_panel.add_child(_detail_stats)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail_panel.add_child(spacer)

	# Botones de acción
	_btn_equipar = _make_button("Equipar", -1, 34)
	_btn_equipar.pressed.connect(_on_equipar_pressed)
	_btn_equipar.disabled = true
	_detail_panel.add_child(_btn_equipar)

	_btn_descartar = _make_button("Descartar", -1, 34)
	_btn_descartar.pressed.connect(_on_descartar_pressed)
	_btn_descartar.disabled = true
	_btn_descartar.add_theme_color_override(
		"font_color", Color(1.0, 0.5, 0.5, 1.0)
	)
	_detail_panel.add_child(_btn_descartar)


# ──────────────────────────────────────────────────────────────
# TAB PERSONAJE
# ──────────────────────────────────────────────────────────────

func _build_tab_personaje() -> void:
	var root := HBoxContainer.new()
	root.name = "Personaje"
	root.add_theme_constant_override("separation", 12)
	_tab_container.add_child(root)

	# ── Columna izquierda: preview + selector ──
	var left_col := VBoxContainer.new()
	left_col.add_theme_constant_override("separation", 6)
	root.add_child(left_col)

	# Selector de modelo
	_model_selector = OptionButton.new()
	_model_selector.add_theme_font_size_override("font_size", 13)
	left_col.add_child(_model_selector)

	# Preview 3D
	_character_preview = CharacterPreview.new()
	left_col.add_child(_character_preview)

	# Llenar opciones del selector después de construir el preview
	for nombre in _character_preview.get_model_names():
		_model_selector.add_item(nombre)
	_model_selector.item_selected.connect(_on_model_selected)

	# ── Columna centro: equipamiento ──
	var center_col := VBoxContainer.new()
	center_col.add_theme_constant_override("separation", 6)
	center_col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(center_col)

	_equipment_panel = EquipmentPanel.new()
	_equipment_panel.equip_requested.connect(_on_equip_requested)
	_equipment_panel.unequip_requested.connect(_on_unequip_requested)
	_equipment_panel.slot_selected.connect(_on_equip_slot_selected)
	center_col.add_child(_equipment_panel)

	# ── Columna derecha: stats ──
	var right_col := VBoxContainer.new()
	right_col.add_theme_constant_override("separation", 6)
	right_col.custom_minimum_size = Vector2(150, 0)
	right_col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(right_col)

	_stats_panel = StatsPanel.new()
	right_col.add_child(_stats_panel)


# ──────────────────────────────────────────────────────────────
# SETUP
# ──────────────────────────────────────────────────────────────

## Vincula el inventario del jugador. Llamar tras instanciar.
func setup(inv: Inventory) -> void:
	_inventory = inv
	if inv:
		if not inv.inventory_changed.is_connected(_on_inventory_changed):
			inv.inventory_changed.connect(_on_inventory_changed)

		# EquipmentData
		var equip := inv.get_or_create_equipment()

		# PlayerStats
		if _player_stats == null:
			_player_stats = PlayerStats.new()
		_player_stats.bind_equipment(equip)

		# Vincular componentes
		_item_grid.setup(inv)
		_equipment_panel.setup(equip, _player_stats)
		_equipment_panel.set_grid_panel(_item_grid)
		_stats_panel.setup(_player_stats)

		_refresh_gold()

	# Mostrar Knight por defecto
	if _model_selector.item_count > 0:
		_on_model_selected(0)


## Abre el panel en la pestaña indicada (TAB_ITEMS o TAB_PERSONAJE).
func open_at_tab(tab: int) -> void:
	visible = true
	_tab_container.current_tab = tab


# ──────────────────────────────────────────────────────────────
# CALLBACKS INTERNOS
# ──────────────────────────────────────────────────────────────

func _on_cerrar() -> void:
	visible = false
	panel_closed.emit()


func _on_inventory_changed() -> void:
	_refresh_gold()
	_item_grid.refresh()


func _refresh_gold() -> void:
	if _inventory and _gold_label:
		_gold_label.text = "🪙 Oro: %d" % _inventory.gold


func _on_item_slot_selected(slot: ItemSlot) -> void:
	_slot_seleccionado = slot
	var item = slot.item
	if item == null:
		_detail_nombre.text = "—"
		_detail_desc.text = ""
		_detail_stats.text = ""
		_btn_equipar.disabled = true
		_btn_descartar.disabled = true
		return

	var nombre: String = item.display_name if "display_name" in item else "Ítem"
	var desc: String   = item.description  if "description"  in item else ""
	_detail_nombre.text = nombre
	_detail_desc.text   = desc
	_detail_stats.text  = _format_stats_mod(item)
	_btn_equipar.disabled  = false
	_btn_descartar.disabled = false

	# Preview de diff en stats
	if _player_stats and _inventory:
		var slot_target := _equipment_panel._get_slot_for_item(item)
		if slot_target != "":
			var diff := _player_stats.get_display_diff(slot_target, item)
			_stats_panel.show_diff(diff)
		else:
			_stats_panel.clear_diff()


func _format_stats_mod(item) -> String:
	if item is WeaponData:
		var parts: Array = []
		if item.bonus_physical_damage != 0:
			parts.append("⚔ ATQ FÍS: %s%d" % ["+" if item.bonus_physical_damage > 0 else "", item.bonus_physical_damage])
		if item.bonus_magic_damage != 0:
			parts.append("✨ ATQ MÁG: %s%d" % ["+" if item.bonus_magic_damage > 0 else "", item.bonus_magic_damage])
		if item.bonus_armor != 0:
			parts.append("🛡 ARMADURA: %s%d" % ["+" if item.bonus_armor > 0 else "", item.bonus_armor])
		if item.bonus_magic_resist != 0:
			parts.append("🔮 RES MÁG: %s%d" % ["+" if item.bonus_magic_resist > 0 else "", item.bonus_magic_resist])
		if item.bonus_speed != 0:
			parts.append("💨 VEL: %s%d" % ["+" if item.bonus_speed > 0 else "", item.bonus_speed])
		if item.bonus_evasion != 0.0:
			parts.append("🌀 EVASIÓN: +%d%%" % int(item.bonus_evasion * 100))
		if item.bonus_crit_chance != 0.0:
			parts.append("💥 CRÍTICO: +%d%%" % int(item.bonus_crit_chance * 100))
		return "\n".join(parts) if parts.size() > 0 else ""

	var mods: Dictionary = {}
	if item is ArmorData:
		mods = item.stats_mod
	elif item is ItemData:
		mods = item.stats_mod
	if mods.is_empty():
		return ""
	var mod_parts: Array = []
	for k in mods:
		var v: int = mods[k]
		if v != 0:
			mod_parts.append("%s: %s%d" % [k.to_upper(), "+" if v > 0 else "", v])
	return "\n".join(mod_parts)


func _on_equipar_pressed() -> void:
	if _slot_seleccionado == null or _inventory == null:
		return
	var item = _slot_seleccionado.item
	if item == null:
		return
	var ok := _equipment_panel.try_equip(item, _inventory)
	if ok:
		_slot_seleccionado = null
		_btn_equipar.disabled  = true
		_btn_descartar.disabled = true
		_detail_nombre.text = "—"
		_detail_desc.text   = ""
		_detail_stats.text  = ""
		_stats_panel.clear_diff()


func _on_descartar_pressed() -> void:
	if _slot_seleccionado == null or _inventory == null:
		return
	var item = _slot_seleccionado.item
	if item == null:
		return
	if item is WeaponData:
		_inventory.remove_weapon(item)
	else:
		_inventory.remove_item_generic(item)
	_slot_seleccionado = null
	_btn_equipar.disabled   = true
	_btn_descartar.disabled = true
	_detail_nombre.text = "—"
	_detail_desc.text   = ""
	_detail_stats.text  = ""
	_stats_panel.clear_diff()


func _on_equip_requested(item, slot_name: String) -> void:
	# Llamado cuando se arrastra del grid al slot de equipo
	if _inventory == null:
		return
	var equip := _inventory.get_or_create_equipment()
	if not equip.is_slot_compatible(slot_name, item):
		_equipment_panel.mostrar_mensaje("Ese ítem no va en ese slot")
		return
	var item_viejo = equip.unequip(slot_name)
	equip.equip(slot_name, item)
	_inventory.remove_item_generic(item)
	if item_viejo != null:
		if not _inventory.add_item_generic(item_viejo):
			# Revertir todo
			equip.equip(slot_name, item_viejo)
			_inventory.add_item_generic(item)
			_equipment_panel.mostrar_mensaje("Inventario lleno")


func _on_unequip_requested(slot_name: String) -> void:
	if _inventory == null:
		return
	_equipment_panel.try_unequip(slot_name, _inventory)


func _on_equip_slot_selected(slot_name: String, item) -> void:
	# Mostrar diff cuando se selecciona un slot ocupado
	if item != null and _player_stats:
		var diff := _player_stats.get_display_diff(slot_name, null)
		_stats_panel.show_diff(diff)


func _on_model_selected(index: int) -> void:
	if _character_preview == null:
		return
	var nombres := _character_preview.get_model_names()
	if index < nombres.size():
		_character_preview.swap_model(nombres[index])


# ──────────────────────────────────────────────────────────────
# INPUT
# ──────────────────────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	# En modo embedded, no manejar ESC (lo maneja el panel padre)
	if _embedded:
		return
	if event.is_action_pressed("ui_cancel"):
		_on_cerrar()
		get_viewport().set_input_as_handled()


# ──────────────────────────────────────────────────────────────
# HELPERS
# ──────────────────────────────────────────────────────────────

func _make_button(txt: String, min_w: int = -1, min_h: int = 32) -> Button:
	const TEX_NORMAL  := "res://assets/kenney_ui-pack-rpg-expansion/PNG/buttonLong_blue.png"
	const TEX_PRESSED := "res://assets/kenney_ui-pack-rpg-expansion/PNG/buttonLong_blue_pressed.png"
	var btn := Button.new()
	btn.text = txt
	btn.add_theme_font_size_override("font_size", 13)
	# Texto oscuro sobre botón azul Kenney
	btn.add_theme_color_override("font_color", Color(0.10, 0.12, 0.22, 1.0))
	btn.add_theme_color_override("font_hover_color", Color(0.05, 0.08, 0.18, 1.0))
	if min_w > 0:
		btn.custom_minimum_size = Vector2(min_w, min_h)
	else:
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size.y = min_h
	if ResourceLoader.exists(TEX_NORMAL):
		var tex_n: Texture2D = load(TEX_NORMAL)
		var style_n := StyleBoxTexture.new()
		style_n.texture = tex_n
		style_n.texture_margin_left = 6; style_n.texture_margin_right = 6
		style_n.texture_margin_top = 4; style_n.texture_margin_bottom = 4
		btn.add_theme_stylebox_override("normal",  style_n)
		btn.add_theme_stylebox_override("hover",   style_n)
		btn.add_theme_stylebox_override("focus",   style_n)
	if ResourceLoader.exists(TEX_PRESSED):
		var tex_p: Texture2D = load(TEX_PRESSED)
		var style_p := StyleBoxTexture.new()
		style_p.texture = tex_p
		style_p.texture_margin_left = 6; style_p.texture_margin_right = 6
		style_p.texture_margin_top = 4; style_p.texture_margin_bottom = 4
		btn.add_theme_stylebox_override("pressed", style_p)
	return btn
