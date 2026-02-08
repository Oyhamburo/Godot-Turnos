@tool
extends Node3D
##
## En el editor: al abrir o recargar la escena, todos los hijos de Tiles
## se alinean al centro del hex más cercano (snap a la grilla).
## Así puedes colocar hexes a ojo y quedan siempre bien posicionados.
##

@onready var tiles_node: Node3D = $Tiles

func _ready() -> void:
	if not Engine.is_editor_hint():
		return
	_snap_tiles_to_grid()

func _snap_tiles_to_grid() -> void:
	var tiles: Node3D = tiles_node if tiles_node != null else get_node_or_null("Tiles") as Node3D
	if tiles == null:
		return
	for child in tiles.get_children():
		if not child is Node3D:
			continue
		var pos: Vector3 = child.position
		var hex: Vector2i = HexGrid.world_to_hex(pos.x, pos.z)
		var grid_pos: Vector3 = HexGrid.hex_to_world(hex.x, hex.y, 0.0)
		child.position = grid_pos
