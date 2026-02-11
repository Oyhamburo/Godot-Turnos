extends Node3D
class_name BattleCameraRig
##
## Rig de cámara para paneos: overview del tablero y focus en unidades.
##

signal skip_requested

var _camera: Camera3D
var _current_tween: Tween

# Estado de órbita para transiciones suaves
var _orbit_target: Vector3
var _orbit_look_target: Vector3

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


## Transición orbital suave: la cámara orbita alrededor del personaje usando
## coordenadas polares (ángulo + radio + altura), manteniendo look_at en cada frame.
func _tween_to_offset_view(target: Vector3, offset: Vector3, view_name: String) -> void:
	_stop_current_tween()
	if not _camera:
		return

	_orbit_target = target
	_orbit_look_target = target + Vector3(0, 1.0, 0)

	var from_polar: Vector3 = _cam_to_polar(target)
	var to_polar: Vector3 = _offset_to_polar(offset)

	# Interpolar ángulo por camino más corto (evitar giro de 360°)
	var angle_diff: float = wrapf(to_polar.x - from_polar.x, -PI, PI)
	var final_angle: float = from_polar.x + angle_diff

	print("[Camera] %s: orbit de %.0f° a %.0f° (diff: %.0f°), radio %.1f→%.1f, alt %.1f→%.1f" % [
		view_name,
		rad_to_deg(from_polar.x), rad_to_deg(to_polar.x), rad_to_deg(angle_diff),
		from_polar.y, to_polar.y,
		from_polar.z, to_polar.z
	])

	_current_tween = create_tween()
	_current_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_current_tween.tween_method(
		func(t: float) -> void:
			var angle: float = lerpf(from_polar.x, final_angle, t)
			var radius: float = lerpf(from_polar.y, to_polar.y, t)
			var height: float = lerpf(from_polar.z, to_polar.z, t)
			_camera.global_position = _orbit_target + Vector3(
				cos(angle) * radius,
				height,
				sin(angle) * radius
			)
			_camera.look_at(_orbit_look_target, Vector3.UP),
		0.0, 1.0, COMBAT_TWEEN_DURATION
	)


## Convierte un offset cartesiano a coordenadas polares: (ángulo_rad, radio_xz, altura_y).
func _offset_to_polar(offset: Vector3) -> Vector3:
	var angle: float = atan2(offset.z, offset.x)
	var radius: float = Vector2(offset.x, offset.z).length()
	return Vector3(angle, radius, offset.y)


## Calcula las coordenadas polares actuales de la cámara relativas a un target.
func _cam_to_polar(target: Vector3) -> Vector3:
	var diff: Vector3 = _camera.global_position - target
	var angle: float = atan2(diff.z, diff.x)
	var radius: float = Vector2(diff.x, diff.z).length()
	return Vector3(angle, radius, diff.y)
