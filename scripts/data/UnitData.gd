extends Resource
class_name UnitData

@export var display_name: String = "Unit"
@export_enum("PLAYER", "ENEMY") var team: int = 0

@export var max_hp: int = 30
@export var speed: int = 10
@export var attack: int = 8
@export var stop_distance: float = 1.35

@export var color: Color = Color.WHITE
