extends Resource
class_name TileOverride
##
## Override manual por coordenada: piso, bloqueado, obstáculo.
##

@export var coord: Vector2i = Vector2i.ZERO
@export var floor_scene: PackedScene
@export var blocked: bool = false
@export var obstacle_scene: PackedScene
