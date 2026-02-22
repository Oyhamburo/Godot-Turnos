extends Unit
class_name PlayerMannequin
##
## Mannequin Medium controlado por el jugador (modo RogueLike).
## Usa el modelo Mannequin_Medium.glb con animaciones Rig_Medium.
## Basado en EnemyUnit pero con team = PLAYER e inventario de RogueManager.
##

# ── Animaciones base (Rig_Medium de KayKit Skeletons 1.1) ─────
const RIG_ANIMATION_GLB := "res://assets/KayKit_Skeletons_1.1_FREE/Animations/gltf/Rig_Medium/Rig_Medium_General.glb"
const RIG_MOVEMENT_GLB := "res://assets/KayKit_Skeletons_1.1_FREE/Animations/gltf/Rig_Medium/Rig_Medium_MovementBasic.glb"

const BASE_ANIMS := {
	"spawn_air": "Spawn_Air",
	"idle": "Idle_B",
	"death": "Death_A",
	"hit": "Hit_B",
	"attack": "Interact"
}

# ── Animaciones de combate (KayKit Character Animations 1.1) ──
const _CHAR_ANIM_BASE := "res://assets/KayKit_Character_Animations_1.1/Animations/gltf/Rig_Medium/"
const COMBAT_MELEE_GLB := _CHAR_ANIM_BASE + "Rig_Medium_CombatMelee.glb"
const COMBAT_RANGED_GLB := _CHAR_ANIM_BASE + "Rig_Medium_CombatRanged.glb"
const MOVEMENT_ADV_GLB := _CHAR_ANIM_BASE + "Rig_Medium_MovementAdvanced.glb"

const MELEE_ANIMS := {
	"melee_1h_chop":    "Melee_1H_Attack_Chop",
	"melee_1h_slice":   "Melee_1H_Attack_Slice_Horizontal",
	"melee_1h_stab":    "Melee_1H_Attack_Stab",
	"melee_2h_chop":    "Melee_2H_Attack_Chop",
	"melee_2h_spin":    "Melee_2H_Attack_Spin",
	"melee_kick":       "Melee_Unarmed_Attack_Kick",
	"melee_punch":      "Melee_Unarmed_Attack_Punch_A",
	# ── Bloqueo ──
	"melee_block":         "Melee_Block",
	"melee_block_attack":  "Melee_Block_Attack",
	"melee_block_hit":     "Melee_Block_Hit",
	"melee_blocking":      "Melee_Blocking",
}

const RANGED_ANIMS := {
	"ranged_bow_draw":        "Ranged_Bow_Draw",
	"ranged_bow_draw_up":     "Ranged_Bow_Draw_Up",
	"ranged_bow_release":     "Ranged_Bow_Release",
	"ranged_bow_release_up":  "Ranged_Bow_Release_Up",
	"ranged_magic_shoot":     "Ranged_Magic_Shoot",
	"ranged_magic_spellcast": "Ranged_Magic_Spellcasting",
	"ranged_magic_summon":    "Ranged_Magic_Summon",
	"ranged_1h_shoot":        "Ranged_1H_Shoot",
}

const DODGE_ANIMS := {
	"dodge_backward": "Dodge_Backward",
	"dodge_forward": "Dodge_Forward",
	"dodge_left": "Dodge_Left",
	"dodge_right": "Dodge_Right",
}


func _ready() -> void:
	team = Team.PLAYER
	_setup_rig_animations(RIG_ANIMATION_GLB, BASE_ANIMS)
	_setup_walk_animation()
	_setup_combat_animations()
	super._ready()

	# Cargar inventario y HP desde RogueManager si hay una run activa
	var rm: Node = Engine.get_main_loop().root.get_node_or_null("RogueManager")
	if rm and rm.get("run_activa") and rm.run_activa and rm.get("rogue_inventory") != null:
		inventory = rm.rogue_inventory
		_aplicar_armas_del_inventario()
		# Restaurar HP persistente
		if rm.player_hp > 0:
			stats.hp = rm.player_hp
		if rm.player_max_hp > 0:
			stats.max_hp = rm.player_max_hp
	else:
		inventory = Inventory.new()
		_equip_default_weapon()

	set_animation_state(AnimState.SPAWN)


## Aplica las armas equipadas del inventario.
func _aplicar_armas_del_inventario() -> void:
	if inventory == null:
		return
	if inventory.equipped_right != null:
		equip_weapon_data(inventory.equipped_right, WeaponSlot.RIGHT_HAND)
	if inventory.equipped_left != null and inventory.equipped_left != inventory.equipped_right:
		equip_weapon_data(inventory.equipped_left, WeaponSlot.LEFT_HAND)


## Equipa arma por defecto: puños.
func _equip_default_weapon() -> void:
	var weapon_path := "res://data/weapons/mannequin_large_fists.tres"
	if ResourceLoader.exists(weapon_path):
		var weapon: WeaponData = load(weapon_path) as WeaponData
		if weapon:
			inventory.add_weapon(weapon)
			inventory.equipped_right = weapon
			equip_weapon_data(weapon)


## Carga animaciones de combate.
func _setup_combat_animations() -> void:
	if ResourceLoader.exists(COMBAT_MELEE_GLB):
		_setup_rig_animations(COMBAT_MELEE_GLB, MELEE_ANIMS)
	if ResourceLoader.exists(COMBAT_RANGED_GLB):
		_setup_rig_animations(COMBAT_RANGED_GLB, RANGED_ANIMS)
	if ResourceLoader.exists(MOVEMENT_ADV_GLB):
		_setup_rig_animations(MOVEMENT_ADV_GLB, DODGE_ANIMS)


## Carga la animación de caminar.
func _setup_walk_animation() -> void:
	var walk_name := _discover_walk_anim_name(RIG_MOVEMENT_GLB)
	if walk_name.is_empty():
		return
	_setup_rig_animations(RIG_MOVEMENT_GLB, {"walk": walk_name})


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
