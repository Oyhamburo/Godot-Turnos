extends Resource
class_name BattleEncounterConfig
##
## Configuración completa de un encuentro: tablero, suelos, obstáculos, spawns.
## Delegación de resolución a EncounterGenerator.
##

# Precarga tipos necesarios para que estén en scope.
const _FloorWeightEntry = preload("res://scripts/battle/data/floor_weight_entry.gd")
const _TileOverride = preload("res://scripts/battle/data/tile_override.gd")
const _UnitSpawn = preload("res://scripts/battle/data/unit_spawn.gd")

# --- Tablero ---
@export var width: int = 4
@export var height: int = 4
@export var tile_size: float = 4.0
@export var seed_value: int = 12345

# --- Floors ---
@export_enum("single", "weighted", "manual") var floor_mode: String = "single"
@export var floor_single_scene: PackedScene
@export var floor_weighted: Array[FloorWeightEntry] = []
@export var floor_manual_overrides: Array[TileOverride] = []

# --- Obstacles ---
@export_enum("manual", "random", "pattern") var obstacle_mode: String = "manual"
@export_range(0.0, 1.0) var obstacle_density: float = 0.15
@export var obstacle_manual_coords: Array[Vector2i] = []
@export_enum("none", "borders", "columns", "cross") var obstacle_pattern: String = "none"
@export var obstacle_scene: PackedScene
@export var obstacle_avoid_spawns: bool = true

# --- Spawns ---
@export var players: Array[UnitSpawn] = []
@export var enemies: Array[UnitSpawn] = []

# --- Orientación de unidades ---
## Cómo orientar las unidades al spawnear: hacia centroide del equipo contrario, hacia el más cercano, o dirección fija.
@export_enum("look_at_opponent_centroid", "look_at_nearest_opponent", "fixed") var facing_mode: String = "look_at_opponent_centroid"
## Dirección fija si facing_mode == "fixed", o fallback cuando no hay contrarios.
@export var fixed_facing_dir: Vector3 = Vector3(0, 0, 1)
