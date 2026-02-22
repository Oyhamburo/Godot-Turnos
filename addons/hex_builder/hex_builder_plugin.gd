@tool
extends EditorPlugin
##
## Plugin "Hex Builder": dock para construir mapas hexagonales rápido.
## Click izquierdo coloca el asset seleccionado en la celda hex bajo el mouse.
## Shift+click izquierdo o click derecho borra. Arrastrar pinta continuo.
## Todo con Undo/Redo del editor.
##

const BUILDING_Y_OFFSET := 0.02

var _dock: Control  # hex_builder_dock.gd
var _arrastrando: bool = false
var _ultimo_hex_pintado: Vector2i = Vector2i(-999, -999)


func _enter_tree() -> void:
	var dock_script: GDScript = load("res://addons/hex_builder/hex_builder_dock.gd") as GDScript
	_dock = VBoxContainer.new()
	_dock.set_script(dock_script)
	_dock.name = "HexBuilder"
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, _dock)


func _exit_tree() -> void:
	if _dock:
		remove_control_from_docks(_dock)
		_dock.queue_free()
		_dock = null


func _forward_3d_gui_input(camera: Camera3D, event: InputEvent) -> int:
	if not _dock or not _dock.is_active():
		return AFTER_GUI_INPUT_PASS

	# Click izquierdo: colocar o borrar según modo y shift
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_arrastrando = true
				_ultimo_hex_pintado = Vector2i(-999, -999)
				var borrar: bool = mb.shift_pressed or _dock.get_mode() == "erase"
				var ok := _procesar_accion(camera, mb.position, borrar)
				if ok:
					return AFTER_GUI_INPUT_STOP
			else:
				_arrastrando = false
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			# Click derecho: borrar
			var ok := _procesar_accion(camera, mb.position, true)
			if ok:
				return AFTER_GUI_INPUT_STOP

	# Arrastre continuo
	if event is InputEventMouseMotion and _arrastrando:
		var motion := event as InputEventMouseMotion
		var borrar: bool = Input.is_key_pressed(KEY_SHIFT) or _dock.get_mode() == "erase"
		var ok := _procesar_accion(camera, motion.position, borrar)
		if ok:
			return AFTER_GUI_INPUT_STOP

	return AFTER_GUI_INPUT_PASS


func _procesar_accion(camera: Camera3D, screen_pos: Vector2, borrar: bool) -> bool:
	var hit: Variant = _raycast_plano_y0(camera, screen_pos)
	if hit == null:
		return false

	var hit_pos: Vector3 = hit as Vector3
	var hex: Vector2i = HexGrid.world_to_hex(hit_pos.x, hit_pos.z)

	# Evitar pintar dos veces el mismo hex en un arrastre
	if hex == _ultimo_hex_pintado:
		return true
	_ultimo_hex_pintado = hex

	if borrar:
		return _borrar_en_hex(hex)
	else:
		return _colocar_en_hex(hex)


func _colocar_en_hex(hex: Vector2i) -> bool:
	var scene_path: String = _dock.get_selected_scene_path()
	if scene_path.is_empty():
		return false

	var container: Node = _get_target_container()
	if container == null:
		push_warning("HexBuilder: No se encontró nodo 'Tiles' ni 'Buildings' en la escena.")
		return false

	# No colocar si ya hay algo en esa coordenada
	if _hay_nodo_en_hex(container, hex):
		return true  # No es error, simplemente ya hay algo

	var scene: PackedScene = load(scene_path) as PackedScene
	if scene == null:
		push_warning("HexBuilder: No se pudo cargar %s" % scene_path)
		return false

	var tile: Node3D = scene.instantiate() as Node3D
	if tile == null:
		return false

	var es_edificio: bool = _dock.get_selected_category() == "Edificio"
	var y_pos: float = BUILDING_Y_OFFSET if es_edificio else 0.0
	tile.position = HexGrid.hex_to_world(hex.x, hex.y, y_pos)
	tile.name = "%s_%d_%d" % ["Building" if es_edificio else "Hex", hex.x, hex.y]
	tile.rotation_degrees.y = _dock.get_rotation_degrees()

	var root: Node = get_editor_interface().get_edited_scene_root()
	var undo: EditorUndoRedoManager = get_undo_redo()
	undo.create_action("Colocar %s en (%d, %d)" % [tile.name, hex.x, hex.y])
	undo.add_do_method(container, "add_child", tile)
	undo.add_do_property(tile, "owner", root)
	undo.add_do_reference(tile)
	undo.add_undo_method(container, "remove_child", tile)
	undo.commit_action()
	return true


func _borrar_en_hex(hex: Vector2i) -> bool:
	var container: Node = _get_target_container()
	if container == null:
		return false

	var nodo: Node3D = _encontrar_nodo_en_hex(container, hex)
	if nodo == null:
		# Intentar en Buildings también
		var buildings: Node = _get_buildings_container()
		if buildings:
			nodo = _encontrar_nodo_en_hex(buildings, hex)
			if nodo:
				container = buildings

	if nodo == null:
		return false

	var root: Node = get_editor_interface().get_edited_scene_root()
	var undo: EditorUndoRedoManager = get_undo_redo()
	undo.create_action("Borrar en (%d, %d)" % [hex.x, hex.y])
	undo.add_do_method(container, "remove_child", nodo)
	undo.add_do_reference(nodo)
	undo.add_undo_method(container, "add_child", nodo)
	undo.add_undo_property(nodo, "owner", root)
	undo.commit_action()
	return true


func _hay_nodo_en_hex(container: Node, hex: Vector2i) -> bool:
	return _encontrar_nodo_en_hex(container, hex) != null


func _encontrar_nodo_en_hex(container: Node, hex: Vector2i) -> Node3D:
	for child in container.get_children():
		if child is Node3D:
			var h: Vector2i = HexGrid.world_to_hex(child.position.x, child.position.z)
			if h.x == hex.x and h.y == hex.y:
				return child as Node3D
	return null


func _get_target_container() -> Node:
	var root: Node = get_editor_interface().get_edited_scene_root()
	if root == null:
		return null

	# Buscar "Tiles" en varias ubicaciones posibles
	for path in ["HexMapRoot/Tiles", "DefaultMap/Tiles", "Tiles"]:
		var n: Node = root.get_node_or_null(path)
		if n:
			return n

	# Si el root se llama DefaultMap, buscar Tiles directamente
	if root.name == "DefaultMap":
		return root.get_node_or_null("Tiles")

	# Buscar recursivamente
	return _find_named(root, "Tiles")


func _get_buildings_container() -> Node:
	var root: Node = get_editor_interface().get_edited_scene_root()
	if root == null:
		return null

	for path in ["HexMapRoot/Buildings", "DefaultMap/Buildings", "Buildings"]:
		var n: Node = root.get_node_or_null(path)
		if n:
			return n

	if root.name == "DefaultMap":
		return root.get_node_or_null("Buildings")

	return _find_named(root, "Buildings")


func _find_named(node: Node, target_name: String) -> Node:
	if node.name == target_name:
		return node
	for child in node.get_children():
		var found: Node = _find_named(child, target_name)
		if found:
			return found
	return null


func _raycast_plano_y0(camera: Camera3D, screen_pos: Vector2) -> Variant:
	var from: Vector3 = camera.project_ray_origin(screen_pos)
	var dir: Vector3 = camera.project_ray_normal(screen_pos)
	var plano := Plane(Vector3.UP, 0.0)
	return plano.intersects_ray(from, dir)
