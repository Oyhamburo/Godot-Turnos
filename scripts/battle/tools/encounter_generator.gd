class_name EncounterGenerator
##
## Genera encuentros resueltos a partir de BattleEncounterConfig.
## Usable en runtime y en editor.
##

const TILE_SCENE := preload("res://scenes/battle/Tile.tscn")
const _SpawnEntry = preload("res://scripts/battle/data/spawn_entry.gd")
const _BattleEncounterConfig = preload("res://scripts/battle/data/battle_encounter_config.gd")
const _UnitSpawn = preload("res://scripts/battle/data/unit_spawn.gd")
const _FloorWeightEntry = preload("res://scripts/battle/data/floor_weight_entry.gd")
const FLOOR_SCENES_PATHS: Array[String] = [
	"res://scenes/floors/FloorTileLarge.tscn",
	"res://scenes/floors/FloorTileGrate.tscn",
	"res://scenes/floors/FloorTileLargeRocks.tscn",
]
const FLOOR_BLOCKED_PATH: String = "res://assets/KayKit_DungeonRemastered_1.1_FREE/Assets/gltf/floor_tile_big_spikes.gltf"
const KAYKIT_FLOOR_DIR: String = "res://assets/KayKit_DungeonRemastered_1.1_FREE/Assets/gltf"
const UNITS_DIR: String = "res://scenes/units/"

const MAX_SPAWN_RETRIES: int = 50

## Resultado de la generación.
class ResolvedEncounter:
	var tiles: Array[Dictionary] = []  # { coord, floor_scene, blocked }
	var unit_spawns: Array[Dictionary] = []  # { unit_scene, unit_data, coord, team }
	var obstacle_coords: Array[Vector2i] = []


static func generate(config: BattleEncounterConfig) -> ResolvedEncounter:
	var result := ResolvedEncounter.new()
	if not config:
		return result

	var rng := RandomNumberGenerator.new()
	rng.seed = config.seed_value

	# 1. Resolver spawn coords (antes de obstáculos para avoid_spawns)
	var occupied: Array[Vector2i] = []
	var all_spawns: Array[UnitSpawn] = []
	all_spawns.append_array(config.players)
	all_spawns.append_array(config.enemies)

	for spawn in all_spawns:
		if not spawn or not spawn.unit_scene:
			continue
		var coord := _resolve_spawn_coord(spawn, config, occupied, rng)
		if coord.x >= 0:
			occupied.append(coord)
			result.unit_spawns.append({
				"unit_scene": spawn.unit_scene,
				"unit_data": spawn.unit_data,
				"coord": coord,
				"team": spawn.team
			})

	# 2. Resolver obstáculos (excluir spawns si avoid_spawns)
	var blocked := _resolve_obstacle_coords(config, occupied, rng)
	result.obstacle_coords = blocked

	# 3. Resolver floors por tile
	var walkable_scenes := _load_floor_assets_walkable()
	var blocked_scene: PackedScene = _load_floor_blocked()
	if not blocked_scene:
		blocked_scene = walkable_scenes[0] if walkable_scenes.size() > 0 else null

	var floor_single: PackedScene = config.floor_single_scene if config.floor_single_scene else (walkable_scenes[0] if walkable_scenes.size() > 0 else null)
	var manual_map: Dictionary = {}
	for override in config.floor_manual_overrides:
		if override:
			manual_map[_coord_key(override.coord)] = override

	for y in range(config.height):
		for x in range(config.width):
			var coord := Vector2i(x, y)
			var is_blocked: bool = coord in blocked
			var floor_scene: PackedScene = null
			var override_entry = manual_map.get(_coord_key(coord))
			if override_entry and override_entry.floor_scene:
				floor_scene = override_entry.floor_scene
			elif config.floor_mode == "single":
				floor_scene = floor_single
			elif config.floor_mode == "weighted" and config.floor_weighted.size() > 0:
				floor_scene = _pick_weighted_floor(config.floor_weighted, rng)
			else:
				floor_scene = floor_single

			if is_blocked and blocked_scene:
				floor_scene = blocked_scene
			elif not floor_scene and walkable_scenes.size() > 0:
				floor_scene = walkable_scenes[0]

			result.tiles.append({
				"coord": coord,
				"floor_scene": floor_scene,
				"blocked": is_blocked
			})

	return result


