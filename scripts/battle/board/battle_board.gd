extends Node3D
class_name BattleBoard
##
## Genera y gestiona el tablero de batalla: grilla de tiles, bloqueos, ocupación y spawn de unidades.
##

const TILE_SCENE := preload("res://scenes/battle/Tile.tscn")
const FLOOR_SCENES_PATHS: Array[String] = [
	"res://scenes/floors/FloorTileLarge.tscn",
	"res://scenes/floors/FloorTileGrate.tscn",
	"res://scenes/floors/FloorTileLargeRocks.tscn",
]
const FLOOR_BLOCKED_PATH: String = "res://assets/KayKit_DungeonRemastered_1.1_FREE/Assets/gltf/floor_tile_big_spikes.gltf"
const KAYKIT_FLOOR_DIR: String = "res://assets/KayKit_DungeonRemastered_1.1_FREE/Assets/gltf"

signal tile_selected(tile: Tile)

var tiles: Dictionary = {}  # Vector2i -> Tile
var _floor_walkable: Array[PackedScene] = []
var _floor_blocked: PackedScene = null
var _selected_tile: Tile = null
var _config: BattleConfig
var _tiles_node: Node3D

@onready var units_container: Node3D = get_parent().get_node_or_null("Units")


func setup(config: BattleConfig) -> void:
	_config = config
	_load_floor_assets()
	_tiles_node = get_node_or_null("Tiles")
	if not _tiles_node:
		_tiles_node = Node3D.new()
		_tiles_node.name = "Tiles"
		add_child(_tiles_node)

	_clear_tiles()
	_generate_grid()


func _load_floor_assets() -> void:
	_floor_walkable.clear()
	_floor_blocked = null

	# Prioridad 1: escenas en scenes/floors/
	for path in FLOOR_SCENES_PATHS:
		if ResourceLoader.exists(path):
			var scene: PackedScene = load(path) as PackedScene
			if scene:
				_floor_walkable.append(scene)

	# Prioridad 2: si no hay .tscn, escanear KayKit gltf
	if _floor_walkable.is_empty():
		var dir := DirAccess.open(KAYKIT_FLOOR_DIR)
		if dir:
			dir.list_dir_begin()
			var file := dir.get_next()
			while file != "":
				if file.ends_with(".gltf") and file.begins_with("floor"):
					if "spike" in file.to_lower():
						if not _floor_blocked:
							var full := KAYKIT_FLOOR_DIR.path_join(file)
							_floor_blocked = load(full) as PackedScene
					else:
						var full := KAYKIT_FLOOR_DIR.path_join(file)
						var scene: PackedScene = load(full) as PackedScene
						if scene and _floor_walkable.size() < 3:
							_floor_walkable.append(scene)
				file = dir.get_next()
			dir.list_dir_end()

	# Fallback bloqueado: cargar spikes si existe
	if not _floor_blocked and ResourceLoader.exists(FLOOR_BLOCKED_PATH):
		_floor_blocked = load(FLOOR_BLOCKED_PATH) as PackedScene


func _clear_tiles() -> void:
	for t in tiles.values():
		if is_instance_valid(t):
			t.queue_free()
	tiles.clear()
	_selected_tile = null
	if _tiles_node:
		for c in _tiles_node.get_children():
			c.queue_free()


func _generate_grid() -> void:
	if not _config:
		push_error("BattleBoard: BattleConfig no asignado.")
		return

	var blocked: Array[Vector2i] = _config.get_blocked_coords()
	var ts: float = _config.tile_size
	var walkable_scene: PackedScene = _floor_walkable[0] if _floor_walkable.size() > 0 else null
	var blocked_scene: PackedScene = _floor_blocked if _floor_blocked else walkable_scene

	for y in range(_config.height):
		for x in range(_config.width):
			var coord := Vector2i(x, y)
			var is_blocked: bool = coord in blocked
			var pos := _coords_to_world(coord)
			var tile: Tile = TILE_SCENE.instantiate() as Tile
			_tiles_node.add_child(tile)
			tile.coords = coord
			tile.world_position = pos
			tile.position = pos
			tile.setup_floor(blocked_scene if is_blocked else walkable_scene, is_blocked, ts)
			tile.tile_clicked.connect(_on_tile_clicked)
			tiles[coord] = tile


func _coords_to_world(coord: Vector2i) -> Vector3:
	var ts: float = _config.tile_size
	# Centro del tablero en origen; tiles centrados en su celda
	var half_w: float = (_config.width - 1) * ts * 0.5
	var half_h: float = (_config.height - 1) * ts * 0.5
	var x: float = coord.x * ts - half_w
	var z: float = coord.y * ts - half_h
	return Vector3(x, 0.0, z)


func _on_tile_clicked(tile: Tile) -> void:
	if _selected_tile and _selected_tile != tile:
		_selected_tile.set_highlighted(false)
	_selected_tile = tile
	tile.set_highlighted(true)
	tile_selected.emit(tile)


func get_tile_at(coords: Vector2i) -> Tile:
	return tiles.get(coords, null)


func get_tile_at_world(pos: Vector3) -> Tile:
	if not _config:
		return null
	var ts: float = _config.tile_size
	var half_w: float = (_config.width - 1) * ts * 0.5
	var half_h: float = (_config.height - 1) * ts * 0.5
	var x: int = int(round((pos.x + half_w) / ts))
	var z: int = int(round((pos.z + half_h) / ts))
	return get_tile_at(Vector2i(x, z))


