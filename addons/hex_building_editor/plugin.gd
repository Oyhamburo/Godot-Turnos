@tool
extends EditorPlugin
##
## Menú "Add building to map": diálogo para elegir (q, r) y tipo de edificio, añadir a DefaultMap/Buildings.
## Los edificios se colocan encima de los hexágonos (mismo (q,r), altura pequeña).
## Requiere tener abierta la escena DefaultMap (o una que contenga el nodo DefaultMap).
##

const BUILDINGS_SCENES_PATH := "res://scenes/buildings/"
const BUILDING_Y_OFFSET := 0.02
const MENU_NAME := "Add building to map"
const CONFIG_PATH := "user://hex_building_editor.cfg"
const CONFIG_KEY_LAST_BUILDING := "last_building"

var _dialog: Window
var _building_option: OptionButton
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
	_dialog.title = "Añadir edificio al mapa"
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
	help.text = "Abre DefaultMap.tscn. Clic en la grilla para seleccionar celdas (una o varias). Los edificios se colocan encima de los hexágonos. Añadir: coloca edificios. Borrar: elimina los de las celdas seleccionadas."
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.custom_minimum_size.y = 32
	if theme:
		help.add_theme_font_size_override("font_size", 12)
	vbox.add_child(help)

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

	var controls_row := HBoxContainer.new()
	controls_row.add_theme_constant_override("separation", 32)
	controls_row.alignment = BoxContainer.ALIGNMENT_CENTER
	controls_row.custom_minimum_size.y = 140

	var building_box := VBoxContainer.new()
	building_box.add_theme_constant_override("separation", 6)
	building_box.custom_minimum_size.x = 280
	var building_title := Label.new()
	building_title.text = "Tipo de edificio"
	if theme:
		building_title.add_theme_font_size_override("font_size", 13)
	building_box.add_child(building_title)
	_building_option = OptionButton.new()
	_building_option.custom_minimum_size = Vector2(260, 0)
	_building_option.item_selected.connect(_update_summary)
	building_box.add_child(_building_option)
	_fill_building_list()
	controls_row.add_child(building_box)

	vbox.add_child(controls_row)

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
	var remove_btn := Button.new()
	remove_btn.text = " Borrar selección "
	if theme:
		var remove_icon: Texture2D = theme.get_icon("Remove", "EditorIcons")
		if remove_icon:
			remove_btn.icon = remove_icon
	remove_btn.pressed.connect(_on_remove_pressed)
	var add_btn := Button.new()
	add_btn.text = " Añadir "
	if theme:
		var add_icon: Texture2D = theme.get_icon("Add", "EditorIcons")
		if add_icon:
			add_btn.icon = add_icon
	add_btn.pressed.connect(_on_add_pressed)
	btn_row.add_child(cancel_btn)
	btn_row.add_child(remove_btn)
	btn_row.add_child(add_btn)
	vbox.add_child(btn_row)

	_dialog.close_requested.connect(_on_cancel_pressed)

func _fill_building_list() -> void:
	_building_option.clear()
	var dir := DirAccess.open(BUILDINGS_SCENES_PATH)
	if dir == null:
		_building_option.add_item("BuildingGrain (default)", 0)
		_select_last_building()
		return
	var files: PackedStringArray = dir.get_files()
	var idx := 0
	for f in files:
		if not f.ends_with(".tscn"):
			continue
		_building_option.add_item(f.get_basename(), idx)
		idx += 1
	if _building_option.item_count == 0:
		_building_option.add_item("BuildingGrain (default)", 0)
	_select_last_building()

func _update_summary(_arg = null) -> void:
	var name_only: String = "BuildingGrain"
	if _building_option and _building_option.item_count > 0:
		name_only = _building_option.get_item_text(_building_option.selected)
	var hexes: Array = []
	if _hex_picker and _hex_picker.has_method("get_selected_hexes"):
		hexes = _hex_picker.get_selected_hexes()
	var occupied_count: int = _count_occupied_in_selection(hexes)
	if _summary_label:
		if hexes.is_empty():
			_summary_label.text = "Selecciona al menos una celda. Se usará: %s." % name_only
		else:
			var add_text: String
			if hexes.size() == 1:
				var h: Vector2i = hexes[0]
				add_text = "Se añadirá %s en (%d, %d)." % [name_only, h.x, h.y]
			else:
				var parts: PackedStringArray = []
				for i in range(mini(hexes.size(), 8)):
					var h: Vector2i = hexes[i]
					parts.append("(%d,%d)" % [h.x, h.y])
				var rest: String = "" if hexes.size() <= 8 else " ..."
				add_text = "Se añadirá %s en %d celdas: %s%s." % [name_only, hexes.size(), ", ".join(parts), rest]
			if occupied_count > 0:
				_summary_label.text = add_text + " %d con edificio → Borrar selección los quita." % occupied_count
			else:
				_summary_label.text = add_text

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
	var buildings_node: Node = _get_buildings_node()
	var occupied: Array = []
	if buildings_node:
		for child in buildings_node.get_children():
			if child is Node3D:
				var h: Vector2i = HexGrid.world_to_hex(child.position.x, child.position.z)
				occupied.append(h)
	_hex_picker.set_occupied_hexes(occupied)

func _count_occupied_in_selection(hexes: Array) -> int:
	if hexes.is_empty():
		return 0
	var buildings_node: Node = _get_buildings_node()
	if buildings_node == null:
		return 0
	var occupied_set: Dictionary = {}
	for child in buildings_node.get_children():
		if child is Node3D:
			var h: Vector2i = HexGrid.world_to_hex(child.position.x, child.position.z)
			occupied_set["%d,%d" % [h.x, h.y]] = true
	var count := 0
	for h in hexes:
		if occupied_set.get("%d,%d" % [h.x, h.y], false):
			count += 1
	return count

