extends CharacterBody3D
##
## Controlador de jugador 3ra persona.
## WASD para moverse (relativo a la cámara), Shift corre, Space salta.
## E para interactuar con edificios cercanos.
## La cámara se controla con el mouse a través de CameraPivot.
##

const WALK_SPEED := 2.0
const RUN_SPEED := 4.5
const ACCELERATION := 8.0
const DECELERATION := 10.0
const JUMP_VELOCITY := 4.5
const GRAVITY := 15.0
const ROTATION_SPEED := 10.0

@onready var _camera_pivot: CameraPivot = $CameraPivot
@onready var _visual: Node3D = $Visual
@onready var _anim_fsm: AnimationFSM = $AnimFSM
@onready var _ap: AnimationPlayer = $Visual/AnimationPlayer
@onready var _interact_area: Area3D = $InteractArea

var _corriendo: bool = false
var _interactable_cercano: Interactable = null

## Signal para que el mapa muestre/oculte el hint de interacción
signal interact_hint_changed(visible: bool, nombre: String)
## Signal para que el mapa muestre el cartel del edificio
signal edificio_interactuado(nombre: String)


func _ready() -> void:
	# Configurar la FSM de animaciones
	if _anim_fsm and _ap and _visual:
		_anim_fsm.setup(_ap, _visual)


func _physics_process(delta: float) -> void:
	# Gravedad
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	# Saltar
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Correr
	_corriendo = Input.is_action_pressed("run")
	var speed: float = RUN_SPEED if _corriendo else WALK_SPEED

	# Leer input WASD
	var input_dir := Vector2.ZERO
	input_dir.x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	input_dir.y = Input.get_action_strength("move_forward") - Input.get_action_strength("move_back")
	input_dir = input_dir.limit_length(1.0)

	# Dirección relativa al yaw de la cámara
	var cam_basis: Basis = _camera_pivot.global_transform.basis
	var forward: Vector3 = -cam_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var right: Vector3 = cam_basis.x
	right.y = 0.0
	right = right.normalized()

	var direction: Vector3 = (right * input_dir.x + forward * input_dir.y).normalized()

	# Aplicar movimiento con aceleración/deceleración
	if direction.length_squared() > 0.01:
		velocity.x = move_toward(velocity.x, direction.x * speed, ACCELERATION * delta)
		velocity.z = move_toward(velocity.z, direction.z * speed, ACCELERATION * delta)
		# Rotar el visual hacia la dirección de movimiento
		var target_angle: float = atan2(direction.x, direction.z)
		_visual.rotation.y = lerp_angle(_visual.rotation.y, target_angle, ROTATION_SPEED * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, DECELERATION * delta)
		velocity.z = move_toward(velocity.z, 0.0, DECELERATION * delta)

	move_and_slide()

	# Actualizar FSM de animaciones
	var vel_xz: float = Vector2(velocity.x, velocity.z).length()
	if _anim_fsm:
		_anim_fsm.actualizar(vel_xz, is_on_floor(), _corriendo, velocity.y)

	# Detectar interactable cercano
	_actualizar_interactable_cercano()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and _interactable_cercano:
		_interactable_cercano.interact(self)
		if _interactable_cercano is BuildingInteractable:
			var edificio := _interactable_cercano as BuildingInteractable
			edificio_interactuado.emit(edificio.nombre_edificio)


func _actualizar_interactable_cercano() -> void:
	if not _interact_area:
		return

	var mejor: Interactable = null
	var mejor_dist: float = INF

	for body in _interact_area.get_overlapping_bodies():
		# Buscar el Interactable padre del StaticBody
		var nodo := body.get_parent()
		if nodo is Interactable:
			var dist: float = global_position.distance_to(nodo.global_position)
			if dist < mejor_dist:
				mejor_dist = dist
				mejor = nodo

	if mejor != _interactable_cercano:
		_interactable_cercano = mejor
		if _interactable_cercano and _interactable_cercano is BuildingInteractable:
			var edificio := _interactable_cercano as BuildingInteractable
			interact_hint_changed.emit(true, edificio.nombre_edificio)
		else:
			interact_hint_changed.emit(false, "")
