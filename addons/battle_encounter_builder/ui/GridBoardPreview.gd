@tool
extends Control
class_name GridBoardPreview
##
## Control 2D que muestra una grilla del tablero para editar spawns y obstáculos.
## Emite señales al hacer click en celdas.
##

signal cell_clicked(coord: Vector2i, button: int, modifiers: int)
signal cell_hovered(coord: Vector2i)

const CELL_SIZE_MIN: int = 24

var grid_width: int = 4
var grid_height: int = 4
var obstacles: Array[Vector2i] = []
var player_spawns: Array[Vector2i] = []
var enemy_spawns: Array[Vector2i] = []
var selected_spawn_key: String = ""

var _cell_size: float = 24.0
var _obstacle_set: Dictionary = {}
var _player_set: Dictionary = {}
var _enemy_set: Dictionary = {}


func _ready() -> void:
	focus_mode = FOCUS_CLICK
	_clamp_minimum_size()


func _draw() -> void:
	_update_sets()
	_cell_size = _compute_cell_size()

	var margin := 2.0
	for y in range(grid_height):
		for x in range(grid_width):
			var coord := Vector2i(x, y)
			var rect := Rect2(
				x * _cell_size + margin,
				y * _cell_size + margin,
				_cell_size - margin * 2,
				_cell_size - margin * 2
			)
			var color := _get_cell_color(coord)
			draw_rect(rect, color)
			# Borde
			draw_rect(rect, Color(0.2, 0.2, 0.25, 1), false, 1.0)


func _update_sets() -> void:
	_obstacle_set.clear()
	for c in obstacles:
		_obstacle_set[_coord_key(c)] = true
	_player_set.clear()
	for c in player_spawns:
		_player_set[_coord_key(c)] = true
	_enemy_set.clear()
	for c in enemy_spawns:
		_enemy_set[_coord_key(c)] = true


func _get_cell_color(coord: Vector2i) -> Color:
	var key := _coord_key(coord)
	if _obstacle_set.get(key, false):
		return Color(0.45, 0.25, 0.2, 1)
	if _player_set.get(key, false):
		return Color(0.2, 0.55, 0.3, 1)
	if _enemy_set.get(key, false):
		return Color(0.55, 0.2, 0.2, 1)
	return Color(0.4, 0.42, 0.48, 1)


func _compute_cell_size() -> float:
	if grid_width <= 0 or grid_height <= 0:
		return float(CELL_SIZE_MIN)
	var w: float = size.x / float(grid_width)
	var h: float = size.y / float(grid_height)
	return max(CELL_SIZE_MIN, min(w, h))


func _clamp_minimum_size() -> void:
	custom_minimum_size = Vector2(
		grid_width * CELL_SIZE_MIN,
		grid_height * CELL_SIZE_MIN
	)


func _coord_key(c: Vector2i) -> String:
	return "%d,%d" % [c.x, c.y]


func _screen_to_cell(local_pos: Vector2) -> Vector2i:
	if _cell_size <= 0:
		return Vector2i(-1, -1)
	var cx := int(local_pos.x / _cell_size)
	var cy := int(local_pos.y / _cell_size)
	if cx < 0 or cx >= grid_width or cy < 0 or cy >= grid_height:
		return Vector2i(-1, -1)
	return Vector2i(cx, cy)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed:
			var coord := _screen_to_cell(mb.position)
			if coord.x >= 0:
				cell_clicked.emit(coord, mb.button_index, mb.get_modifiers_mask())
	if event is InputEventMouseMotion:
		var mm: InputEventMouseMotion = event as InputEventMouseMotion
		var coord := _screen_to_cell(mm.position)
		if coord.x >= 0:
			cell_hovered.emit(coord)


func set_grid_size(w: int, h: int) -> void:
	grid_width = max(1, w)
	grid_height = max(1, h)
	_clamp_minimum_size()
	queue_redraw()


func notify_data_changed() -> void:
	queue_redraw()
