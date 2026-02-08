extends Unit
class_name EnemyUnit

# Animaciones disponibles en Rig_Medium_General.glb (orden igual que en el GLB).
enum RigAnim {
	DEATH_A,
	DEATH_A_POSE,
	DEATH_B,
	DEATH_B_POSE,
	HIT_A,
	HIT_B,
	IDLE_A,
	IDLE_B,
	INTERACT,
	PICK_UP,
	SPAWN_AIR,
	SPAWN_GROUND,
	T_POSE,
	THROW,
	USE_ITEM
}

# Mapeo enum -> nombre real de la animación en el GLB.
const RIG_ANIM_NAMES: Array[String] = [
	"Death_A", "Death_A_Pose", "Death_B", "Death_B_Pose",
	"Hit_A", "Hit_B", "Idle_A", "Idle_B", "Interact", "PickUp",
	"Spawn_Air", "Spawn_Ground", "T-Pose", "Throw", "Use_Item"
]

# Ruta al GLB que contiene las animaciones del rig KayKit (mismo esqueleto que Skeleton_Warrior).
const RIG_ANIMATION_GLB := "res://assets/KayKit_Skeletons_1.1_FREE/Animations/gltf/Rig_Medium/Rig_Medium_General.glb"

# Animaciones que usamos: nombre interno en nuestro AnimationPlayer -> RigAnim.
const SKELETON_ANIMS := {
	"spawn_air": RigAnim.SPAWN_AIR,
	"idle": RigAnim.IDLE_B,
	"death": RigAnim.DEATH_A,
	"hit": RigAnim.HIT_B,
	"attack": RigAnim.INTERACT
}

func _ready() -> void:
	team = Team.ENEMY
	var anim_map := {}
	for local_name in SKELETON_ANIMS:
		anim_map[local_name] = RIG_ANIM_NAMES[SKELETON_ANIMS[local_name]]
	_setup_rig_animations(RIG_ANIMATION_GLB, anim_map)
	super._ready()
	set_animation_state(AnimState.SPAWN)
