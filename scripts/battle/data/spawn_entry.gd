extends Resource
class_name SpawnEntry
##
## Define un spawn de unidad: escena, datos, coordenadas y equipo.
##

@export var unit_scene: PackedScene
@export var unit_data: UnitData
@export var spawn_coords: Vector2i = Vector2i.ZERO
@export_enum("player", "enemy") var team: String = "player"
