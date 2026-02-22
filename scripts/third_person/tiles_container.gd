@tool
extends Node3D
##
## Contenedor de tiles y edificios del mapa 3ra persona.
## Script @tool que al guardar la escena (Ctrl+S) alinea todos los hijos
## a Y=0 (nivel del suelo), manteniendo X y Z intactos.
## También preserva la rotación y escala.
##


func _notification(what: int) -> void:
	if what == NOTIFICATION_EDITOR_PRE_SAVE:
		_snap_hijos_al_suelo()


func _snap_hijos_al_suelo() -> void:
	for child in get_children():
		if child is Node3D:
			var pos: Vector3 = child.position
			if not is_zero_approx(pos.y):
				child.position = Vector3(pos.x, 0.0, pos.z)
				print("[TilesContainer] Snap '%s' → Y=0 (era Y=%.4f)" % [child.name, pos.y])
