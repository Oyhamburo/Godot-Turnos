extends Node3D
class_name BattleCameraRig
##
## Rig de cámara para paneos: overview del tablero y focus en unidades.
##

signal skip_requested

var _camera: Camera3D
var _current_tween: Tween

const OVERVIEW_DISTANCE_FACTOR: float = 1.8
const OVERVIEW_HEIGHT_OFFSET: float = 2.0
const FOCUS_DISTANCE: float = 5.0
const FOCUS_HEIGHT: float = 2.5

# Offsets para vistas de combate
const ACTION_VIEW_OFFSET := Vector3(3.0, 2.5, 3.0)
const ATTACK_VIEW_OFFSET := Vector3(1.5, 2.0, -3.0)
const ITEM_VIEW_OFFSET := Vector3(-2.5, 2.5, 3.0)
const COMBAT_TWEEN_DURATION: float = 0.7


func _ready() -> void:
	_camera = get_node_or_null("Camera3D")
	if not _camera:
		push_error("BattleCameraRig: no se encontró Camera3D.")


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT):
		skip_requested.emit()
		get_viewport().set_input_as_handled()


## Posiciona la cámara en vista elevada/diagonal del tablero.
func tween_to_overview(center: Vector3, size: Vector2, duration: float) -> void:
	_stop_current_tween()
	if not _camera:
		return

	var max_dim: float = maxf(size.x, size.y)
	var distance: float = max_dim * OVERVIEW_DISTANCE_FACTOR
	var target_pos: Vector3 = center + Vector3(
		distance * 0.5,
		distance * 0.4 + OVERVIEW_HEIGHT_OFFSET,
		distance * 0.5
	)
	print("[Camera] tween_to_overview: center=%s size=%s cam_from=%s cam_to=%s look_at=%s" % [center, size, _camera.global_position, target_pos, center])
	_camera.look_at(center, Vector3.UP)

	_current_tween = create_tween()
	_current_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_current_tween.tween_property(_camera, "global_position", target_pos, duration)
	_current_tween.tween_callback(_camera.look_at.bind(center, Vector3.UP))


## Enfoca la cámara en un punto (ej. posición de una unidad).
func tween_to_focus(target: Vector3, duration: float) -> void:
	_stop_current_tween()
	if not _camera:
		return

	var dir: Vector3 = (_camera.global_position - target).normalized()
	var cam_pos: Vector3 = _camera.global_position
	dir.y = 0
	if dir.length_squared() < 0.01:
		dir = Vector3(0.5, 0, 0.5).normalized()
	var target_pos: Vector3 = target + Vector3(dir.x * FOCUS_DISTANCE, FOCUS_HEIGHT, dir.z * FOCUS_DISTANCE)
	print("[Camera] tween_to_focus: focus_target=%s cam_from=%s cam_to=%s" % [target, cam_pos, target_pos])

	_current_tween = create_tween()
	_current_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_current_tween.tween_property(_camera, "global_position", target_pos, duration)
	_current_tween.tween_callback(func() -> void: _camera.look_at(target, Vector3.UP))


func _stop_current_tween() -> void:
	if _current_tween and _current_tween.is_running():
		_current_tween.kill()
	_current_tween = null


## Cancela el tween actual (para skip).
func cancel_tween() -> void:
	_stop_current_tween()


## Vista lateral del personaje para menú de acciones (Atacar/Item/Salir).
func tween_to_action_view(unit_pos: Vector3) -> void:
	_tween_to_offset_view(unit_pos, ACTION_VIEW_OFFSET, "action_view")


## Vista frontal/cercana para elegir ataque.
func tween_to_attack_view(unit_pos: Vector3) -> void:
	_tween_to_offset_view(unit_pos, ATTACK_VIEW_OFFSET, "attack_view")


## Vista alternativa para menú de items.
func tween_to_item_view(unit_pos: Vector3) -> void:
	_tween_to_offset_view(unit_pos, ITEM_VIEW_OFFSET, "item_view")


func _tween_to_offset_view(target: Vector3, offset: Vector3, view_name: String) -> void:
	_stop_current_tween()
	if not _camera:
		return
	var look_target: Vector3 = target + Vector3(0, 1.0, 0)
	var cam_target: Vector3 = target + offset
	print("[Camera] %s: target=%s cam_to=%s" % [view_name, target, cam_target])

	_current_tween = create_tween()
	_current_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_current_tween.tween_property(_camera, "global_position", cam_target, COMBAT_TWEEN_DURATION)
	_current_tween.tween_callback(func() -> void: _camera.look_at(look_target, Vector3.UP))
