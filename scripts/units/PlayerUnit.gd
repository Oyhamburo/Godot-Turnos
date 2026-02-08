extends Unit
class_name PlayerUnit

const RIG_ANIMATION_GLB := "res://assets/KayKit_Adventurers_2.0_FREE/Animations/gltf/Rig_Medium/Rig_Medium_General.glb"
const ADVENTURER_ANIMS := {
	"spawn_air": "Spawn_Air",
	"idle": "Idle_B",
	"death": "Death_A",
	"hit": "Hit_B",
	"attack": "Interact"
}

func _ready() -> void:
	team = Team.PLAYER
	_setup_rig_animations(RIG_ANIMATION_GLB, ADVENTURER_ANIMS)
	super._ready()
	set_animation_state(AnimState.SPAWN)
