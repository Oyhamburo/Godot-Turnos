extends Node3D
class_name ExploreCameraRig
##
## Cámara orbital interactiva para la escena de exploración de mapa.
## El jugador puede rotar con botón derecho del mouse, hacer zoom con la rueda,
## y rotar con las teclas de flecha izquierda/derecha.
##

var _camera: Camera3D
var _tween_target: Tween

# Estado orbital (coordenadas polares)
var _angulo: float = PI / 4.0        # Ángulo horizontal en radianes
var _radio: float = 12.0             # Distancia al target en plano XZ
var _altura: float = 9.0             # Altura Y de la cámara
var _target: Vector3 = Vector3.ZERO  # Punto al que orbita (posición del jugador)

# Límites
const RADIO_MIN := 5.0
const RADIO_MAX := 22.0
const ALTURA_MIN := 3.0
const ALTURA_MAX := 18.0
const VELOCIDAD_ROTACION := 0.006   # Radianes por pixel de mouse
const VELOCIDAD_ZOOM := 1.2
const VELOCIDAD_TECLADO := 1.8      # Radianes por segundo

# Control de arrastre
var _arrastrando: bool = false


func _ready() -> void:
	_camera = get_node_or_null("Camera3D")
	if not _camera:
		push_error("ExploreCameraRig: no se encontró Camera3D hijo.")
		return
	_actualizar_camara()


func _input(event: InputEvent) -> void:
	if not _camera:
		return

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			_arrastrando = mb.pressed
			if mb.pressed:
				Input.set_default_cursor_shape(Input.CURSOR_MOVE)
			else:
				Input.set_default_cursor_shape(Input.CURSOR_ARROW)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_radio = clampf(_radio - VELOCIDAD_ZOOM, RADIO_MIN, RADIO_MAX)
			_altura = clampf(_altura - VELOCIDAD_ZOOM * 0.5, ALTURA_MIN, ALTURA_MAX)
			_actualizar_camara()
			get_viewport().set_input_as_handled()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_radio = clampf(_radio + VELOCIDAD_ZOOM, RADIO_MIN, RADIO_MAX)
			_altura = clampf(_altura + VELOCIDAD_ZOOM * 0.5, ALTURA_MIN, ALTURA_MAX)
			_actualizar_camara()
			get_viewport().set_input_as_handled()

	elif event is InputEventMouseMotion and _arrastrando:
		var motion := event as InputEventMouseMotion
		_angulo -= motion.relative.x * VELOCIDAD_ROTACION
		_altura = clampf(_altura - motion.relative.y * VELOCIDAD_ROTACION * 8.0, ALTURA_MIN, ALTURA_MAX)
		_actualizar_camara()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not _camera:
		return
	var rotacion := 0.0
	if Input.is_action_pressed("ui_left"):
		rotacion -= 1.0
	if Input.is_action_pressed("ui_right"):
		rotacion += 1.0
	if rotacion != 0.0:
		_angulo += rotacion * delta * VELOCIDAD_TECLADO
		_actualizar_camara()


## Establece el target de la cámara (posición del jugador) de forma instantánea.
func set_target(pos: Vector3) -> void:
	_target = pos
	_actualizar_camara()


## Mueve suavemente el target hacia una nueva posición (cuando el jugador se mueve).
func seguir_jugador_suave(pos: Vector3, duracion: float) -> void:
	if _tween_target and _tween_target.is_valid() and _tween_target.is_running():
		_tween_target.kill()
	_tween_target = create_tween()
	_tween_target.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween_target.tween_method(
		func(p: Vector3) -> void:
			_target = p
			_actualizar_camara(),
		_target, pos, duracion
	)


## Devuelve la Camera3D activa para raycast desde ExploreMap.
func get_camera() -> Camera3D:
	return _camera


func _actualizar_camara() -> void:
	if not _camera:
		return
	var cam_pos := _target + Vector3(
		cos(_angulo) * _radio,
		_altura,
		sin(_angulo) * _radio
	)
	_camera.global_position = cam_pos
	_camera.look_at(_target + Vector3(0, 0.5, 0), Vector3.UP)
