extends Unit
class_name EnemyMannequinLarge

## Enemigo Mannequin Large: usa el esqueleto Rig_Large con animaciones propias.
## No puede usar CombatRanged (no hay Rig_Large_CombatRanged), solo melee.

# ── KayKit Character Animations 1.1 — Rig_Large ──────────────
const _ANIM_BASE := "res://assets/KayKit_Character_Animations_1.1/Animations/gltf/Rig_Large/"
const RIG_ANIMATION_GLB := _ANIM_BASE + "Rig_Large_General.glb"
const RIG_MOVEMENT_GLB := _ANIM_BASE + "Rig_Large_MovementBasic.glb"
const COMBAT_MELEE_GLB := _ANIM_BASE + "Rig_Large_CombatMelee.glb"
const MOVEMENT_ADV_GLB := _ANIM_BASE + "Rig_Large_MovementAdvanced.glb"

# Animaciones base (mapeo nombre_local → nombre_en_glb)
# Rig_Large_General.glb tiene los mismos nombres de animación que Rig_Medium_General.glb
const BASE_ANIMS := {
	"spawn_air": "Spawn_Air",
	"idle": "Idle_B",
	"death": "Death_A",
	"hit": "Hit_B",
	"attack": "Interact"
}

# Animaciones melee
const MELEE_ANIMS := {
	"melee_1h_chop": "Melee_1H_Attack_Chop",
	"melee_1h_stab": "Melee_1H_Attack_Stab",
	"melee_2h_slice": "Melee_2H_Attack_Slice",
	"melee_kick": "Melee_Unarmed_Attack_Kick",
}

# Animaciones de dodge
const DODGE_ANIMS := {
	"dodge_backward": "Dodge_Backward",
	"dodge_forward": "Dodge_Forward",
	"dodge_left": "Dodge_Left",
	"dodge_right": "Dodge_Right",
}


func _ready() -> void:
	team = Team.ENEMY
	_setup_rig_animations(RIG_ANIMATION_GLB, BASE_ANIMS)
	_setup_walk_animation()
	_setup_combat_animations()
	super._ready()
	_equip_default_weapon()
	set_animation_state(AnimState.SPAWN)


## Carga animaciones de combate melee y dodge (no hay CombatRanged para Rig_Large).
func _setup_combat_animations() -> void:
	if ResourceLoader.exists(COMBAT_MELEE_GLB):
		_setup_rig_animations(COMBAT_MELEE_GLB, MELEE_ANIMS)
	if ResourceLoader.exists(MOVEMENT_ADV_GLB):
		_setup_rig_animations(MOVEMENT_ADV_GLB, DODGE_ANIMS)


## Carga la animación de caminar desde Rig_Large_MovementBasic.glb.
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


## Equipa arma por defecto: puños pesados (UNARMED, sin modelo visual).
func _equip_default_weapon() -> void:
	var weapon_path := "res://data/weapons/mannequin_large_fists.tres"
	if ResourceLoader.exists(weapon_path):
		var weapon: WeaponData = load(weapon_path) as WeaponData
		if weapon:
			equip_weapon_data(weapon)
