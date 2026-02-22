extends Unit
class_name PlayerUnit

const RIG_ANIMATION_GLB := "res://assets/KayKit_Adventurers_2.0_FREE/Animations/gltf/Rig_Medium/Rig_Medium_General.glb"
const RIG_MOVEMENT_GLB := "res://assets/KayKit_Adventurers_2.0_FREE/Animations/gltf/Rig_Medium/Rig_Medium_MovementBasic.glb"
const ADVENTURER_ANIMS := {
	"spawn_air": "Spawn_Air",
	"idle": "Idle_B",
	"death": "Death_A",
	"hit": "Hit_B",
	"attack": "Interact"
}

# ── Armas del pack KayKit Adventurers ──────────────────────
const _ADV_WEAPONS := "res://assets/weapons/"

# ── KayKit Character Animations 1.1 ──────────────────────
const _CHAR_ANIM_BASE := "res://assets/KayKit_Character_Animations_1.1/Animations/gltf/Rig_Medium/"
const COMBAT_MELEE_GLB := _CHAR_ANIM_BASE + "Rig_Medium_CombatMelee.glb"
const COMBAT_RANGED_GLB := _CHAR_ANIM_BASE + "Rig_Medium_CombatRanged.glb"
const MOVEMENT_ADV_GLB := _CHAR_ANIM_BASE + "Rig_Medium_MovementAdvanced.glb"

# Animaciones melee a registrar (nombre local → nombre en GLB)
const MELEE_ANIMS := {
	"melee_1h_chop": "Melee_1H_Attack_Chop",
	"melee_1h_slice": "Melee_1H_Attack_Slice_Horizontal",
	"melee_1h_stab": "Melee_1H_Attack_Stab",
	"melee_2h_chop": "Melee_2H_Attack_Chop",
	"melee_2h_spin": "Melee_2H_Attack_Spin",
	"melee_kick": "Melee_Unarmed_Attack_Kick",
	"melee_punch": "Melee_Unarmed_Attack_Punch_A",
}

# Animaciones a distancia a registrar
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

# Animaciones avanzadas de movimiento
const ADV_MOVE_ANIMS := {
	"dodge_backward": "Dodge_Backward",
	"dodge_forward": "Dodge_Forward",
	"dodge_left": "Dodge_Left",
	"dodge_right": "Dodge_Right",
}


func _ready() -> void:
	team = Team.PLAYER
	_setup_rig_animations(RIG_ANIMATION_GLB, ADVENTURER_ANIMS)
	_setup_walk_animation()
	_setup_combat_animations()
	super._ready()
	# Usar el inventario global del GameManager si está disponible
	var gm: Node = Engine.get_main_loop().root.get_node_or_null("GameManager")
	if gm and gm.get("player_inventory") != null:
		inventory = gm.player_inventory
	else:
		# Fallback: crear inventario local (para testing sin autoload)
		inventory = Inventory.new()
		_equip_default_weapon()
		_populate_default_inventory()
	_aplicar_armas_del_inventario()
	set_animation_state(AnimState.SPAWN)


## Detecta el nombre del rig activo (clase del personaje) desde los hijos de Visual.
func _detect_rig_name() -> String:
	for c in visual.get_children():
		if not c is AnimationPlayer:
			return c.name
	return ""


## Equipa arma por defecto según la clase del personaje usando WeaponData resources.
func _equip_default_weapon() -> void:
	var rig_name := _detect_rig_name()
	var weapon_path := ""
	match rig_name:
		"Knight":
			weapon_path = "res://data/weapons/swords/player_sword.tres"
			# El Knight empieza con escudo en mano izquierda (WeaponData real, no cosmético)
			var shield_path := "res://data/weapons/shields/player_shield.tres"
			if ResourceLoader.exists(shield_path):
				var shield: WeaponData = load(shield_path) as WeaponData
				if shield:
					inventory.equipped_left = shield
					inventory.add_weapon(shield)
					equip_weapon_data(shield, WeaponSlot.LEFT_HAND)
		"Barbarian":
			weapon_path = "res://data/weapons/axes/player_axe_2h.tres"
		"Mage":
			weapon_path = "res://data/weapons/staves/player_staff.tres"
			# El libro de hechizos sigue siendo cosmético (no es arma del sistema)
			equip_weapon(WeaponSlot.LEFT_HAND, _ADV_WEAPONS + "spellbook_open.gltf")
		"Ranger":
			weapon_path = "res://data/weapons/bows/player_bow.tres"
		"Rogue", "Rogue_Hooded":
			weapon_path = "res://data/weapons/swords/player_dagger.tres"
		_:
			weapon_path = "res://data/weapons/swords/player_sword.tres"
	if ResourceLoader.exists(weapon_path):
		var weapon: WeaponData = load(weapon_path) as WeaponData
		if weapon:
			inventory.equipped_right = weapon
			inventory.add_weapon(weapon)
			equip_weapon_data(weapon)


## Rellena el inventario con TODAS las armas disponibles del juego (para pruebas).
func _populate_default_inventory() -> void:
	var all_weapon_paths: Array[String] = [
		"res://data/weapons/swords/player_sword.tres",
		"res://data/weapons/bows/player_bow.tres",
		"res://data/weapons/staves/player_staff.tres",
		"res://data/weapons/axes/player_axe_2h.tres",
		"res://data/weapons/swords/player_dagger.tres",
		"res://data/weapons/shields/player_shield.tres",
	]
	for path in all_weapon_paths:
		if ResourceLoader.exists(path):
			var w: WeaponData = load(path) as WeaponData
			if w and not inventory.weapons.has(w):
				inventory.add_weapon(w)


## Aplica visualmente las armas que ya están equipadas en el inventario global.
## No modifica el inventario; solo llama equip_weapon_data() para mostrar los modelos 3D.
func _aplicar_armas_del_inventario() -> void:
	if inventory == null:
		return
	if inventory.equipped_right != null:
		equip_weapon_data(inventory.equipped_right, WeaponSlot.RIGHT_HAND)
	if inventory.equipped_left != null and inventory.equipped_left != inventory.equipped_right:
		equip_weapon_data(inventory.equipped_left, WeaponSlot.LEFT_HAND)


## Carga animaciones de combate del pack KayKit Character Animations 1.1.
func _setup_combat_animations() -> void:
	if ResourceLoader.exists(COMBAT_MELEE_GLB):
		_setup_rig_animations(COMBAT_MELEE_GLB, MELEE_ANIMS)
	if ResourceLoader.exists(COMBAT_RANGED_GLB):
		_setup_rig_animations(COMBAT_RANGED_GLB, RANGED_ANIMS)
	if ResourceLoader.exists(MOVEMENT_ADV_GLB):
		_setup_rig_animations(MOVEMENT_ADV_GLB, ADV_MOVE_ANIMS)
	# Las animaciones de ataque ahora vienen del anim_name en WeaponData.abilities


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
