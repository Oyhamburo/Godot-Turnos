extends Node3D
class_name Interactable
##
## Script base para objetos interactuables en el mapa de 3ra persona.
## El player busca nodos del grupo "interactable" con método interact(player).
## Sobreescribir interact() en subclases para lógica específica.
##

func _ready() -> void:
	add_to_group("interactable")
	# Asegurar que los StaticBody hijos estén en collision_layer 2
	# para que el InteractRay del player los detecte.
	for child in get_children():
		if child is StaticBody3D:
			child.collision_layer = 2


## Método a sobreescribir en subclases. Llamado cuando el player presiona E.
func interact(player: Node) -> void:
	print("[Interactable] %s interactuó con %s" % [player.name, name])
