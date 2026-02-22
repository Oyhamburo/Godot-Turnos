extends CharacterBody3D
class_name Unit

const _UnitStats = preload("res://scripts/unit/stats/unit_stats.gd")
const _UnitStatsTemplate = preload("res://scripts/unit/stats/unit_stats_template.gd")
const _FloatingHUDScene = preload("res://scenes/ui/FloatingHUD.tscn")

signal hp_changed(unit: Unit)
signal died(unit: Unit)

enum Team { PLAYER, ENEMY }

## Estados de la máquina de estados de animación (unidades con AnimationPlayer).
enum AnimState {
	NONE,
	IDLE,
	SPAWN,
	HIT,
	DEATH,
	ATTACK,
	WALK
}

@export var data: UnitData
@export var display_name: String = "Unit"
@export_enum("PLAYER", "ENEMY") var team: int = 0
@export var stop_distance: float = 1.35
@export var color: Color = Color.WHITE

## Stats runtime; se crea desde stats_template o desde data.
var stats: UnitStats

@onready var visual: Node3D = $Visual
@onready var selection_ring: MeshInstance3D = $SelectionRing
@onready var collider: CollisionShape3D = $CollisionShape3D

var alive: bool = true
var _start_position: Vector3
var _start_rotation: Vector3
var _idle_tween: Tween
var _mat: StandardMaterial3D
var _base_color: Color
var _mesh_instances: Array[MeshInstance3D] = []
var _mesh_materials: Array[Material] = []
var _use_unit_color: bool = true  # false cuando usamos material del GLB (conservar textura)
var _anim_state: AnimState = AnimState.NONE

## Sistema de armas — BoneAttachment3D en handslot.r / handslot.l del Skeleton3D.
enum WeaponSlot { RIGHT_HAND, LEFT_HAND }
var _skeleton: Skeleton3D = null
var _weapon_attachment_r: BoneAttachment3D = null
var _weapon_attachment_l: BoneAttachment3D = null
var _equipped_weapon_r: Node3D = null
var _equipped_weapon_l: Node3D = null

## WeaponData equipado en mano derecha (o arma 2H); null = vacío.
var _equipped_weapon_data_r: WeaponData = null
## WeaponData equipado en mano izquierda; null = vacío. Igual a _r si es 2H.
var _equipped_weapon_data_l: WeaponData = null

## Inventario del jugador (null en enemigos).
var inventory: Inventory = null

## true cuando la unidad usó "Defender" este turno: anula el siguiente golpe recibido.
var _blocking: bool = false

## Gestor de efectos de estado (veneno, stun, buffs, etc.). Composición.
var efectos_manager: StatusEffectManager = null

## Modificadores QTE (temporales, por ataque del player)
var _qte_hit_bonus: float = 0.0      # +0.10 si perfect
var _qte_crit_bonus: float = 0.0     # +0.15 si perfect
var _qte_evasion_bonus: float = 0.0  # +0.15 si fallo (se aplica al target)

## Último enemigo atacado por esta unidad (para orientarse al terminar de moverse).
var _last_attacked_unit: Unit = null

## Habilidad básica de golpe: disponible siempre que no haya arma equipada.
const BASIC_MELEE_ABILITY: Dictionary = {
	"display_name": "Golpe Básico",
	"physical": 3,
	"magic": 0,
	"hit_chance": 0.90,
	"range": 1,
	"anim_name": "melee_punch"
}

## Devuelve todas las habilidades combinadas de ambas manos equipadas.
## Si ninguna mano tiene arma, devuelve array vacío (get_ability() devolverá BASIC_MELEE_ABILITY).
static func get_all_abilities(unit: Unit) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if unit == null:
		return result
	var wr: WeaponData = unit._equipped_weapon_data_r
	var wl: WeaponData = unit._equipped_weapon_data_l
	if wr != null and not wr.abilities.is_empty():
		result.append_array(wr.abilities)
	# Incluir mano izquierda sólo si es un arma distinta (evita duplicar bonuses de 2H)
	if wl != null and wl != wr and not wl.abilities.is_empty():
		result.append_array(wl.abilities)
	return result

## Devuelve la habilidad en ability_index combinando ambas manos.
## Si no hay arma en ninguna mano, devuelve BASIC_MELEE_ABILITY.
static func get_ability(unit: Unit, ability_index: int) -> Dictionary:
	if unit == null or ability_index < 0:
		return Unit.BASIC_MELEE_ABILITY
	var all_abilities: Array[Dictionary] = Unit.get_all_abilities(unit)
	if all_abilities.is_empty():
		return Unit.BASIC_MELEE_ABILITY
	return all_abilities[clampi(ability_index, 0, all_abilities.size() - 1)]

func _get_visual_meshes() -> Array[MeshInstance3D]:
	var list: Array[MeshInstance3D] = []
	if visual is MeshInstance3D:
		list.append(visual as MeshInstance3D)
	else:
		for c in visual.find_children("*", "MeshInstance3D", true, false):
			list.append(c as MeshInstance3D)
	return list

func _get_mesh_surface_material(mi: MeshInstance3D) -> Material:
	if mi.material_override:
		return mi.material_override.duplicate(true)
	if mi.mesh and mi.mesh.get_surface_count() > 0:
		var surf_mat: Material = mi.mesh.surface_get_material(0)
		if surf_mat:
			return surf_mat.duplicate(true)
	return null

func _ready() -> void:
	if data:
		_apply_data()
	else:
		_create_default_stats()
	_ensure_stats()
	efectos_manager = StatusEffectManager.new(self)
	add_floating_hud()
	_start_position = global_position
	_start_rotation = global_rotation

	_mesh_instances = _get_visual_meshes()
	if _mesh_instances.is_empty():
		push_error("Unit: Visual no tiene MeshInstance3D")
		return

	# Usar material del mesh (GLB con textura) cuando no hay material_override; si no, material plano.
	var first_mat: Material = _get_mesh_surface_material(_mesh_instances[0])
	if first_mat == null:
		first_mat = StandardMaterial3D.new()
		_use_unit_color = true
	else:
		_use_unit_color = false

	for i in range(_mesh_instances.size()):
		var mi: MeshInstance3D = _mesh_instances[i]
		var mat: Material = first_mat if i == 0 else _get_mesh_surface_material(mi)
		if mat == null:
			mat = StandardMaterial3D.new()
		mi.material_override = mat
		_mesh_materials.append(mat)

	_mat = first_mat as StandardMaterial3D
	if _mat:
		if _use_unit_color:
			_base_color = color
			_mat.albedo_color = _base_color
		else:
			_base_color = _mat.albedo_color
	else:
		_base_color = color
	selection_ring.visible = false
	_setup_weapon_slots()
	var ap: AnimationPlayer = _get_anim_ap()
	if ap:
		ap.animation_finished.connect(_on_animation_finished)
	set_animation_state(AnimState.IDLE)

func _physics_process(delta: float) -> void:
	if not alive:
		return
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y += get_gravity().y * delta
	move_and_slide()

func _apply_data() -> void:
	display_name = data.display_name
	team = data.team
	stop_distance = data.stop_distance
	color = data.color
	var t: UnitStatsTemplate
	if data.stats_template:
		t = data.stats_template
	else:
		t = _build_template_from_data()
	stats = _UnitStats.from_template(t)
	if stats and stats.template:
		display_name = stats.template.display_name
		team = stats.template.team


