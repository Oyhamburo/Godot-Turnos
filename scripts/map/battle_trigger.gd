extends Node3D
##
## Script para buildings que actúan como punto de inicio de batalla en el mapa de exploración.
## Al tener trigger_event(), ExploreMap no bloquea el hex — el jugador puede caminar sobre él.
## ExploreMap detecta el hex por coordenada (BATTLE_HEX) y muestra el diálogo de batalla.
##

func trigger_event() -> void:
	pass
