@tool
extends EditorPlugin
##
## Menú "Add hex to map": diálogo para elegir (q, r) y tipo de tile, añadir hex a DefaultMap/Tiles.
## Requiere tener abierta la escena DefaultMap (o una que contenga el nodo DefaultMap).
##

const HEX_SCENES_PATH := "res://scenes/hex/"
const MENU_NAME := "Add hex to map"
const CONFIG_PATH := "user://hex_map_editor.cfg"
const CONFIG_KEY_LAST_TILE := "last_tile"

var _dialog: Window
var _tile_option: OptionButton
var _summary_label: Label
var _hex_picker: Control

func _enter_tree() -> void:
	_build_dialog()
	var base: Control = get_editor_interface().get_base_control()
	base.call_deferred("add_child", _dialog)
	add_tool_menu_item(MENU_NAME, _on_menu_pressed)

func _exit_tree() -> void:
	remove_tool_menu_item(MENU_NAME)
	if _dialog:
		_dialog.queue_free()
		_dialog = null

func _build_dialog() -> void:
	var theme: Theme = get_editor_interface().get_editor_theme() if get_editor_interface() else null

	_dialog = Window.new()
	_dialog.title = "Añadir hex al mapa"
	_dialog.min_size = Vector2i(1580, 1680)
	_dialog.size = Vector2i(1620, 1720)
	_dialog.unresizable = false
	if theme:
		_dialog.theme = theme

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 24
	vbox.offset_top = 24
	vbox.offset_right = -24
	vbox.offset_bottom = -24
	vbox.add_theme_constant_override("separation", 16)
	_dialog.add_child(vbox)

	var help := Label.new()
	help.text = "Abre DefaultMap.tscn. Clic en la grilla para seleccionar celdas (varias a la vez). Elige el tipo de hex y pulsa Añadir."
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.custom_minimum_size.y = 32
	if theme:
		help.add_theme_font_size_override("font_size", 12)
	vbox.add_child(help)

	# Fila central: grilla centrada (contenedor ~1500x1500)
	var content := HBoxContainer.new()
	content.custom_minimum_size.y = 1520
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var spacer_left := Control.new()
	spacer_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(spacer_left)
	var center_col := VBoxContainer.new()
	center_col.add_theme_constant_override("separation", 8)
	center_col.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	center_col.custom_minimum_size.x = 1520
	var grid_title := Label.new()
	grid_title.text = "Clic para seleccionar celdas (múltiples)"
	if theme:
		grid_title.add_theme_font_size_override("font_size", 13)
	center_col.add_child(grid_title)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(1500, 1500)
	scroll.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var picker_script: GDScript = load("res://addons/hex_map_editor/hex_grid_picker.gd") as GDScript
	_hex_picker = Control.new()
	_hex_picker.set_script(picker_script)
	_hex_picker.custom_minimum_size = Vector2(1500, 1500)
	if _hex_picker.has_signal("selection_changed"):
		_hex_picker.selection_changed.connect(_update_summary)
	scroll.add_child(_hex_picker)
	center_col.add_child(scroll)
	content.add_child(center_col)
	var spacer_right := Control.new()
	spacer_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(spacer_right)
	vbox.add_child(content)

	# Fila de controles: tipo de hex
	var controls_row := HBoxContainer.new()
	controls_row.add_theme_constant_override("separation", 32)
	controls_row.alignment = BoxContainer.ALIGNMENT_CENTER
	controls_row.custom_minimum_size.y = 140

	var tile_box := VBoxContainer.new()
	tile_box.add_theme_constant_override("separation", 6)
	tile_box.custom_minimum_size.x = 280
	var tile_title := Label.new()
	tile_title.text = "Tipo de hex"
	if theme:
		tile_title.add_theme_font_size_override("font_size", 13)
	tile_box.add_child(tile_title)
	_tile_option = OptionButton.new()
	_tile_option.custom_minimum_size = Vector2(260, 0)
	_tile_option.item_selected.connect(_update_summary)
	tile_box.add_child(_tile_option)
	_fill_tile_list()
	controls_row.add_child(tile_box)

	vbox.add_child(controls_row)

	# Panel resumen
	var summary_panel := PanelContainer.new()
	if theme:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.2, 0.22, 0.26, 0.6)
		style.set_corner_radius_all(4)
		style.set_content_margin_all(10)
		summary_panel.add_theme_stylebox_override("panel", style)
	_summary_label = Label.new()
	if theme:
		_summary_label.add_theme_font_size_override("font_size", 14)
	summary_panel.add_child(_summary_label)
	vbox.add_child(summary_panel)
	_update_summary()

	# Botones
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 12)
	btn_row.alignment = BoxContainer.ALIGNMENT_END
	var cancel_btn := Button.new()
	cancel_btn.text = " Cancelar "
	if theme:
		var close_icon: Texture2D = theme.get_icon("Close", "EditorIcons")
		if close_icon:
			cancel_btn.icon = close_icon
	cancel_btn.pressed.connect(_on_cancel_pressed)
	var add_btn := Button.new()
	add_btn.text = " Añadir "
	if theme:
		var add_icon: Texture2D = theme.get_icon("Add", "EditorIcons")
		if add_icon:
			add_btn.icon = add_icon
	add_btn.pressed.connect(_on_add_pressed)
	btn_row.add_child(cancel_btn)
	btn_row.add_child(add_btn)
	vbox.add_child(btn_row)

	_dialog.close_requested.connect(_on_cancel_pressed)

