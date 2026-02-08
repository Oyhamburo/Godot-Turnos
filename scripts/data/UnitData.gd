extends Resource
class_name UnitData

@export var display_name: String = "Unit"
@export_enum("PLAYER", "ENEMY") var team: int = 0

@export var max_hp: int = 30
@export var speed: int = 10
@export var stop_distance: float = 1.35

# Daño base (si physical_damage/magic_damage son 0, se usa attack como physical_damage)
@export var attack: int = 8
@export var physical_damage: int = 0
@export var magic_damage: int = 0
@export var armor: int = 0
@export var magic_resist: int = 0
@export_range(0.0, 1.0) var crit_chance: float = 0.05
@export_range(0.0, 1.0) var dodge_chance: float = 0.05

@export var color: Color = Color.WHITE