func _build_template_from_data() -> UnitStatsTemplate:
	var t := _UnitStatsTemplate.new()
	t.display_name = data.display_name
	t.team = data.team
	t.max_hp = data.max_hp
	t.max_mana = 0
	t.speed = data.speed
	t.armor = data.armor
	t.magic_resist = data.magic_resist
	t.physical_damage = data.physical_damage if data.physical_damage > 0 else data.attack
	t.magic_damage = data.magic_damage
	t.evasion = data.dodge_chance
	t.crit_chance = data.crit_chance
	return t


func _create_default_stats() -> void:
	var t := _UnitStatsTemplate.new()
	t.display_name = display_name
	t.team = team
	t.max_hp = 30
	t.max_mana = 0
	t.speed = 10
	t.armor = 0
	t.magic_resist = 0
	t.physical_damage = 8
	t.magic_damage = 0
	t.evasion = 0.05
	t.crit_chance = 0.05
	stats = _UnitStats.from_template(t)


func _ensure_stats() -> void:
	if not stats:
		_create_default_stats()


func add_floating_hud() -> void:
	if not stats:
		print("[Unit] %s: add_floating_hud - stats es null!" % display_name)
		return
	var hud: Node3D = _FloatingHUDScene.instantiate()
	add_child(hud)
	hud.position = Vector3(0.0, 1.85, 0.0)
	if hud is FloatingHUD:
		hud.setup(stats, display_name, team)
		stats.hp_changed.connect(_on_stats_hp_changed)
		# Conectar efectos de estado al HUD para mostrar emojis
		if efectos_manager:
			hud.conectar_efectos(efectos_manager)
		print("[Unit] %s: FloatingHUD creado - HP %d/%d - team: %d - pos: %s" % [display_name, stats.hp, stats.max_hp, team, hud.position])
	else:
		print("[Unit] %s: hud instanciado pero no es FloatingHUD!" % display_name)


func _on_stats_hp_changed(_current: int, _max_val: int) -> void:
	print("[Unit] %s: hp_changed -> %d/%d" % [display_name, _current, _max_val])
	emit_signal("hp_changed", self)

func refresh_visual_color() -> void:
	if not _use_unit_color:
		return
	_base_color = color
	for m in _mesh_materials:
		if m is StandardMaterial3D:
			(m as StandardMaterial3D).albedo_color = _base_color

func reset_start_pose() -> void:
	_start_position = global_position
	_start_rotation = global_rotation

func set_selected(selected: bool) -> void:
	if not alive:
		selection_ring.visible = false
		return
	selection_ring.visible = selected

func _get_anim_ap() -> AnimationPlayer:
	return visual.get_node_or_null("AnimationPlayer") as AnimationPlayer


# ── WEAPON ATTACHMENT ─────────────────────────────────────

