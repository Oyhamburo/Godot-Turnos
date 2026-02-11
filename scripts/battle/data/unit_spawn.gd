extends Resource
class_name UnitSpawn
##
## Spawn de unidad con modo de posición: manual, zona o random.
##

@export var unit_scene: PackedScene
@export var unit_data: UnitData
@export_enum("player", "enemy") var team: String = "player"
@export_enum("manual", "zone", "random") var position_mode: String = "manual"

## Coordenada fija si position_mode == "manual".
@export var coord: Vector2i = Vector2i.ZERO

## Zona permitida si position_mode == "zone". Rect2i(pos_x, pos_y, size_x, size_y).
@export var allowed_zone: Rect2i = Rect2i(0, 0, 2, 4)

## Tags opcionales (tank, healer, etc.).
@export var tags: String = ""