## Instancia una unidad en el tile indicado. Devuelve la unidad o null.
func spawn_unit(unit_scene: PackedScene, unit_data: UnitData, coords: Vector2i, _team: String) -> Node:
	var tile: Tile = get_tile_at(coords)
	if not tile or not tile.walkable or tile.occupied_by:
		push_warning("BattleBoard: no se puede spawnear en %s (bloqueado u ocupado)" % coords)
		return null

	var unit: Node = unit_scene.instantiate()
	if "data" in unit and unit_data:
		unit.set("data", unit_data)
	var container: Node3D = units_container if units_container else self
	container.add_child(unit)

	unit.global_position = tile.world_position + Vector3(0, 0.1, 0)

	tile.occupied_by = unit
	return unit


## Devuelve el centro 3D del tablero (para la cámara overview).
func get_board_center() -> Vector3:
	if not _config:
		return Vector3.ZERO
	return Vector3(0, 0, 0)


## Devuelve el tamaño aproximado del tablero en X y Z para calcular distancia de cámara.
func get_board_size() -> Vector2:
	if not _config:
		return Vector2(10, 10)
	return Vector2(_config.width * _config.tile_size, _config.height * _config.tile_size)


func clear_selection() -> void:
	if _selected_tile:
		_selected_tile.set_highlighted(false)
		_selected_tile = null


## BFS de rango de movimiento: devuelve coords alcanzables desde origin en max_steps pasos.
## Solo tiles walkable y no ocupados. Excluye el origin.
func get_movement_range(origin: Vector2i, max_steps: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var visited: Dictionary = {}
	var queue: Array = [[origin, 0]]
	visited[origin] = true
	while not queue.is_empty():
		var current: Array = queue.pop_front()
		var coord: Vector2i = current[0]
		var dist: int = current[1]
		if coord != origin:
			result.append(coord)
		if dist >= max_steps:
			continue
		for neighbor in _get_neighbors(coord):
			if neighbor in visited:
				continue
			var tile: Tile = get_tile_at(neighbor)
			if not tile or not tile.walkable or tile.occupied_by:
				continue
			visited[neighbor] = true
			queue.append([neighbor, dist + 1])
	return result


func _get_neighbors(coord: Vector2i) -> Array[Vector2i]:
	return [
		coord + Vector2i(1, 0),
		coord + Vector2i(-1, 0),
		coord + Vector2i(0, 1),
		coord + Vector2i(0, -1),
	]


## Resalta los tiles indicados (verde de rango válido).
func highlight_tiles(coords: Array[Vector2i]) -> void:
	for c in coords:
		var tile: Tile = get_tile_at(c)
		if tile:
			tile.set_highlighted(true)


## Resalta en rojo tenue los tiles walkables vacíos que NO están en valid_coords (fuera del rango de movimiento).
## Excluye tiles ocupados por unidades y tiles bloqueados.
func highlight_unreachable_tiles(valid_coords: Array[Vector2i]) -> void:
	for coord in tiles:
		if coord in valid_coords:
			continue
		var tile: Tile = tiles[coord]
		if not tile or not tile.walkable or tile.occupied_by != null:
			continue
		tile.set_blocked_range_highlight(true)


## Resalta en naranja los tiles dentro del rango de ataque desde el origen.
## atk_range == 0 (Defender/self): no resalta nada.
## atk_range == 99 (ranged): resalta todo el tablero excepto el atacante.
func highlight_attack_range(origin: Vector2i, atk_range: int) -> void:
	if atk_range <= 0:
		return
	for coord in tiles:
		var dist: int = get_tile_distance(coord, origin)
		if dist > 0 and dist <= atk_range:
			var tile: Tile = get_tile_at(coord)
			if tile:
				tile.set_attack_range_highlight(true)


## Limpia el highlight de todos los tiles del tablero (verde, rojo, naranja, púrpura AoE y hover).
func clear_all_highlights() -> void:
	for tile in tiles.values():
		if tile is Tile:
			tile.set_highlighted(false)
			tile.set_hover_highlighted(false)
			tile.set_blocked_range_highlight(false)
			tile.set_attack_range_highlight(false)
			tile.set_aoe_preview_highlight(false)


## Devuelve todas las coordenadas dentro del radio AoE (Manhattan) desde el centro.
## Incluye el centro. Solo tiles existentes en el tablero.
func get_aoe_coords(center: Vector2i, radius: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for coord in tiles:
		if get_tile_distance(coord, center) <= radius:
			result.append(coord)
	return result


## Resalta en púrpura los tiles dentro de la zona AoE (preview al hacer hover).
func highlight_aoe_preview(center: Vector2i, radius: int) -> void:
	clear_aoe_preview()
	var aoe_coords: Array[Vector2i] = get_aoe_coords(center, radius)
	for coord in aoe_coords:
		var tile: Tile = get_tile_at(coord)
		if tile:
			tile.set_aoe_preview_highlight(true)


## Limpia el highlight púrpura AoE de todos los tiles.
func clear_aoe_preview() -> void:
	for tile in tiles.values():
		if tile is Tile:
			tile.set_aoe_preview_highlight(false)


## Busca las coordenadas del tile que ocupa una unidad.
func get_coords_for_unit(unit: Node) -> Vector2i:
	for coord in tiles:
		var tile: Tile = tiles[coord]
		if tile and tile.occupied_by == unit:
			return coord
	return Vector2i(-1, -1)


## Distancia Manhattan entre dos coordenadas de tile.
func get_tile_distance(coord1: Vector2i, coord2: Vector2i) -> int:
	return absi(coord1.x - coord2.x) + absi(coord1.y - coord2.y)
