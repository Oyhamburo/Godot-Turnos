extends Node3D
class_name EventBuilding
##
## Componente para edificios que activan un evento al llegar el jugador al hex.
## No bloquea el movimiento: el jugador puede entrar en el hex y al hacerlo se dispara el evento.
##

const BATTLE_SCENE := "res://scenes/Battle.tscn"

## Si está asignado, al activar el evento se inicia esta batalla y se cambia a la escena de combate.
@export var battle_config: BattleConfig

## Devuelve true si este edificio tiene un evento configurado (p. ej. batalla).
func has_event() -> bool:
	return battle_config != null

## Llamado cuando el jugador llega al hex de este edificio. Inicia la batalla si battle_config está asignado.
func trigger_event() -> void:
	if battle_config == null:
		return
	var bm: Node = Engine.get_main_loop().get_root().get_node_or_null("BattleManager")
	if bm and bm.has_method("set_battle"):
		bm.set_battle(battle_config)
	get_tree().change_scene_to_file(BATTLE_SCENE)