## Busca el Skeleton3D dentro del árbol de nodos (recursivo).
func _find_skeleton_recursive(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node as Skeleton3D
	for c in node.get_children():
		var found := _find_skeleton_recursive(c)
		if found:
			return found
	return null


## Crea los BoneAttachment3D en handslot.r/l (o hand.r/l como fallback).
## Llamado desde _ready(), después de que el GLB ya está instanciado.
func _setup_weapon_slots() -> void:
	_skeleton = _find_skeleton_recursive(visual)
	if not _skeleton:
		return

	# Intentar primero "handslot.r/l" (Mannequin_Large, Adventurers),
	# si no existe usar "hand.r/l" (Mannequin_Medium, Skeletons sin slot dedicado).
	var name_r := "handslot.r" if _skeleton.find_bone("handslot.r") >= 0 else "hand.r"
	var name_l := "handslot.l" if _skeleton.find_bone("handslot.l") >= 0 else "hand.l"

	if _skeleton.find_bone(name_r) >= 0:
		_weapon_attachment_r = BoneAttachment3D.new()
		_weapon_attachment_r.bone_name = name_r
		_skeleton.add_child(_weapon_attachment_r)

	if _skeleton.find_bone(name_l) >= 0:
		_weapon_attachment_l = BoneAttachment3D.new()
		_weapon_attachment_l.bone_name = name_l
		_skeleton.add_child(_weapon_attachment_l)


## Equipa un arma en el slot indicado. weapon_scene_path vacío = desequipar.
func equip_weapon(slot: WeaponSlot, weapon_scene_path: String, offset_pos: Vector3 = Vector3.ZERO, offset_rot: Vector3 = Vector3.ZERO) -> void:
	var attachment: BoneAttachment3D
	if slot == WeaponSlot.RIGHT_HAND:
		attachment = _weapon_attachment_r
		if _equipped_weapon_r:
			_equipped_weapon_r.queue_free()
			_equipped_weapon_r = null
	else:
		attachment = _weapon_attachment_l
		if _equipped_weapon_l:
			_equipped_weapon_l.queue_free()
			_equipped_weapon_l = null

	if not attachment:
		push_warning("Unit %s: no weapon attachment for slot %d" % [display_name, slot])
		return

	if weapon_scene_path.is_empty():
		return  # Desequipar (ya se hizo queue_free arriba)

	if not ResourceLoader.exists(weapon_scene_path):
		push_error("Unit: arma no encontrada: %s" % weapon_scene_path)
		return

	var scene: PackedScene = load(weapon_scene_path) as PackedScene
	if not scene:
		push_error("Unit: no se pudo cargar arma %s" % weapon_scene_path)
		return

	var weapon_inst: Node3D = scene.instantiate() as Node3D
	if not weapon_inst:
		push_error("Unit: instancia de arma no es Node3D: %s" % weapon_scene_path)
		return

	attachment.add_child(weapon_inst)
	weapon_inst.position = offset_pos
	weapon_inst.rotation = offset_rot

	if slot == WeaponSlot.RIGHT_HAND:
		_equipped_weapon_r = weapon_inst
	else:
		_equipped_weapon_l = weapon_inst
	print("[Unit] %s: arma equipada en %s → %s" % [display_name, "R" if slot == WeaponSlot.RIGHT_HAND else "L", weapon_scene_path.get_file()])


## Desequipa el arma del slot indicado.
func unequip_weapon(slot: WeaponSlot) -> void:
	equip_weapon(slot, "")


# ── WEAPON DATA (alto nivel) ──────────────────────────────

## Suma los bonuses de stats del arma al UnitStats runtime.
func _apply_weapon_stat_bonuses(weapon: WeaponData) -> void:
	if not weapon or not stats:
		return
	stats.physical_damage += weapon.bonus_physical_damage
	stats.magic_damage     += weapon.bonus_magic_damage
	stats.armor            += weapon.bonus_armor
	stats.magic_resist     += weapon.bonus_magic_resist
	stats.speed            += weapon.bonus_speed
	stats.evasion           = clampf(stats.evasion + weapon.bonus_evasion, 0.0, 1.0)
	stats.crit_chance       = clampf(stats.crit_chance + weapon.bonus_crit_chance, 0.0, 1.0)
	stats.notify_stats_changed()


## Resta los bonuses de stats del arma del UnitStats runtime.
func _remove_weapon_stat_bonuses(weapon: WeaponData) -> void:
	if not weapon or not stats:
		return
	stats.physical_damage = maxi(0, stats.physical_damage - weapon.bonus_physical_damage)
	stats.magic_damage     = maxi(0, stats.magic_damage - weapon.bonus_magic_damage)
	stats.armor            = maxi(0, stats.armor - weapon.bonus_armor)
	stats.magic_resist     = maxi(0, stats.magic_resist - weapon.bonus_magic_resist)
	stats.speed            = maxi(0, stats.speed - weapon.bonus_speed)
	stats.evasion           = clampf(stats.evasion - weapon.bonus_evasion, 0.0, 1.0)
	stats.crit_chance       = clampf(stats.crit_chance - weapon.bonus_crit_chance, 0.0, 1.0)
	stats.notify_stats_changed()


## Equipa un WeaponData en el slot indicado (RIGHT_HAND por defecto).
## Maneja automáticamente armas 2H (ocupan ambos slots, aplican bonuses una sola vez).
## Para 1H: si había un arma diferente en ese slot, quita sus bonuses y pone la nueva.
## Si venía de 2H, quita el bonus del arma 2H y libera el otro slot.
func equip_weapon_data(weapon_data: WeaponData, slot: WeaponSlot = WeaponSlot.RIGHT_HAND) -> void:
	if weapon_data == null:
		unequip_weapon_data(slot)
		return

	# ── ARMA 2H: ocupa ambos slots ──────────────────────────
	if weapon_data.slot == WeaponData.SlotMode.TWO_HANDED:
		# Quitar bonuses de lo que había en la derecha
		if _equipped_weapon_data_r != null:
			_remove_weapon_stat_bonuses(_equipped_weapon_data_r)
		# Quitar bonuses de la izquierda sólo si era un arma diferente (evita doble quita en 2H anterior)
		if _equipped_weapon_data_l != null and _equipped_weapon_data_l != _equipped_weapon_data_r:
			_remove_weapon_stat_bonuses(_equipped_weapon_data_l)
		_equipped_weapon_data_r = weapon_data
		_equipped_weapon_data_l = weapon_data  # referencia compartida → indica 2H
		_apply_weapon_stat_bonuses(weapon_data)
		if not weapon_data.scene_3d_path.is_empty():
			# visual_hand decide en qué mano aparece el modelo (0=derecha, 1=izquierda)
			var vis_slot: WeaponSlot = WeaponSlot.LEFT_HAND if weapon_data.get("visual_hand") == 1 else WeaponSlot.RIGHT_HAND
			var other_slot: WeaponSlot = WeaponSlot.RIGHT_HAND if vis_slot == WeaponSlot.LEFT_HAND else WeaponSlot.LEFT_HAND
			equip_weapon(vis_slot, weapon_data.scene_3d_path, weapon_data.hand_offset_pos, weapon_data.hand_offset_rot)
			unequip_weapon(other_slot)
		else:
			unequip_weapon(WeaponSlot.LEFT_HAND)
		print("[Unit] %s: equipó WeaponData 2H '%s'" % [display_name, weapon_data.display_name])
		return

	# ── ARMA 1H: sólo ocupa el slot indicado ────────────────
	var old_in_slot: WeaponData = _equipped_weapon_data_r if slot == WeaponSlot.RIGHT_HAND else _equipped_weapon_data_l
	var other_slot_weapon: WeaponData = _equipped_weapon_data_l if slot == WeaponSlot.RIGHT_HAND else _equipped_weapon_data_r

	if old_in_slot != null:
		if old_in_slot == other_slot_weapon:
			# Venía de 2H: quitar bonuses una sola vez y liberar el otro slot
			_remove_weapon_stat_bonuses(old_in_slot)
			if slot == WeaponSlot.RIGHT_HAND:
				_equipped_weapon_data_l = null
			else:
				_equipped_weapon_data_r = null
		else:
			# Arma 1H normal en ese slot
			_remove_weapon_stat_bonuses(old_in_slot)

	if slot == WeaponSlot.RIGHT_HAND:
		_equipped_weapon_data_r = weapon_data
	else:
		_equipped_weapon_data_l = weapon_data

	_apply_weapon_stat_bonuses(weapon_data)
	if not weapon_data.scene_3d_path.is_empty():
		equip_weapon(slot, weapon_data.scene_3d_path, weapon_data.hand_offset_pos, weapon_data.hand_offset_rot)
	print("[Unit] %s: equipó WeaponData 1H '%s' en %s" % [display_name, weapon_data.display_name,
		"derecha" if slot == WeaponSlot.RIGHT_HAND else "izquierda"])


## Desequipa el arma del slot indicado (RIGHT_HAND por defecto).
## Si es un arma 2H, libera ambos slots y quita el bonus una sola vez.
func unequip_weapon_data(slot: WeaponSlot = WeaponSlot.RIGHT_HAND) -> void:
	var weapon: WeaponData = _equipped_weapon_data_r if slot == WeaponSlot.RIGHT_HAND else _equipped_weapon_data_l
	if weapon == null:
		return
	if weapon.slot == WeaponData.SlotMode.TWO_HANDED:
		# 2H: quitar bonuses una vez, limpiar ambos slots y visuales
		_remove_weapon_stat_bonuses(weapon)
		_equipped_weapon_data_r = null
		_equipped_weapon_data_l = null
		unequip_weapon(WeaponSlot.RIGHT_HAND)
		unequip_weapon(WeaponSlot.LEFT_HAND)
	else:
		_remove_weapon_stat_bonuses(weapon)
		if slot == WeaponSlot.RIGHT_HAND:
			_equipped_weapon_data_r = null
		else:
			_equipped_weapon_data_l = null
		unequip_weapon(slot)
	print("[Unit] %s: desequipó arma de %s" % [display_name,
		"derecha (2H)" if weapon.slot == WeaponData.SlotMode.TWO_HANDED else
		("derecha" if slot == WeaponSlot.RIGHT_HAND else "izquierda")])


## Carga un GLB de rig (p. ej. Rig_Medium_General), reasigna las pistas al nodo bajo Visual
## y registra las animaciones en nuestro AnimationPlayer. anim_map: nombre_local -> nombre_en_glb.
func _setup_rig_animations(rig_glb_path: String, anim_map: Dictionary) -> void:
	var ap: AnimationPlayer = visual.get_node_or_null("AnimationPlayer")
	if not ap:
		return
	var rig_root: Node = null
	for c in visual.get_children():
		if c is AnimationPlayer:
			continue
		rig_root = c
		break
	if not rig_root:
		return
	var scene: PackedScene = load(rig_glb_path) as PackedScene
	if not scene:
		push_error("Unit: no se pudo cargar rig %s" % rig_glb_path)
		return
	var anim_source: Node = scene.instantiate()
	var source_ap: AnimationPlayer = _find_animation_player(anim_source)
	if not source_ap:
		anim_source.queue_free()
		return
	# No llamar get_animation_library("") si no existe: en Godot 4 puede fallar y devolver Ref inválida
	var list: PackedStringArray = ap.get_animation_library_list()
	if not list.has(""):
		ap.add_animation_library("", AnimationLibrary.new())
	var lib: AnimationLibrary = ap.get_animation_library("")
	if not lib:
		push_error("Unit: no se pudo obtener la biblioteca de animación por defecto")
		anim_source.queue_free()
		return
	var source_root_name := anim_source.name
	var target_root_name := rig_root.name
	for local_name in anim_map:
		var rig_anim_name: String = anim_map[local_name]
		if not source_ap.has_animation(rig_anim_name):
			continue
		var anim: Animation = source_ap.get_animation(rig_anim_name).duplicate()
		for i in range(anim.get_track_count()):
			var path: NodePath = anim.track_get_path(i)
			var path_str := str(path)
			var new_path: String
			if path_str.begins_with(source_root_name + "/"):
				new_path = target_root_name + path_str.substr(source_root_name.length())
			elif path_str == source_root_name:
				new_path = target_root_name
			else:
				new_path = target_root_name + "/" + path_str
			anim.track_set_path(i, NodePath(new_path))
		if local_name == "idle" or local_name == "walk":
			anim.loop_mode = Animation.LOOP_LINEAR
		lib.add_animation(local_name, anim)
	anim_source.queue_free()

func _find_animation_player(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n as AnimationPlayer
	for c in n.get_children():
		var ap := _find_animation_player(c)
		if ap:
			return ap
	return null

func _anim_name_for_state(s: AnimState) -> String:
	match s:
		AnimState.IDLE: return "idle"
		AnimState.SPAWN: return "spawn_air"
		AnimState.HIT: return "hit"
		AnimState.DEATH: return "death"
		AnimState.ATTACK: return "attack"
		AnimState.WALK: return "walk"
		_: return ""

## Máquina de estados de animación: transiciona al estado indicado y reproduce la animación correspondiente.
## Transiciones IDLE↔WALK usan cross-fade (blend) de 0.25s para suavidad.
func set_animation_state(s: AnimState) -> void:
	if s == AnimState.NONE:
		_stop_idle()
		_anim_state = AnimState.NONE
		return
	if not alive and s != AnimState.DEATH:
		return
	if _anim_state == s and s == AnimState.IDLE:
		return

	var prev_state: AnimState = _anim_state
	var ap: AnimationPlayer = _get_anim_ap()
	var anim_name := _anim_name_for_state(s)
	if ap and anim_name != "" and ap.has_animation(anim_name):
		# Blend suave para transiciones IDLE↔WALK; instantáneo para el resto
		var use_blend: bool = (
			(prev_state == AnimState.IDLE and s == AnimState.WALK) or
			(prev_state == AnimState.WALK and s == AnimState.IDLE)
		)
		_stop_idle_tween()  # Matar tween de breathing/bounce, sin parar AnimationPlayer
		_anim_state = s
		if use_blend:
			ap.play(anim_name, 0.25)  # Cross-fade 0.25s
		else:
			ap.play(anim_name)
	elif s == AnimState.WALK:
		# Fallback: bounce vertical simulando caminar
		_stop_idle()
		_anim_state = AnimState.WALK
		_idle_tween = create_tween()
		_idle_tween.set_loops()
		_idle_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_idle_tween.tween_property(visual, "position:y", 0.08, 0.15)
		_idle_tween.tween_property(visual, "position:y", 0.0, 0.15)
	elif s == AnimState.SPAWN:
		set_animation_state(AnimState.IDLE)
	elif s == AnimState.IDLE:
		_stop_idle()
		if not alive:
			return
		_anim_state = AnimState.IDLE
		_idle_tween = create_tween()
		_idle_tween.set_loops()
		_idle_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_idle_tween.tween_property(visual, "scale", Vector3(1.04, 0.98, 1.04), 0.6)
		_idle_tween.tween_property(visual, "scale", Vector3.ONE, 0.6)

func play_idle() -> void:
	set_animation_state(AnimState.IDLE)

## Detiene solo el tween de breathing/bounce, sin tocar el AnimationPlayer.
## Usado para transiciones con blend donde el AP necesita seguir corriendo.
func _stop_idle_tween() -> void:
	if _idle_tween and _idle_tween.is_running():
		_idle_tween.kill()
	_idle_tween = null
	visual.scale = Vector3.ONE
	visual.position.y = 0.0


func _stop_idle() -> void:
	_stop_idle_tween()
	var ap: AnimationPlayer = _get_anim_ap()
	if ap and ap.is_playing():
		ap.stop()

func _on_animation_finished(_anim_name: StringName) -> void:
	if _anim_state == AnimState.SPAWN or _anim_state == AnimState.HIT or _anim_state == AnimState.ATTACK:
		set_animation_state(AnimState.IDLE)

## Cura HP respetando el efecto ENFERMEDAD (bloquea curación).
## Usar este método en vez de stats.heal() para que ENFERMEDAD funcione.
func curar_hp(cantidad: int) -> void:
	if efectos_manager and efectos_manager.tiene_efecto(StatusEffect.Tipo.ENFERMEDAD):
		show_floating_text("🤢 ¡No puede curarse!", Color(0.6, 0.75, 0.1))
		return
	if stats:
		stats.heal(cantidad)


## Aplica un efecto de estado a esta unidad (wrapper de conveniencia).
## Devuelve true si se aplicó, false si fue bloqueado por inmunidad.
func aplicar_efecto_estado(tipo: StatusEffect.Tipo, duracion: int, potencia: int = 0, fuente = null) -> bool:
	if not efectos_manager:
		return false
	var efecto := StatusEffect.new(tipo, duracion, potencia, fuente)
	return efectos_manager.aplicar_efecto(efecto)


func take_damage(amount: int) -> void:
	take_damage_split(amount, 0)

## Aplica daño físico y mágico ya reducido por armadura y resistencia mágica.
func take_damage_split(physical: int, magic: int) -> void:
	if not alive or not stats:
		return
	stats.apply_damage_direct(physical, magic)
	if stats.hp <= 0:
		die()
	else:
		_play_hurt_fx()
		set_animation_state(AnimState.HIT)

func die() -> void:
	if not alive:
		return
	print("[Unit] %s: murio" % display_name)
	alive = false
	if efectos_manager:
		efectos_manager.limpiar_todos()
	set_selected(false)
	collider.disabled = true
	set_physics_process(false)
	velocity = Vector3.ZERO
	_stop_idle()

	var ap: AnimationPlayer = _get_anim_ap()
	if ap and ap.has_animation("death"):
		set_animation_state(AnimState.DEATH)
		await ap.animation_finished
	else:
		var t := create_tween()
		t.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
		t.tween_property(visual, "scale", Vector3(1.1, 1.1, 1.1), 0.12)
		t.tween_property(visual, "scale", Vector3.ZERO, 0.38)
		t.parallel().tween_property(self, "position:y", position.y - 0.35, 0.5)
		await t.finished

	emit_signal("died", self)

func _play_hurt_fx() -> void:
	# Flash + small shake.
	var t := create_tween()
	t.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	for m in _mesh_materials:
		if m is StandardMaterial3D:
			t.parallel().tween_property(m, "albedo_color", Color(1, 0.35, 0.35, 1), 0.08)
	t.parallel().tween_property(visual, "position:x", visual.position.x + 0.06, 0.06)
	t.tween_property(visual, "position:x", visual.position.x - 0.06, 0.06)
	for m in _mesh_materials:
		if m is StandardMaterial3D:
			t.parallel().tween_property(m, "albedo_color", _base_color, 0.12)

func _face_target(target_pos: Vector3) -> void:
	var flat := target_pos
	flat.y = global_position.y
	look_at(flat, Vector3.UP)

func _approach_position(target: Unit) -> Vector3:
	var dir := target.global_position - global_position
	dir.y = 0.0
	if dir.length() < 0.001:
		dir = Vector3.FORWARD
	dir = dir.normalized()
	var p := target.global_position - dir * stop_distance
	p.y = global_position.y
	return p

## Mueve la unidad al tile destino con animación de caminar.
func move_to_tile(target_pos: Vector3) -> void:
	if not alive:
		return
	var dest := target_pos + Vector3(0, 0.1, 0)
	_face_target(dest)

	# Intentar animación walk
	set_animation_state(AnimState.WALK)

	var move_tween := create_tween()
	move_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	var distance: float = global_position.distance_to(dest)
	var duration: float = clampf(distance / 3.0, 0.3, 1.5)
	move_tween.tween_property(self, "global_position", dest, duration)
	await move_tween.finished

	set_animation_state(AnimState.IDLE)


func attack_target(target: Unit, ability_index: int = 0) -> void:
	# Async action: approach (melee) o stay (ranged) -> attack anim -> resolve -> return.
	if not alive or not target or not target.alive:
		return

	set_animation_state(AnimState.NONE)
	set_selected(false)

	# Guardar el último enemigo atacado (para facing post-movimiento)
	_last_attacked_unit = target

	var ab: Dictionary = Unit.get_ability(self, ability_index)
	var is_melee: bool = ab.get("range", 99) <= 1
	var start_pos := global_position
	var start_rot := global_rotation

	_face_target(target.global_position)

	if is_melee:
		# Melee: acercarse al enemigo con animación de caminar
		var approach := _approach_position(target)
		var approach_dist: float = global_position.distance_to(approach)
		var approach_dur: float = clampf(approach_dist / 4.0, 0.25, 1.0)
		set_animation_state(AnimState.WALK)
		var t_move := create_tween()
		t_move.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t_move.tween_property(self, "global_position", approach, approach_dur)
		await t_move.finished
		set_animation_state(AnimState.NONE)

	# El daño se aplica internamente en _play_attack_animation:
	# - Melee: a ~55% de la animación (cuando el arma conecta)
	# - Arco: al impacto del proyectil (antes de que Release termine)
	await _play_attack_animation(ability_index, target)

	if is_melee:
		# Volver a posición original con animación de caminar
		_face_target(start_pos)
		var return_dist: float = global_position.distance_to(start_pos)
		var return_dur: float = clampf(return_dist / 4.0, 0.25, 1.0)
		set_animation_state(AnimState.WALK)
		var t_back := create_tween()
		t_back.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
		t_back.tween_property(self, "global_position", start_pos, return_dur)
		await t_back.finished

	# Restore original rotation por el camino más corto (evita giro de 360° por Euler ±PI).
	var current_y := global_rotation.y
	var target_y := current_y + wrapf(start_rot.y - current_y, -PI, PI)
	var final_rot := Vector3(start_rot.x, target_y, start_rot.z)
	var t_rot := create_tween()
	t_rot.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t_rot.tween_property(self, "global_rotation", final_rot, 0.18)
	await t_rot.finished

	set_animation_state(AnimState.IDLE)


## Ataque de area: reproduce animación de disparo al cielo, efecto de lluvia de flechas,
## y resuelve daño en cada unidad afectada dentro de la zona.
func attack_area(center_world: Vector3, affected_units: Array[Unit], ability_index: int = 0) -> void:
	if not alive:
		return

	set_animation_state(AnimState.NONE)
	set_selected(false)

	var ab: Dictionary = Unit.get_ability(self, ability_index)
	var start_rot := global_rotation

	# Mirar hacia el centro del area AoE
	_face_target(center_world)

	# Reproducir animación de disparo hacia arriba (Draw Up → Release Up, sin proyectil individual)
	await _play_bow_attack_aoe(ab.get("anim_name", "ranged_bow_draw_up"))

	# Efecto visual: lluvia de flechas + daño al impacto (antes del linger visual)
	var aoe_radius: int = ab.get("aoe_radius", 2)
	await _launch_arrow_rain(center_world, aoe_radius, affected_units, ability_index)

	# Restaurar rotación original
	var current_y := global_rotation.y
	var target_y := current_y + wrapf(start_rot.y - current_y, -PI, PI)
	var final_rot := Vector3(start_rot.x, target_y, start_rot.z)
	var t_rot := create_tween()
	t_rot.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t_rot.tween_property(self, "global_rotation", final_rot, 0.18)
	await t_rot.finished

	set_animation_state(AnimState.IDLE)


func _resolve_attack_damage(target: Unit, ability_index: int) -> void:
	if not stats or not target.stats:
		return
	var ab: Dictionary = Unit.get_ability(self, ability_index)
	# Bloqueo activo: anula el golpe y consume el bloqueo
	if target._blocking:
		target._blocking = false
		target.show_floating_text("¡Bloqueado!", Color(0.3, 0.7, 1.0))
		target.play_dodge_animation(global_position)  # Reacción visual de bloqueo
		# Registrar: atacante falló (bloqueado), defensor bloqueó
		stats.battle_misses += 1
		target.stats.battle_blocks += 1
		return
	var effective_evasion: float = target.stats.evasion + _qte_evasion_bonus
	if randf() < effective_evasion:
		target.play_dodge_animation(global_position)
		target.show_floating_text("Esquive", Color.YELLOW)
		# Registrar: atacante falló (esquivado), defensor esquivó
		stats.battle_misses += 1
		target.stats.battle_evades += 1
		return
	# ── ELECTROCUTADO: penalización drástica al hit_chance del atacante ──
	var penalizacion_elec: float = 0.0
	if efectos_manager and efectos_manager.tiene_efecto(StatusEffect.Tipo.ELECTROCUTADO):
		var eff_elec: StatusEffect = efectos_manager.obtener_efecto(StatusEffect.Tipo.ELECTROCUTADO)
		if eff_elec:
			penalizacion_elec = eff_elec.potencia / 100.0
	var effective_hit: float = ab.get("hit_chance", 1.0) + _qte_hit_bonus - penalizacion_elec
	if randf() > effective_hit:
		target.show_floating_text("Falló", Color(0.55, 0.55, 0.55))
		# Registrar: atacante falló
		stats.battle_misses += 1
		return
	var effective_crit: float = stats.crit_chance + _qte_crit_bonus
	var crit_mult: float = 2.0 if randf() < effective_crit else 1.0
	var phys: int = int((stats.physical_damage + ab.get("physical", 0)) * crit_mult)
	var mag: int = int((stats.magic_damage + ab.get("magic", 0)) * crit_mult)
	var phys_taken: int = max(0, phys - target.stats.armor)
	var magic_taken: int = max(0, mag - target.stats.magic_resist)
	var phys_blocked: int = phys - phys_taken
	var magic_blocked: int = mag - magic_taken
	var total_dealt: int = phys_taken + magic_taken

	# Registrar estadísticas acumuladas del atacante
	stats.battle_hits += 1
	stats.battle_damage_dealt += total_dealt
	if crit_mult >= 2.0:
		stats.battle_crits += 1
	# Registrar estadísticas del defensor
	target.stats.battle_damage_taken += total_dealt
	# Kill: se registrará si muere por este golpe
	if target.stats.hp - total_dealt <= 0:
		stats.battle_kills += 1

	var v_offset: float = 0.0
	var line_height: float = 0.4
	var delay_step: float = 0.14
	var popup_delay: float = 0.0
	if crit_mult >= 2.0:
		target.show_floating_text("¡Crítico!", Color(1.0, 0.55, 0.0), v_offset, popup_delay)
		v_offset += line_height
		popup_delay += delay_step
	if phys_taken > 0:
		target.show_floating_text("-%d" % phys_taken, Color(1.0, 0.25, 0.25), v_offset, popup_delay)
		v_offset += line_height
		popup_delay += delay_step
	if magic_taken > 0:
		target.show_floating_text("-%d" % magic_taken, Color(0.75, 0.35, 1.0), v_offset, popup_delay)
		v_offset += line_height
		popup_delay += delay_step
	if phys_blocked > 0:
		target.show_floating_text("Armadura %d" % phys_blocked, Color(0.25, 0.5, 1.0), v_offset, popup_delay)
		v_offset += line_height
		popup_delay += delay_step
	if magic_blocked > 0:
		target.show_floating_text("Resist. %d" % magic_blocked, Color(0.2, 0.75, 1.0), v_offset, popup_delay)

	target.take_damage_split(phys_taken, magic_taken)

	# ── ESPINAS: refleja daño fijo al atacante cuando el target tiene espinas ──
	if target.efectos_manager and target.efectos_manager.tiene_efecto(StatusEffect.Tipo.ESPINAS):
		var esp: StatusEffect = target.efectos_manager.obtener_efecto(StatusEffect.Tipo.ESPINAS)
		if esp and esp.potencia > 0 and total_dealt > 0:
			show_floating_text("🌵 -%d" % esp.potencia, Color(0.4, 0.7, 0.2))
			take_damage_split(esp.potencia, 0)

	# ── ESPEJO: refleja 100% del daño recibido al atacante ──
	if target.efectos_manager and target.efectos_manager.tiene_efecto(StatusEffect.Tipo.ESPEJO):
		if total_dealt > 0:
			show_floating_text("🪞 -%d" % total_dealt, Color(0.7, 0.85, 1.0))
			take_damage_split(total_dealt, 0)

	# ── Aplicar efectos de estado de la habilidad del arma ──
	for efecto_dict in ab.get("status_effects", []):
		var chance: float = efecto_dict.get("probabilidad", 1.0)
		if randf() < chance:
			target.aplicar_efecto_estado(
				efecto_dict.get("tipo", 0) as StatusEffect.Tipo,
				efecto_dict.get("duracion", 2),
				efecto_dict.get("potencia", 0),
				self)

## Muestra un popup flotante sobre la unidad (esquive, daño, bloqueos, etc.).
## delay_sec: segundos antes de mostrar este popup (para escalonar múltiples popups).
func show_floating_text(text: String, text_color: Color, vertical_offset: float = 0.0, delay_sec: float = 0.0) -> void:
	if delay_sec > 0.0:
		await get_tree().create_timer(delay_sec).timeout
	if not is_instance_valid(self):
		return
	_spawn_one_floating_text(text, text_color, vertical_offset)

func _spawn_one_floating_text(text: String, text_color: Color, vertical_offset: float) -> void:
	var parent: Node = get_parent()
	if parent == null or not is_instance_valid(self):
		return
	var label: Label3D = Label3D.new()
	label.text = text
	label.modulate = text_color
	label.font_size = 16
	label.outline_size = 4
	label.outline_modulate = Color(0.0, 0.0, 0.0, 0.9)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.fixed_size = true
	label.no_depth_test = true
	parent.add_child(label)
	label.global_position = global_position + Vector3(0.0, 1.45 + vertical_offset, 0.0)

	var duration: float = 0.85
	var start_y: float = label.global_position.y
	var end_y: float = start_y + 0.7
	var start_mod: Color = text_color
	var end_mod: Color = Color(start_mod.r, start_mod.g, start_mod.b, 0.0)

	var t := create_tween()
	t.set_parallel(true)
	t.tween_method(func(v: float) -> void: label.global_position.y = lerpf(start_y, end_y, v), 0.0, 1.0, duration)
	t.tween_method(func(v: float) -> void: label.modulate = start_mod.lerp(end_mod, v), 0.0, 1.0, duration)
	t.set_parallel(false)
	t.tween_callback(label.queue_free)

## Reproduce la animación de ataque para el ability_index.
## Lee anim_name de la habilidad del arma equipada; fallback a "attack" (Interact genérico).
## Si es un ataque de arco (ranged_bow_draw*), encadena Draw→Release y lanza proyectil.
func _play_attack_animation(ability_index: int = 0, target: Unit = null) -> void:
	var ab: Dictionary = Unit.get_ability(self, ability_index)
	var anim_name: String = ab.get("anim_name", "attack")

	# Flujo especial para arco: Draw → proyectil → Release encadenados
	# El daño se aplica dentro de _play_bow_attack al momento del impacto del proyectil
	if anim_name.begins_with("ranged_bow_draw") and target != null:
		await _play_bow_attack(anim_name, target, ability_index)
		return

	# Flujo genérico (una sola animación) — daño a ~55% de la animación
	var ap: AnimationPlayer = _get_anim_ap()
	if not ap:
		await _fallback_attack_tween()
		if target != null and is_instance_valid(target) and target.alive:
			_resolve_attack_damage(target, ability_index)
		return
	if not ap.has_animation(anim_name):
		anim_name = "attack"
	if ap.has_animation(anim_name):
		_stop_idle()
		_anim_state = AnimState.ATTACK
		var anim_len: float = ap.get_animation(anim_name).length
		ap.play(anim_name)
		# Aplicar daño a mitad de la animación (cuando el arma conecta visualmente)
		if target != null:
			get_tree().create_timer(anim_len * 0.55).timeout.connect(func() -> void:
				if is_instance_valid(self) and is_instance_valid(target) and target.alive:
					_resolve_attack_damage(target, ability_index), CONNECT_ONE_SHOT)
		await ap.animation_finished
	else:
		await _fallback_attack_tween()
		if target != null and is_instance_valid(target) and target.alive:
			_resolve_attack_damage(target, ability_index)


## Devuelve el MeshInstance3D del arco equipado (mano que corresponda a visual_hand).
## Usado para animar el blend shape "Draw" de la cuerda.
func _get_bow_mesh() -> MeshInstance3D:
	# El arco 2H puede estar en mano izquierda o derecha según visual_hand
	var bow_root: Node3D = null
	var weapon_data: WeaponData = _equipped_weapon_data_r
	if weapon_data and weapon_data.get("visual_hand") == 1:
		bow_root = _equipped_weapon_l
	else:
		bow_root = _equipped_weapon_r
	if not is_instance_valid(bow_root):
		return null
	# El MeshInstance3D puede ser el propio nodo o un hijo (depende del GLTF)
	if bow_root is MeshInstance3D:
		return bow_root as MeshInstance3D
	return bow_root.find_child("*", true, false) as MeshInstance3D


## Reproduce animación de bloqueo con tween del escudo desde (0,0,0) hasta los offsets.
## Al terminar la animación, el escudo regresa suavemente a (0,0,0).
## Usado por battle_flow y weapon_preview para mantener una sola implementación.
func play_block_animation(anim_name: String, block_pos: Vector3, block_rot: Vector3) -> void:
	var ap: AnimationPlayer = _get_anim_ap()
	if not ap or not ap.has_animation(anim_name):
		return

	# Buscar el nodo del escudo (izquierda primero, luego derecha)
	var shield_node: Node3D = _equipped_weapon_l if is_instance_valid(_equipped_weapon_l) else _equipped_weapon_r

	# Tween de subida: 0.2s lineal hacia la posición de guardia
	if is_instance_valid(shield_node):
		shield_node.position = Vector3.ZERO
		shield_node.rotation = Vector3.ZERO
		var tw := create_tween()
		tw.set_parallel(true)
		tw.set_trans(Tween.TRANS_LINEAR)
		tw.tween_property(shield_node, "position", block_pos, 0.2)
		tw.tween_property(shield_node, "rotation", block_rot, 0.2)

	_stop_idle()
	_anim_state = AnimState.ATTACK
	ap.play(anim_name)
	await ap.animation_finished

	# Tween de regreso: 0.2s lineal de vuelta a (0,0,0)
	if is_instance_valid(shield_node):
		var tw_back := create_tween()
		tw_back.set_parallel(true)
		tw_back.set_trans(Tween.TRANS_LINEAR)
		tw_back.tween_property(shield_node, "position", Vector3.ZERO, 0.2)
		tw_back.tween_property(shield_node, "rotation", Vector3.ZERO, 0.2)
		await tw_back.finished


## Encadena Draw → Release y lanza el proyectil al inicio del Release.
## Aplica daño al momento del impacto del proyectil (no al terminar Release).
## Anima el blend shape "Draw" del arco: 0→1 durante Draw, 1→0 durante Release.
func _play_bow_attack(draw_anim: String, target: Unit, ability_index: int = 0) -> void:
	var ap: AnimationPlayer = _get_anim_ap()
	if not ap:
		await _fallback_attack_tween()
		return

	# Derivar el nombre de Release desde Draw (ranged_bow_draw → ranged_bow_release)
	var release_anim: String = draw_anim.replace("_draw", "_release")

	# Buscar el MeshInstance3D del arco para animar la cuerda (blend shape "Draw")
	var bow_mesh: MeshInstance3D = _get_bow_mesh()
	var has_string_bs: bool = bow_mesh != null and bow_mesh.find_blend_shape_by_name("Draw") >= 0
	var bs_idx: int = -1
	if has_string_bs:
		bs_idx = bow_mesh.find_blend_shape_by_name("Draw")

	# 1. Draw: tensar la cuerda (blend shape 0 → 1 mientras dura la animación)
	_stop_idle()
	_anim_state = AnimState.ATTACK
	if ap.has_animation(draw_anim):
		var draw_len: float = ap.get_animation(draw_anim).length
		# Animar cuerda en paralelo con la animación del personaje
		if bs_idx >= 0:
			bow_mesh.set_blend_shape_value(bs_idx, 0.0)
			var t_draw := create_tween()
			t_draw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			t_draw.tween_method(func(v: float) -> void:
				if is_instance_valid(bow_mesh):
					bow_mesh.set_blend_shape_value(bs_idx, v),
				0.0, 1.0, draw_len)
		ap.play(draw_anim)
		await ap.animation_finished

	# 2. Release + proyectil en paralelo (el proyectil controla el timing del await)
	var use_bundle: bool = draw_anim.ends_with("_up")
	if ap.has_animation(release_anim):
		var release_len: float = ap.get_animation(release_anim).length
		# Aflojar la cuerda: blend shape 1 → 0 durante Release
		if bs_idx >= 0:
			var t_release := create_tween()
			t_release.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			t_release.tween_method(func(v: float) -> void:
				if is_instance_valid(bow_mesh):
					bow_mesh.set_blend_shape_value(bs_idx, v),
				1.0, 0.0, release_len)
		ap.play(release_anim)
		# Lanzar proyectil y esperar a que llegue
		await _launch_arrow_projectile(target, use_bundle)
		# Aplicar daño al impacto (antes de esperar que Release termine)
		_resolve_attack_damage(target, ability_index)
		# Release puede seguir visualmente mientras el target reacciona
		if ap.is_playing():
			await ap.animation_finished
	else:
		# Sin animación de release: soltar la cuerda rápido
		if bs_idx >= 0:
			var t_snap := create_tween()
			t_snap.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			t_snap.tween_method(func(v: float) -> void:
				if is_instance_valid(bow_mesh):
					bow_mesh.set_blend_shape_value(bs_idx, v),
				1.0, 0.0, 0.2)
		await _launch_arrow_projectile(target, use_bundle)
		_resolve_attack_damage(target, ability_index)


## Variante AoE de _play_bow_attack: reproduce Draw Up → Release Up con cuerda animada,
## pero NO lanza proyectil individual (el efecto visual es la lluvia de flechas posterior).
func _play_bow_attack_aoe(draw_anim: String) -> void:
	var ap: AnimationPlayer = _get_anim_ap()
	if not ap:
		await _fallback_attack_tween()
		return

	var release_anim: String = draw_anim.replace("_draw", "_release")

	# Buscar blend shape "Draw" del arco para animar la cuerda
	var bow_mesh: MeshInstance3D = _get_bow_mesh()
	var bs_idx: int = -1
	if bow_mesh:
		bs_idx = bow_mesh.find_blend_shape_by_name("Draw")

	# 1. Draw: tensar la cuerda
	_stop_idle()
	_anim_state = AnimState.ATTACK
	if ap.has_animation(draw_anim):
		var draw_len: float = ap.get_animation(draw_anim).length
		if bs_idx >= 0:
			bow_mesh.set_blend_shape_value(bs_idx, 0.0)
			var t_draw := create_tween()
			t_draw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			t_draw.tween_method(func(v: float) -> void:
				if is_instance_valid(bow_mesh):
					bow_mesh.set_blend_shape_value(bs_idx, v),
				0.0, 1.0, draw_len)
		ap.play(draw_anim)
		await ap.animation_finished

	# 2. Release (sin proyectil individual)
	if ap.has_animation(release_anim):
		var release_len: float = ap.get_animation(release_anim).length
		if bs_idx >= 0:
			var t_release := create_tween()
			t_release.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			t_release.tween_method(func(v: float) -> void:
				if is_instance_valid(bow_mesh):
					bow_mesh.set_blend_shape_value(bs_idx, v),
				1.0, 0.0, release_len)
		ap.play(release_anim)
		await ap.animation_finished
	else:
		# Sin animación de release: soltar la cuerda rápido
		if bs_idx >= 0:
			var t_snap := create_tween()
			t_snap.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			t_snap.tween_method(func(v: float) -> void:
				if is_instance_valid(bow_mesh):
					bow_mesh.set_blend_shape_value(bs_idx, v),
				1.0, 0.0, 0.2)
			await t_snap.finished


## Efecto visual de lluvia de flechas: spawn múltiples flechas individuales (arrow_bow.gltf)
## que caen desde lo alto sobre el area AoE. Aplica daño al impacto (antes del linger).
func _launch_arrow_rain(center_world: Vector3, aoe_radius: int = 2,
		affected_units: Array[Unit] = [], ability_index: int = 0) -> void:
	# Determinar el asset de flecha individual (NO bundle)
	var weapon: WeaponData = _equipped_weapon_data_r
	var arrow_path: String = ""
	if weapon and not weapon.projectile_scene_path.is_empty():
		arrow_path = weapon.projectile_scene_path
	if arrow_path.is_empty():
		arrow_path = "res://assets/KayKit_Adventurers_2.0_FREE/Assets/gltf/arrow_bow.gltf"

	if not ResourceLoader.exists(arrow_path):
		await get_tree().create_timer(0.6).timeout
		return

	var arrow_scene: PackedScene = load(arrow_path) as PackedScene
	if not arrow_scene:
		await get_tree().create_timer(0.6).timeout
		return

	var scene_root: Node = get_parent()
	if not scene_root:
		return

	# Parámetros de la lluvia
	var spread: float = aoe_radius * 2.0 + 1.0
	var arrow_count: int = randi_range(10, 15)
	var spawn_height: float = 9.0
	var land_height: float = 0.1
	var stagger_delay: float = 0.05
	var fall_duration: float = 0.35
	var linger_time: float = 0.6

	var arrows: Array[Node3D] = []

	for i in range(arrow_count):
		var arrow: Node3D = arrow_scene.instantiate() as Node3D
		if not arrow:
			continue
		scene_root.add_child(arrow)
		arrows.append(arrow)

		# Posición de aterrizaje: random dentro del area AoE
		var offset_x: float = randf_range(-spread * 0.5, spread * 0.5)
		var offset_z: float = randf_range(-spread * 0.5, spread * 0.5)
		var land_pos := Vector3(
			center_world.x + offset_x,
			land_height,
			center_world.z + offset_z
		)

		# Posición de inicio: directamente arriba con pequeño offset aleatorio
		var start_pos := Vector3(
			land_pos.x + randf_range(-0.3, 0.3),
			spawn_height + randf_range(0.0, 2.0),
			land_pos.z + randf_range(-0.3, 0.3)
		)

		arrow.global_position = start_pos

		# Orientar la flecha apuntando hacia abajo (punta primero)
		arrow.rotation = Vector3(PI / 2.0, randf_range(-0.3, 0.3), randf_range(-0.2, 0.2))

		# Tween de caída escalonada
		var t := arrow.create_tween()
		t.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		if i > 0:
			t.tween_interval(i * stagger_delay)
		t.tween_property(arrow, "global_position", land_pos, fall_duration)

	# Esperar a que todas las flechas terminen de caer
	var total_rain_time: float = float(arrow_count - 1) * stagger_delay + fall_duration
	await get_tree().create_timer(total_rain_time + 0.05).timeout

	# Aplicar daño al impacto (las flechas ya llegaron al suelo)
	for target in affected_units:
		if is_instance_valid(target) and target.alive:
			_resolve_attack_damage(target, ability_index)

	# Las flechas quedan "clavadas" un momento mientras se muestran los floating text
	await get_tree().create_timer(linger_time).timeout

	# Limpiar todas las flechas
	for arrow in arrows:
		if is_instance_valid(arrow):
			arrow.queue_free()


## Instancia una flecha 3D en la mano del arquero y la mueve hacia el objetivo.
## Retorna cuando la flecha llega (await), para sincronizar la aplicación del daño.
func _launch_arrow_projectile(target: Unit, use_bundle: bool = false) -> void:
	if not is_instance_valid(target):
		return

	# Determinar el asset de flecha desde el WeaponData equipado
	var weapon: WeaponData = _equipped_weapon_data_r
	var arrow_path: String = ""
	if weapon:
		if use_bundle and not weapon.projectile_bundle_path.is_empty():
			arrow_path = weapon.projectile_bundle_path
		elif not weapon.projectile_scene_path.is_empty():
			arrow_path = weapon.projectile_scene_path

	# Fallback genérico si no hay path en WeaponData
	if arrow_path.is_empty():
		arrow_path = "res://assets/KayKit_Adventurers_2.0_FREE/Assets/gltf/arrow_bow.gltf"

	if not ResourceLoader.exists(arrow_path):
		# Sin asset: esperar un tiempo fijo simulando el vuelo
		await get_tree().create_timer(0.35).timeout
		return

	var arrow_scene: PackedScene = load(arrow_path) as PackedScene
	if not arrow_scene:
		await get_tree().create_timer(0.35).timeout
		return

	var arrow: Node3D = arrow_scene.instantiate() as Node3D
	if not arrow:
		await get_tree().create_timer(0.35).timeout
		return

	# Añadir al nivel de la escena (no como hijo de la unidad, para que vuele libre)
	var scene_root: Node = get_parent()
	if not scene_root:
		arrow.queue_free()
		return
	scene_root.add_child(arrow)

	# Posición de inicio: punto de anclaje del arma en la mano derecha
	var start_pos: Vector3 = global_position + Vector3(0.0, 1.2, 0.0)
	if _weapon_attachment_r and is_instance_valid(_weapon_attachment_r):
		start_pos = _weapon_attachment_r.global_position

	# Posición destino: torso del objetivo
	var end_pos: Vector3 = target.global_position + Vector3(0.0, 1.0, 0.0)

	arrow.global_position = start_pos

	# Orientar la flecha hacia el destino
	if start_pos.distance_squared_to(end_pos) > 0.001:
		arrow.look_at(end_pos, Vector3.UP)

	# Tiempo de vuelo proporcional a la distancia (entre 0.15 y 0.55 segundos)
	var dist: float = start_pos.distance_to(end_pos)
	var flight_time: float = clampf(dist * 0.07, 0.15, 0.55)

	var t := arrow.create_tween()
	t.set_trans(Tween.TRANS_LINEAR)
	t.tween_property(arrow, "global_position", end_pos, flight_time)
	await t.finished

	if is_instance_valid(arrow):
		arrow.queue_free()


## Fallback visual: squash + flash para unidades sin animación de ataque.
func _fallback_attack_tween() -> void:
	var t := create_tween()
	t.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(visual, "scale", Vector3(1.12, 0.88, 1.12), 0.12)
	t.tween_property(visual, "scale", Vector3.ONE, 0.12)
	for m in _mesh_materials:
		if m is StandardMaterial3D:
			t.parallel().tween_property(m, "albedo_color", _base_color.lightened(0.25), 0.10)
			t.parallel().tween_property(m, "albedo_color", _base_color, 0.20)
	await t.finished


## Devuelve el objetivo al que mirar tras moverse:
## el último atacado si sigue vivo, sino el enemigo más cercano de la lista.
func get_facing_target_after_move(opponents: Array) -> Unit:
	if _last_attacked_unit and is_instance_valid(_last_attacked_unit) and _last_attacked_unit.alive:
		return _last_attacked_unit
	var nearest: Unit = null
	var min_dist: float = INF
	for u in opponents:
		if u is Unit and (u as Unit).alive:
			var d: float = global_position.distance_squared_to((u as Unit).global_position)
			if d < min_dist:
				min_dist = d
				nearest = u as Unit
	return nearest


# ── QTE: SLOW MOTION / DODGE / MODIFIERS ───────────────────

## Ralentiza la animación del AnimationPlayer (para QTE slow-motion).
func start_attack_slow_motion() -> void:
	var ap: AnimationPlayer = _get_anim_ap()
	if ap:
		ap.speed_scale = 0.15


## Restaura la velocidad normal de la animación.
func restore_animation_speed() -> void:
	var ap: AnimationPlayer = _get_anim_ap()
	if ap:
		ap.speed_scale = 1.0


## Limpia los modificadores QTE después de cada ataque.
func reset_qte_modifiers() -> void:
	_qte_hit_bonus = 0.0
	_qte_crit_bonus = 0.0
	_qte_evasion_bonus = 0.0


## Reproduce una animación de dodge direccional (fire-and-forget, no bloquea el flujo).
## Elige dodge_backward/forward/left/right según la posición del atacante.
## Al terminar la animación vuelve automáticamente a idle.
func play_dodge_animation(attacker_pos: Vector3) -> void:
	var ap: AnimationPlayer = _get_anim_ap()
	if not ap:
		return
	# Determinar dirección relativa del atacante
	var to_attacker: Vector3 = (attacker_pos - global_position).normalized()
	var forward_dir: Vector3 = -global_transform.basis.z.normalized()
	var dot: float = forward_dir.dot(to_attacker)
	var cross_y: float = forward_dir.cross(to_attacker).y

	var dodge_name: String = "dodge_backward"
	if dot < -0.5:
		dodge_name = "dodge_forward"
	elif abs(cross_y) > 0.5:
		dodge_name = "dodge_left" if cross_y > 0 else "dodge_right"

	# Marcar _anim_state como HIT para que _on_animation_finished vuelva a IDLE al terminar
	if ap.has_animation(dodge_name):
		_stop_idle()
		_anim_state = AnimState.HIT
		ap.play(dodge_name)
	elif ap.has_animation("dodge_backward"):
		_stop_idle()
		_anim_state = AnimState.HIT
		ap.play("dodge_backward")
