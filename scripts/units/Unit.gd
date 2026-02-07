extends CharacterBody3D
class_name Unit

signal hp_changed(unit: Unit)
signal died(unit: Unit)

enum Team { PLAYER, ENEMY }

## Estados de la máquina de estados de animación (unidades con AnimationPlayer).
enum AnimState {
	NONE,
	IDLE,
	SPAWN,
	HIT,
	DEATH
}

@export var data: UnitData
@export var display_name: String = "Unit"
@export_enum("PLAYER", "ENEMY") var team: int = 0
@export var max_hp: int = 30
@export var hp: int = 30
@export var speed: int = 10
@export var attack: int = 8
@export var stop_distance: float = 1.35
@export var color: Color = Color.WHITE

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
	max_hp = data.max_hp
	hp = data.max_hp
	speed = data.speed
	attack = data.attack
	stop_distance = data.stop_distance
	color = data.color

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

func _anim_name_for_state(s: AnimState) -> String:
	match s:
		AnimState.IDLE: return "idle"
		AnimState.SPAWN: return "spawn_air"
		AnimState.HIT: return "hit"
		AnimState.DEATH: return "death"
		_: return ""

## Máquina de estados de animación: transiciona al estado indicado y reproduce la animación correspondiente.
func set_animation_state(s: AnimState) -> void:
	if s == AnimState.NONE:
		_stop_idle()
		_anim_state = AnimState.NONE
		return
	if not alive and s != AnimState.DEATH:
		return
	if _anim_state == s and s == AnimState.IDLE:
		return

	var ap: AnimationPlayer = _get_anim_ap()
	var anim_name := _anim_name_for_state(s)
	if ap and anim_name != "" and ap.has_animation(anim_name):
		_stop_idle()
		_anim_state = s
		ap.play(anim_name)
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

func _stop_idle() -> void:
	if _idle_tween and _idle_tween.is_running():
		_idle_tween.kill()
	_idle_tween = null
	visual.scale = Vector3.ONE
	var ap: AnimationPlayer = _get_anim_ap()
	if ap and ap.has_animation("idle"):
		ap.stop()

func _on_animation_finished(_anim_name: StringName) -> void:
	if _anim_state == AnimState.SPAWN or _anim_state == AnimState.HIT:
		set_animation_state(AnimState.IDLE)

func take_damage(amount: int) -> void:
	if not alive:
		return
	hp = max(hp - amount, 0)
	emit_signal("hp_changed", self)
	if hp <= 0:
		die()
	else:
		_play_hurt_fx()
		set_animation_state(AnimState.HIT)

func die() -> void:
	if not alive:
		return
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

func attack_target(target: Unit) -> void:
	# Async action: move -> attack anim -> damage -> return.
	# Callers should `await` this method.
	if not alive or not target or not target.alive:
		return

	set_animation_state(AnimState.NONE)
	set_selected(false)

	var start_pos := global_position
	var start_rot := global_rotation

	var approach := _approach_position(target)

	_face_target(target.global_position)
	var t_move := create_tween()
	t_move.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t_move.tween_property(self, "global_position", approach, 0.35)
	await t_move.finished

	await _play_attack_anim()

	target.take_damage(attack)

	var t_back := create_tween()
	t_back.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	t_back.tween_property(self, "global_position", start_pos, 0.35)
	await t_back.finished

	# Restore original rotation smoothly (safer than tweening Basis).
	var t_rot := create_tween()
	t_rot.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t_rot.tween_property(self, "global_rotation", start_rot, 0.18)
	await t_rot.finished

	set_animation_state(AnimState.IDLE)

func _play_attack_anim() -> void:
	# A punchy squash + little color punch.
	var t := create_tween()
	t.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(visual, "scale", Vector3(1.12, 0.88, 1.12), 0.12)
	t.tween_property(visual, "scale", Vector3.ONE, 0.12)
	for m in _mesh_materials:
		if m is StandardMaterial3D:
			t.parallel().tween_property(m, "albedo_color", _base_color.lightened(0.25), 0.10)
			t.parallel().tween_property(m, "albedo_color", _base_color, 0.20)
	await t.finished
