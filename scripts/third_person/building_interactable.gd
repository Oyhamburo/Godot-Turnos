extends Interactable
class_name BuildingInteractable
##
## Edificio interactuable en la base.
## Al interactuar muestra el nombre del edificio en un cartel UI.
##

signal mostrar_nombre(nombre: String)

@export var nombre_edificio: String = "Edificio"


func interact(_player: Node) -> void:
	mostrar_nombre.emit(nombre_edificio)