static func _resolve_spawn_coord(spawn: UnitSpawn, config: BattleEncounterConfig, occupied: Array[Vector2i], rng: RandomNumberGenerator) -> Vector2i:
	match spawn.position_mode:
		"manual":
			if _is_valid_spawn(spawn.coord, config, occupied):
				return spawn.coord
			return Vector2i(-1, -1)
		"zone":
			var zone: Rect2i = spawn.allowed_zone
			var candidates: Array[Vector2i] = []
			for y in range(zone.position.y, zone.position.y + zone.size.y):
				for x in range(zone.position.x, zone.position.x + zone.size.x):
					var c := Vector2i(x, y)
					if _is_valid_spawn(c, config, occupied):
						candidates.append(c)
			if candidates.is_empty():
				return Vector2i(-1, -1)
			return candidates[rng.randi() % candidates.size()]
		"random":
			var candidates: Array[Vector2i] = []
			for y in range(config.height):
				for x in range(config.width):
					var c := Vector2i(x, y)
					if _is_valid_spawn(c, config, occupied):
						candidates.append(c)
			if candidates.is_empty():
				return Vector2i(-1, -1)
			return candidates[rng.randi() % candidates.size()]
	return Vector2i(-1, -1)


static func _is_valid_spawn(coord: Vector2i, config: BattleEncounterConfig, occupied: Array[Vector2i]) -> bool:
	if coord.x < 0 or coord.x >= config.width or coord.y < 0 or coord.y >= config.height:
		return false
	if coord in occupied:
		return false
	return true


static func _resolve_obstacle_coords(config: BattleEncounterConfig, exclude_coords: Array[Vector2i], rng: RandomNumberGenerator) -> Array[Vector2i]:
	var exclude_set: Dictionary = {}
	for c in exclude_coords:
		exclude_set[_coord_key(c)] = true

	match config.obstacle_mode:
		"manual":
			var result: Array[Vector2i] = []
			for c in config.obstacle_manual_coords:
				if config.obstacle_avoid_spawns and exclude_set.get(_coord_key(c), false):
					continue
				result.append(c)
			return result
		"random":
			var result: Array[Vector2i] = []
			for y in range(config.height):
				for x in range(config.width):
					var c := Vector2i(x, y)
					if config.obstacle_avoid_spawns and exclude_set.get(_coord_key(c), false):
						continue
					if rng.randf() < config.obstacle_density:
						result.append(c)
			return result
		"pattern":
			var result: Array[Vector2i] = []
			match config.obstacle_pattern:
				"borders":
					for x in range(config.width):
						_try_add_obstacle(result, Vector2i(x, 0), config, exclude_set)
						_try_add_obstacle(result, Vector2i(x, config.height - 1), config, exclude_set)
					for y in range(1, config.height - 1):
						_try_add_obstacle(result, Vector2i(0, y), config, exclude_set)
						_try_add_obstacle(result, Vector2i(config.width - 1, y), config, exclude_set)
				"columns":
					for y in range(config.height):
						for x in range(config.width):
							if x % 2 == 1:
								_try_add_obstacle(result, Vector2i(x, y), config, exclude_set)
				"cross":
					var cx: int = int(config.width / 2.0)
					var cy: int = int(config.height / 2.0)
					for x in range(config.width):
						_try_add_obstacle(result, Vector2i(x, cy), config, exclude_set)
					for y in range(config.height):
						_try_add_obstacle(result, Vector2i(cx, y), config, exclude_set)
			return result
	return []


static func _try_add_obstacle(result: Array[Vector2i], coord: Vector2i, config: BattleEncounterConfig, exclude_set: Dictionary) -> void:
	if config.obstacle_avoid_spawns and exclude_set.get(_coord_key(coord), false):
		return
	result.append(coord)