func _fill_tile_list() -> void:
	_tile_option.clear()
	var dir := DirAccess.open(HEX_SCENES_PATH)
	if dir == null:
		_tile_option.add_item("HexGrass (default)", 0)
		_select_last_tile()
		return
	var files: PackedStringArray = dir.get_files()
	var idx := 0
	for f in files:
		if not f.ends_with(".tscn"):
			continue
		_tile_option.add_item(f.get_basename(), idx)
		idx += 1
	if _tile_option.item_count == 0:
		_tile_option.add_item("HexGrass (default)", 0)
	_select_last_tile()

func _update_summary(_arg = null) -> void:
	var name_only: String = "HexGrass"
	if _tile_option and _tile_option.item_count > 0:
		name_only = _tile_option.get_item_text(_tile_option.selected)
	var hexes: Array = []
	if _hex_picker and _hex_picker.has_method("get_selected_hexes"):
		hexes = _hex_picker.get_selected_hexes()
	if _summary_label:
		if hexes.is_empty():
			_summary_label.text = "Selecciona al menos una celda. Se usará: %s." % name_only
		elif hexes.size() == 1:
			var h: Vector2i = hexes[0]
			_summary_label.text = "Se añadirá %s en (%d, %d)." % [name_only, h.x, h.y]
		else:
			var parts: PackedStringArray = []
			for i in range(mini(hexes.size(), 8)):
				var h: Vector2i = hexes[i]
				parts.append("(%d,%d)" % [h.x, h.y])
			var rest: String = "" if hexes.size() <= 8 else " ..."
			_summary_label.text = "Se añadirá %s en %d celdas: %s%s." % [name_only, hexes.size(), ", ".join(parts), rest]

func _on_menu_pressed() -> void:
	if _dialog == null:
		_build_dialog()
	var base: Control = get_editor_interface().get_base_control()
	if not _dialog.is_inside_tree():
		base.add_child(_dialog)
	_refresh_occupied_hexes()
	_update_summary()
	_dialog.call_deferred("popup_centered")

func _refresh_occupied_hexes() -> void:
	if _hex_picker == null or not _hex_picker.has_method("set_occupied_hexes"):
		return
	var tiles_node: Node = _get_tiles_node()
	var occupied: Array = []
	if tiles_node:
		for child in tiles_node.get_children():
			if child is Node3D:
				var h: Vector2i = HexGrid.world_to_hex(child.position.x, child.position.z)
				occupied.append(h)
	_hex_picker.set_occupied_hexes(occupied)

func _on_cancel_pressed() -> void:
	_dialog.hide()

func _on_add_pressed() -> void:
	var tiles_node: Node = _get_tiles_node()
	if tiles_node == null:
		_show_message("Abre la escena DefaultMap.tscn y vuelve a intentar.")
		return
	var hexes: Array = []
	if _hex_picker and _hex_picker.has_method("get_selected_hexes"):
		hexes = _hex_picker.get_selected_hexes()
	if hexes.is_empty():
		_show_message("Selecciona al menos una celda en la grilla.")
		return
	var scene_path: String = _get_selected_tile_path()
	if scene_path.is_empty():
		_show_message("No se encontró la escena del tile.")
		return
	var scene: PackedScene = load(scene_path) as PackedScene
	if scene == null:
		_show_message("No se pudo cargar: %s" % scene_path)
		return
	var root_owner: Node = get_editor_interface().get_edited_scene_root()
	var name_only: String = _tile_option.get_item_text(_tile_option.selected).replace(" (default)", "")
	_save_last_tile(name_only)
	for h in hexes:
		var q: int = h.x
		var r: int = h.y
		var tile: Node3D = scene.instantiate() as Node3D
		if tile == null:
			continue
		tile.position = HexGrid.hex_to_world(q, r, 0.0)
		tile.name = "Hex_%d_%d" % [q, r]
		tiles_node.add_child(tile)
		tile.owner = root_owner
	if _hex_picker.has_method("clear_selection"):
		_hex_picker.clear_selection()
	_refresh_occupied_hexes()
	_update_summary()
	_show_message("Añadidos %d hex(es). Guarda la escena (Ctrl+S)." % hexes.size())

func _get_tiles_node() -> Node:
	var root: Node = get_editor_interface().get_edited_scene_root()
	if root == null:
		return null
	if root.name == "DefaultMap":
		return root.get_node_or_null("Tiles")
	var default_map: Node = root.get_node_or_null("DefaultMap")
	if default_map:
		return default_map.get_node_or_null("Tiles")
	return null

func _get_selected_tile_path() -> String:
	if _tile_option.item_count == 0:
		return HEX_SCENES_PATH + "HexGrass.tscn"
	var name_only: String = _tile_option.get_item_text(_tile_option.selected)
	if name_only.is_empty():
		return HEX_SCENES_PATH + "HexGrass.tscn"
	name_only = name_only.replace(" (default)", "")
	return HEX_SCENES_PATH + name_only + ".tscn"

func _show_message(msg: String) -> void:
	OS.alert(msg, "Hex Map Editor")

func _save_last_tile(tile_name: String) -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("editor", CONFIG_KEY_LAST_TILE, tile_name)
	cfg.save(CONFIG_PATH)

func _select_last_tile() -> void:
	if _tile_option.item_count == 0:
		return
	var cfg := ConfigFile.new()
	if cfg.load(CONFIG_PATH) != OK:
		_tile_option.selected = 0
		return
	var last: Variant = cfg.get_value("editor", CONFIG_KEY_LAST_TILE, "")
	if last == null or (last is String and (last as String).is_empty()):
		_tile_option.selected = 0
		return
	var name_str: String = str(last)
	for i in range(_tile_option.item_count):
		var item_text: String = _tile_option.get_item_text(i).replace(" (default)", "")
		if item_text == name_str:
			_tile_option.selected = i
			return
	_tile_option.selected = 0
