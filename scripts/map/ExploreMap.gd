extends Node3D
##
## Escena de exploración: hexes válidos se detectan automáticamente desde los hijos de DefaultMap/Tiles.
## Solo hay que añadir o quitar hexes en la escena DefaultMap; no hace falta editar código.
##

const MAIN_MENU_SCENE := "res://scenes/MainMenu.tscn"

@onready var default_map: Node3D = $DefaultMap
@onready var explore_player: Node = $ExplorePlayer
@onready var back_button: Button = $UI/BackButton

var _valid_hexes: Array[Vector2i] = []
var _move_in_progress: bool = false

func _ready() -> void:
	_build_valid_hexes_from_tiles()
	if _valid_hexes.is_empty():
		push_warning("ExploreMap: no hay hexes en DefaultMap/Tiles. Añade instancias de scenes/hex/.")
	else:
		if explore_player.has_method("set_initial_hex"):
			explore_player.set_initial_hex(_valid_hexes[0])
	if explore_player.has_signal("move_finished"):
		explore_player.move_finished.connect(_on_player_move_finished)
	if back_button:
		back_button.pressed.connect(_on_back_pressed)

func _build_valid_hexes_from_tiles() -> void:
	_valid_hexes.clear()
	var tiles: Node = default_map.get_node_or_null("Tiles")
	if tiles == null:
		return
	for child in tiles.get_children():
		var pos: Vector3 = child.global_position
		var hex: Vector2i = HexGrid.world_to_hex(pos.x, pos.z)
		child.global_position = HexGrid.hex_to_world(hex.x, hex.y, 0.0)
		var already: bool = false
		for h in _valid_hexes:
			if h.x == hex.x and h.y == hex.y:
				already = true
				break
		if not already:
			_valid_hexes.append(hex)

func _on_player_move_finished() -> void:
	_move_in_progress = false

func _input(event: InputEvent) -> void:
	if _move_in_progress:
		return
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			_handle_click(mb.position)

func _handle_click(screen_pos: Vector2) -> void:
	var cam: Camera3D = explore_player.get_node_or_null("Camera3D")
	if cam == null:
		return
	var from: Vector3 = cam.project_ray_origin(screen_pos)
	var dir: Vector3 = cam.project_ray_normal(screen_pos)
	var plane := Plane(Vector3.UP, 0.0)
	var hit: Variant = plane.intersects_ray(from, dir)
	if hit == null:
		return
	var hit_pos: Vector3 = hit
	var click_hex: Vector2i = HexGrid.world_to_hex(hit_pos.x, hit_pos.z)
	if not _is_valid_hex(click_hex):
		return
	var current: Vector2i = explore_player.get_current_hex() if explore_player.has_method("get_current_hex") else Vector2i(0, 0)
	if not HexGrid.is_neighbour(current.x, current.y, click_hex.x, click_hex.y):
		return
	if explore_player.has_method("move_to_hex"):
		_move_in_progress = true
		explore_player.move_to_hex(click_hex)

func _is_valid_hex(hex: Vector2i) -> bool:
	for v in _valid_hexes:
		if v.x == hex.x and v.y == hex.y:
			return true
	return false

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)