func _on_cancel_pressed() -> void:
	_dialog.hide()

func _on_add_pressed() -> void:
	var buildings_node: Node = _get_buildings_node()
	if buildings_node == null:
		_show_message("Abre la escena DefaultMap.tscn (debe tener nodo Buildings) y vuelve a intentar.")
		return
	var hexes: Array = []
	if _hex_picker and _hex_picker.has_method("get_selected_hexes"):
		hexes = _hex_picker.get_selected_hexes()
	if hexes.is_empty():
		_show_message("Selecciona al menos una celda en la grilla.")
		return
	var scene_path: String = _get_selected_building_path()
	if scene_path.is_empty():
		_show_message("No se encontró la escena del edificio.")
		return
	var scene: PackedScene = load(scene_path) as PackedScene
	if scene == null:
		_show_message("No se pudo cargar: %s" % scene_path)
		return
	var root_owner: Node = get_editor_interface().get_edited_scene_root()
	var name_only: String = _building_option.get_item_text(_building_option.selected).replace(" (default)", "")
	_save_last_building(name_only)
	for h in hexes:
		var q: int = h.x
		var r: int = h.y
		var building: Node3D = scene.instantiate() as Node3D
		if building == null:
			continue
		var pos: Vector3 = HexGrid.hex_to_world(q, r, BUILDING_Y_OFFSET)
		building.position = pos
		building.name = "Building_%d_%d" % [q, r]
		buildings_node.add_child(building)
		building.owner = root_owner
	if _hex_picker.has_method("clear_selection"):
		_hex_picker.clear_selection()
	_refresh_occupied_hexes()
	_update_summary()
	_show_message("Añadidos %d edificio(s). Guarda la escena (Ctrl+S)." % hexes.size())

func _on_remove_pressed() -> void:
	var buildings_node: Node = _get_buildings_node()
	if buildings_node == null:
		_show_message("Abre la escena DefaultMap.tscn y vuelve a intentar.")
		return
	var hexes: Array = []
	if _hex_picker and _hex_picker.has_method("get_selected_hexes"):
		hexes = _hex_picker.get_selected_hexes()
	if hexes.is_empty():
		_show_message("Selecciona al menos una celda en la grilla para borrar.")
		return
	var to_remove: Array[Node] = []
	for h in hexes:
		var q: int = h.x
		var r: int = h.y
		for child in buildings_node.get_children():
			if child is Node3D:
				var ch_hex: Vector2i = HexGrid.world_to_hex(child.position.x, child.position.z)
				if ch_hex.x == q and ch_hex.y == r:
					to_remove.append(child)
					break
	if to_remove.is_empty():
		if _hex_picker.has_method("clear_selection"):
			_hex_picker.clear_selection()
		_refresh_occupied_hexes()
		_update_summary()
		_show_message("Ningún edificio en las celdas seleccionadas.")
		return
	var root_owner: Node = get_editor_interface().get_edited_scene_root()
	var undo: EditorUndoRedoManager = get_undo_redo()
	undo.create_action("Borrar edificio(s)")
	for node in to_remove:
		undo.add_do_method(buildings_node, "remove_child", node)
		undo.add_do_reference(node)
		undo.add_undo_method(buildings_node, "add_child", node)
		undo.add_undo_property(node, "owner", root_owner)
	undo.commit_action()
	if _hex_picker.has_method("clear_selection"):
		_hex_picker.clear_selection()
	_refresh_occupied_hexes()
	_update_summary()
	_show_message("Borrados %d edificio(s). Guarda la escena (Ctrl+S). Puedes deshacer con Ctrl+Z." % to_remove.size())

func _get_buildings_node() -> Node:
	var root: Node = get_editor_interface().get_edited_scene_root()
	if root == null:
		return null
	if root.name == "DefaultMap":
		return root.get_node_or_null("Buildings")
	var default_map: Node = root.get_node_or_null("DefaultMap")
	if default_map:
		return default_map.get_node_or_null("Buildings")
	return null

func _get_selected_building_path() -> String:
	if _building_option.item_count == 0:
		return BUILDINGS_SCENES_PATH + "BuildingGrain.tscn"
	var name_only: String = _building_option.get_item_text(_building_option.selected)
	if name_only.is_empty():
		return BUILDINGS_SCENES_PATH + "BuildingGrain.tscn"
	name_only = name_only.replace(" (default)", "")
	return BUILDINGS_SCENES_PATH + name_only + ".tscn"

func _show_message(msg: String) -> void:
	OS.alert(msg, "Hex Building Editor")

func _save_last_building(building_name: String) -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("editor", CONFIG_KEY_LAST_BUILDING, building_name)
	cfg.save(CONFIG_PATH)

func _select_last_building() -> void:
	if _building_option.item_count == 0:
		return
	var cfg := ConfigFile.new()
	if cfg.load(CONFIG_PATH) != OK:
		_building_option.selected = 0
		return
	var last: Variant = cfg.get_value("editor", CONFIG_KEY_LAST_BUILDING, "")
	if last == null or (last is String and (last as String).is_empty()):
		_building_option.selected = 0
		return
	var name_str: String = str(last)
	for i in range(_building_option.item_count):
		var item_text: String = _building_option.get_item_text(i).replace(" (default)", "")
		if item_text == name_str:
			_building_option.selected = i
			return
	_building_option.selected = 0
