extends CharacterBody3D
class_name Unit

signal hp_changed(unit: Unit)
signal died(unit: Unit)

enum Team { PLAYER, ENEMY }

@export var display_name: String = "Unit"
@export_enum("PLAYER", "ENEMY") var team: int = 0
@export var max_hp: int = 30
@export var hp: int = 30
@export var speed: int = 10
@export var attack: int = 8
@export var stop_distance: float = 1.35
@export var color: Color = Color.WHITE

@onready var visual: MeshInstance3D = $Visual
@onready var selection_ring: MeshInstance3D = $SelectionRing
@onready var collider: CollisionShape3D = $CollisionShape3D

var alive: bool = true
var _start_position: Vector3
var _start_rotation: Vector3
var _idle_tween: Tween
var _mat: StandardMaterial3D
var _base_color: Color

func _ready() -> void:
	_start_position = global_position
	_start_rotation = global_rotation

	# Ensure material is unique per instance so flashes don't affect all units.
	if visual.material_override:
		_mat = visual.material_override.duplicate(true)
		visual.material_override = _mat
	else:
		_mat = StandardMaterial3D.new()
		visual.material_override = _mat

	_base_color = _mat.albedo_color
	selection_ring.visible = false
	play_idle()

func reset_start_pose() -> void:
	_start_position = global_position
	_start_rotation = global_rotation

func set_selected(selected: bool) -> void:
	if not alive:
		selection_ring.visible = false
		return
	selection_ring.visible = selected

func play_idle() -> void:
	_stop_idle()
	if not alive:
		return
	_idle_tween = create_tween()
	_idle_tween.set_loops() # infinite
	_idle_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_idle_tween.tween_property(visual, "scale", Vector3(1.04, 0.98, 1.04), 0.6)
	_idle_tween.tween_property(visual, "scale", Vector3.ONE, 0.6)

func _stop_idle() -> void:
	if _idle_tween and _idle_tween.is_running():
		_idle_tween.kill()
	_idle_tween = null
	visual.scale = Vector3.ONE

func take_damage(amount: int) -> void:
	if not alive:
		return
	hp = max(hp - amount, 0)
	emit_signal("hp_changed", self)
	if hp <= 0:
		die()
	else:
		_play_hurt_fx()

func die() -> void:
	if not alive:
		return
	alive = false
	set_selected(false)
	collider.disabled = true

	_stop_idle()
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
	t.tween_property(_mat, "albedo_color", Color(1, 0.35, 0.35, 1), 0.08)
	t.parallel().tween_property(visual, "position:x", visual.position.x + 0.06, 0.06)
	t.tween_property(visual, "position:x", visual.position.x - 0.06, 0.06)
	t.tween_property(_mat, "albedo_color", _base_color, 0.12)

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

	_stop_idle()
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

	play_idle()

func _play_attack_anim() -> void:
	# A punchy squash + little color punch.
	var t := create_tween()
	t.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(visual, "scale", Vector3(1.12, 0.88, 1.12), 0.12)
	t.tween_property(visual, "scale", Vector3.ONE, 0.12)

	t.parallel().tween_property(_mat, "albedo_color", _base_color.lightened(0.25), 0.10)
	t.parallel().tween_property(_mat, "albedo_color", _base_color, 0.20)

	await t.finished