static func _pick_weighted_floor(entries: Array[FloorWeightEntry], rng: RandomNumberGenerator) -> PackedScene:
	var total: float = 0.0
	for e in entries:
		if e:
			total += max(0.0, e.weight)
	if total <= 0:
		return null
	var r: float = rng.randf() * total
	for e in entries:
		if not e:
			continue
		r -= e.weight
		if r <= 0 and e.floor_scene:
			return e.floor_scene
	return entries[0].floor_scene if entries.size() > 0 and entries[0] else null


static func _coord_key(c: Vector2i) -> String:
	return "%d,%d" % [c.x, c.y]


static func _load_floor_assets_walkable() -> Array[PackedScene]:
	var list: Array[PackedScene] = []
	for path in FLOOR_SCENES_PATHS:
		if ResourceLoader.exists(path):
			var scene: PackedScene = load(path) as PackedScene
			if scene:
				list.append(scene)
	if list.is_empty():
		var dir := DirAccess.open(KAYKIT_FLOOR_DIR)
		if dir:
			dir.list_dir_begin()
			var file := dir.get_next()
			while file != "":
				if file.ends_with(".gltf") and file.begins_with("floor") and "spike" not in file.to_lower():
					var full := KAYKIT_FLOOR_DIR.path_join(file)
					var scene: PackedScene = load(full) as PackedScene
					if scene and list.size() < 3:
						list.append(scene)
				file = dir.get_next()
			dir.list_dir_end()
	return list


static func _load_floor_blocked() -> PackedScene:
	if ResourceLoader.exists(FLOOR_BLOCKED_PATH):
		return load(FLOOR_BLOCKED_PATH) as PackedScene
	var dir := DirAccess.open(KAYKIT_FLOOR_DIR)
	if dir:
		dir.list_dir_begin()
		var file := dir.get_next()
		while file != "":
			if "spike" in file.to_lower() and file.ends_with(".gltf"):
				var full := KAYKIT_FLOOR_DIR.path_join(file)
				return load(full) as PackedScene
			file = dir.get_next()
		dir.list_dir_end()
	return null


## Convierte ResolvedEncounter a BattleConfig para compatibilidad con BattleFlow.
static func to_battle_config(resolved: ResolvedEncounter, config: BattleEncounterConfig) -> BattleConfig:
	if not config:
		return null
	var bc := BattleConfig.new()
	bc.width = config.width
	bc.height = config.height
	bc.tile_size = config.tile_size
	bc.blocked_coords = resolved.obstacle_coords.duplicate()
	bc.facing_mode = config.facing_mode
	bc.fixed_facing_dir = config.fixed_facing_dir
	bc.spawns.clear()
	for sp in resolved.unit_spawns:
		var se := SpawnEntry.new()
		se.unit_scene = sp.unit_scene
		se.unit_data = sp.unit_data
		se.spawn_coords = sp.coord
		se.team = sp.team
		bc.spawns.append(se)
	return bc


## Instancia el encuentro en nodos 3D. tiles_parent y units_parent deben existir.
static func instantiate_in_scene(resolved: ResolvedEncounter, config: BattleEncounterConfig, tiles_parent: Node3D, units_parent: Node3D, set_owner: Node = null) -> void:
	if not config:
		return

	var ts: float = config.tile_size
	var half_w: float = (config.width - 1) * ts * 0.5
	var half_h: float = (config.height - 1) * ts * 0.5

	for t in resolved.tiles:
		var coord: Vector2i = t.coord
		var floor_scene: PackedScene = t.floor_scene
		var blocked: bool = t.blocked
		var pos := Vector3(coord.x * ts - half_w, 0.0, coord.y * ts - half_h)

		var tile: Tile = TILE_SCENE.instantiate() as Tile
		tiles_parent.add_child(tile)
		tile.coords = coord
		tile.world_position = pos
		tile.position = pos
		tile.setup_floor(floor_scene, blocked, ts)
		if set_owner:
			tile.owner = set_owner
		tile.name = "Generated_Tile_%d_%d" % [coord.x, coord.y]

	var unit_nodes: Array[Node3D] = []
	var unit_positions: Array[Vector3] = []
	var unit_teams: Array[String] = []

	for sp in resolved.unit_spawns:
		var unit_scene: PackedScene = sp.unit_scene
		var unit_data: UnitData = sp.unit_data
		var coord: Vector2i = sp.coord
		var pos := Vector3(coord.x * ts - half_w, 0.1, coord.y * ts - half_h)

		var unit: Node = unit_scene.instantiate()
		if "data" in unit and unit_data:
			unit.set("data", unit_data)
		units_parent.add_child(unit)
		unit.global_position = pos
		if set_owner:
			unit.owner = set_owner
		unit.name = "Generated_Unit_%s_%d_%d" % [sp.team, coord.x, coord.y]

		if unit is Node3D:
			unit_nodes.append(unit)
			unit_positions.append(pos)
			unit_teams.append(sp.team)

	_apply_unit_facing(unit_nodes, unit_positions, unit_teams, config)


