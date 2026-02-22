extends Node3D
class_name CameraPivot
##
## Pivot de cámara 3ra persona. Controla yaw (horizontal) y pitch (vertical)
## con el movimiento del mouse. El SpringArm3D hijo evita colisiones.
##

const MOUSE_SENSITIVITY := 0.002
const PITCH_MIN_RAD := deg_to_rad(-60.0)
const PITCH_MAX_RAD := deg_to_rad(40.0)

var _yaw: float = 0.0
var _pitch: float = deg_to_rad(-10.0)


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	rotation = Vector3(_pitch, _yaw, 0.0)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		var motion := event as InputEventMouseMotion
		_yaw -= motion.relative.x * MOUSE_SENSITIVITY
		_pitch -= motion.relative.y * MOUSE_SENSITIVITY
		_pitch = clampf(_pitch, PITCH_MIN_RAD, PITCH_MAX_RAD)
		rotation = Vector3(_pitch, _yaw, 0.0)

	if event.is_action_pressed("ui_cancel"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
