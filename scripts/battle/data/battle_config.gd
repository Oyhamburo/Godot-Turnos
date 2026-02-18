extends Resource
class_name BattleConfig
##
## Carga SpawnEntry para que el tipo esté disponible.
const _SpawnEntry = preload("res://scripts/battle/data/spawn_entry.gd")
## Configuración de una batalla: tamaño del tablero, tiles bloqueados y spawns de unidades.
##

@export var width: int = 4
@export var height: int = 4
@export var tile_size: float = 2.0

## Coordenadas (x, y) de tiles bloqueados (impasables).
@export var blocked_coords: Array[Vector2i] = []

## Lista de spawns. Cada SpawnEntry define unidad, datos, coordenadas y equipo.
@export var spawns: Array[SpawnEntry] = []

## Orientación al spawnear: look_at_opponent_centroid, look_at_nearest_opponent, fixed.
@export_enum("look_at_opponent_centroid", "look_at_nearest_opponent", "fixed") var facing_mode: String = "look_at_opponent_centroid"
## Dirección fija si facing_mode == "fixed", o fallback cuando no hay contrarios.
@export var fixed_facing_dir: Vector3 = Vector3(0, 0, 1)

## Devuelve las coordenadas bloqueadas. Por defecto usa blocked_coords.
## Sobrescribir para generar bloqueos dinámicamente.
func get_blocked_coords() -> Array[Vector2i]:
	return blocked_coords.duplicate()