## Aplica orientación a las unidades según facing_mode: miran hacia el equipo contrario.
## Godot: -Z es forward; look_at hace que -Z apunte al target.
static func _apply_unit_facing(unit_nodes: Array[Node3D], unit_positions: Array[Vector3], unit_teams: Array[String], config: BattleEncounterConfig) -> void:
	if unit_nodes.is_empty():
		return

	var player_positions: Array[Vector3] = []
	var enemy_positions: Array[Vector3] = []
	for i in range(unit_positions.size()):
		if unit_teams[i] == "player":
			player_positions.append(unit_positions[i])
		else:
			enemy_positions.append(unit_positions[i])

	var player_centroid := _compute_centroid(player_positions)
	var enemy_centroid := _compute_centroid(enemy_positions)

	var fixed_dir: Vector3 = config.fixed_facing_dir
	if fixed_dir.length_squared() < 0.0001:
		fixed_dir = Vector3(0, 0, 1)
	fixed_dir = fixed_dir.normalized()

	for i in range(unit_nodes.size()):
		var unit: Node3D = unit_nodes[i]
		var pos: Vector3 = unit_positions[i]
		var team: String = unit_teams[i]
		var opponents: Array[Vector3] = enemy_positions if team == "player" else player_positions
		var target_pos: Vector3

		match config.facing_mode:
			"look_at_opponent_centroid":
				if opponents.is_empty():
					target_pos = pos + fixed_dir
				else:
					target_pos = enemy_centroid if team == "player" else player_centroid
			"look_at_nearest_opponent":
				if opponents.is_empty():
					target_pos = pos + fixed_dir
				else:
					var nearest: Vector3 = opponents[0]
					var dmin: float = pos.distance_squared_to(nearest)
					for o in opponents:
						var d: float = pos.distance_squared_to(o)
						if d < dmin:
							dmin = d
							nearest = o
					target_pos = nearest
			"fixed":
				target_pos = pos + fixed_dir
			_:
				target_pos = pos + fixed_dir

		if target_pos.distance_squared_to(pos) > 0.0001:
			unit.look_at(target_pos, Vector3.UP)
			# Debug: verificar orientación (Godot: -Z es forward)
			var forward: Vector3 = -unit.global_transform.basis.z
			forward.y = 0
			if forward.length_squared() > 0.01:
				forward = forward.normalized()
			var expected_dir: Vector3 = (target_pos - pos)
			expected_dir.y = 0
			if expected_dir.length_squared() > 0.01:
				expected_dir = expected_dir.normalized()
			var dot: float = forward.dot(expected_dir)
			print("[Facing] %s team=%s pos=%s target=%s forward=-Z=(%s) expected_dir=(%s) dot=%.3f (1=correcto)" % [unit.name, team, pos, target_pos, forward, expected_dir, dot])
		else:
			print("[Facing] %s team=%s pos=%s (sin target, sin orientar)" % [unit.name, team, pos])


static func _compute_centroid(positions: Array[Vector3]) -> Vector3:
	if positions.is_empty():
		return Vector3.ZERO
	var sum := Vector3.ZERO
	for p in positions:
		sum += p
	return sum / float(positions.size())
