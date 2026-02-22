extends Node3D
##
## Script mínimo para buildings de puerta en el mapa de exploración.
## Al tener trigger_event(), ExploreMap no bloquea el hex — el jugador
## puede caminar sobre él. ExploreMap detecta el hex por coordenada
## (GATE_HEX) y muestra el diálogo de entrada a la ciudad.
##

func trigger_event() -> void:
	pass
