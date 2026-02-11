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

const RIG_MOVEMENT_GLB := "res://assets/KayKit_Skeletons_1.1_FREE/Animations/gltf/Rig_Medium/Rig_Medium_MovementBasic.glb"

# ── KayKit Character Animations 1.1 ──────────────────────
const _CHAR_ANIM_BASE := "res://assets/KayKit_Character_Animations_1.1/Animations/gltf/Rig_Medium/"
const COMBAT_MELEE_GLB := _CHAR_ANIM_BASE + "Rig_Medium_CombatMelee.glb"
const COMBAT_RANGED_GLB := _CHAR_ANIM_BASE + "Rig_Medium_CombatRanged.glb"

# Animaciones melee para enemigos
const ENEMY_MELEE_ANIMS := {
	"melee_1h_chop": "Melee_1H_Attack_Chop",
	"melee_1h_stab": "Melee_1H_Attack_Stab",
	"melee_2h_slice": "Melee_2H_Attack_Slice",
	"melee_kick": "Melee_Unarmed_Attack_Kick",
}

# Animaciones a distancia para enemigos
const ENEMY_RANGED_ANIMS := {
	"ranged_magic_shoot": "Ranged_Magic_Shoot",
	"ranged_1h_shoot": "Ranged_1H_Shoot",
}


func _ready() -> void:
	team = Team.ENEMY
	var anim_map := {}
	for local_name in SKELETON_ANIMS:
		anim_map[local_name] = RIG_ANIM_NAMES[SKELETON_ANIMS[local_name]]
	_setup_rig_animations(RIG_ANIMATION_GLB, anim_map)
	_setup_walk_animation()
	_setup_combat_animations()
	super._ready()
	set_animation_state(AnimState.SPAWN)


## Carga animaciones de combate del pack KayKit Character Animations 1.1.
func _setup_combat_animations() -> void:
	if ResourceLoader.exists(COMBAT_MELEE_GLB):
		_setup_rig_animations(COMBAT_MELEE_GLB, ENEMY_MELEE_ANIMS)
	if ResourceLoader.exists(COMBAT_RANGED_GLB):
		_setup_rig_animations(COMBAT_RANGED_GLB, ENEMY_RANGED_ANIMS)

	# Mapeo ability_index → animación de ataque
	# Abilities 0,1 = distancia (range 99), Abilities 2,3 = melee (range 1)
	_attack_anim_for_ability = {
		0: "ranged_1h_shoot",       # Ataque a distancia débil
		1: "ranged_magic_shoot",    # Ataque a distancia fuerte
		2: "melee_1h_stab",         # Ataque melee débil
		3: "melee_1h_chop",         # Ataque melee fuerte
	}


## Carga la animación de caminar desde Rig_Medium_MovementBasic.glb.
func _setup_walk_animation() -> void:
	var walk_name := _discover_walk_anim_name(RIG_MOVEMENT_GLB)
	if walk_name.is_empty():
		return
	_setup_rig_animations(RIG_MOVEMENT_GLB, {"walk": walk_name})


## Busca el nombre real de la animación "walk" en el GLB de movimiento.
func _discover_walk_anim_name(glb_path: String) -> String:
	if not ResourceLoader.exists(glb_path):
		return ""
	var scene: PackedScene = load(glb_path) as PackedScene
	if not scene:
		return ""
	var inst: Node = scene.instantiate()
	var source_ap: AnimationPlayer = _find_anim_player_recursive(inst)
	var name_out := ""
	if source_ap:
		for candidate in ["Walk", "Walking", "walk"]:
			if source_ap.has_animation(candidate):
				name_out = candidate
				break
		if name_out.is_empty():
			for lib_name in source_ap.get_animation_library_list():
				var lib: AnimationLibrary = source_ap.get_animation_library(lib_name)
				if lib:
					for anim_name in lib.get_animation_list():
						if "walk" in String(anim_name).to_lower():
							name_out = String(anim_name) if lib_name.is_empty() else str(lib_name) + "/" + String(anim_name)
							break
					if not name_out.is_empty():
						break
	inst.queue_free()
	return name_out


func _find_anim_player_recursive(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n as AnimationPlayer
	for c in n.get_children():
		var ap := _find_anim_player_recursive(c)
		if ap:
			return ap
	return null
