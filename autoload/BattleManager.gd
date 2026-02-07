extends Node
## Guarda la batalla seleccionada desde el menú para que CombatManager la use al cargar la escena.

var current_battle_config: BattleConfig = null

func set_battle(config: BattleConfig) -> void:
	current_battle_config = config

func clear_battle() -> void:
	current_battle_config = null
