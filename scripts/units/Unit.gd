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


## Crea los BoneAttachment3D en handslot.r y handslot.l del esqueleto.
## Llamado desde _ready(), después de que el GLB ya está instanciado.
func _setup_weapon_slots() -> void:
	_skeleton = _find_skeleton_recursive(visual)
	if not _skeleton:
		return

	var bone_r := _skeleton.find_bone("handslot.r")
	var bone_l := _skeleton.find_bone("handslot.l")

	if bone_r >= 0:
		_weapon_attachment_r = BoneAttachment3D.new()
		_weapon_attachment_r.bone_name = "handslot.r"
		_skeleton.add_child(_weapon_attachment_r)

	if bone_l >= 0:
		_weapon_attachment_l = BoneAttachment3D.new()
		_weapon_attachment_l.bone_name = "handslot.l"
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
			equip_weapon(WeaponSlot.RIGHT_HAND, weapon_data.scene_3d_path, weapon_data.hand_offset_pos, weapon_data.hand_offset_rot)
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
		# Melee: acercarse al enemigo
		var approach := _approach_position(target)
		var t_move := create_tween()
		t_move.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t_move.tween_property(self, "global_position", approach, 0.35)
		await t_move.finished

	await _play_attack_animation(ability_index)

	_resolve_attack_damage(target, ability_index)

	if is_melee:
		# Solo volver si se acercó
		var t_back := create_tween()
		t_back.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
		t_back.tween_property(self, "global_position", start_pos, 0.35)
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

func _resolve_attack_damage(target: Unit, ability_index: int) -> void:
	if not stats or not target.stats:
		return
	var ab: Dictionary = Unit.get_ability(self, ability_index)
	# Bloqueo activo: anula el golpe y consume el bloqueo
	if target._blocking:
		target._blocking = false
		target.show_floating_text("¡Bloqueado!", Color(0.3, 0.7, 1.0))
		# Registrar: atacante falló (bloqueado), defensor bloqueó
		stats.battle_misses += 1
		target.stats.battle_blocks += 1
		return
	if randf() < target.stats.evasion:
		target.show_floating_text("Esquive", Color.YELLOW)
		# Registrar: atacante falló (esquivado), defensor esquivó
		stats.battle_misses += 1
		target.stats.battle_evades += 1
		return
	if randf() > ab.get("hit_chance", 1.0):
		target.show_floating_text("Falló", Color(0.55, 0.55, 0.55))
		# Registrar: atacante falló
		stats.battle_misses += 1
		return
	var crit_mult: float = 2.0 if randf() < stats.crit_chance else 1.0
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
func _play_attack_animation(ability_index: int = 0) -> void:
	var ap: AnimationPlayer = _get_anim_ap()
	if not ap:
		await _fallback_attack_tween()
		return

	var ab: Dictionary = Unit.get_ability(self, ability_index)
	var anim_name: String = ab.get("anim_name", "attack")
	if not ap.has_animation(anim_name):
		anim_name = "attack"

	if ap.has_animation(anim_name):
		_stop_idle()
		_anim_state = AnimState.ATTACK
		ap.play(anim_name)
		await ap.animation_finished
	else:
		await _fallback_attack_tween()


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
