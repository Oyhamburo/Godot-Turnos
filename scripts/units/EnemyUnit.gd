extends Unit
class_name EnemyUnit

func _ready() -> void:
	team = Team.ENEMY
	super._ready()
