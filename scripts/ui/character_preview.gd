extends SubViewportContainer
class_name CharacterPreview
##
## Preview 3D del personaje usando SubViewport.
## Muestra el modelo GLB del personaje con animación idle.
## Soporta rotación por drag y swap de modelo.
## Construido 100% por código (instanciado en PersonalInventoryPanel).
##

const MODELS: Dictionary = {
	"Knight":    "res://assets/KayKit_Adventurers_2.0_FREE/Characters/gltf/Knight.glb",
	"Mage":      "res://assets/KayKit_Adventurers_2.0_FREE/Characters/gltf/Mage.glb",
	"Rogue":     "res://assets/KayKit_Adventurers_2.0_FREE/Characters/gltf/Rogue.glb",
	"Barbarian": "res://assets/KayKit_Adventurers_2.0_FREE/Characters/gltf/Barbarian.glb",
}

const PREVIEW_SIZE := Vector2(220, 320)
const CAM_DISTANCE := 2.0
const CAM_HEIGHT   := 0.8
const CAM_FOV      := 50.0
const ROT_SPEED    := 0.5     # grados por píxel

var _viewport: SubViewport
var _scene_root: Node3D
var _model_anchor: Node3D
var _camera: Camera3D
var _light: DirectionalLight3D
var _anim_player: AnimationPlayer = null
var _current_model_name: String = ""

var _drag_active: bool = false
var _drag_start: Vector2 = Vector2.ZERO
var _model_rotation_y: float = 0.0

var _no_preview_label: Label = null


func _init() -> void:
	custom_minimum_size = PREVIEW_SIZE
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_build_viewport()
	_build_overlay()


func _build_viewport() -> void:
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(int(PREVIEW_SIZE.x), int(PREVIEW_SIZE.y))
	_viewport.transparent_bg = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.world_3d = World3D.new()
	add_child(_viewport)

	# Raíz de la escena 3D dentro del viewport
	_scene_root = Node3D.new()
	_viewport.add_child(_scene_root)

	# Cámara — construimos el Transform directamente para evitar look_at()
	# que requiere que el nodo esté en el árbol.
	_camera = Camera3D.new()
	_camera.fov = CAM_FOV
	var cam_pos    := Vector3(0.0, CAM_HEIGHT, CAM_DISTANCE)
	var cam_target := Vector3(0.0, CAM_HEIGHT * 0.5, 0.0)
	# Basis que apunta -Z hacia el objetivo
	var forward := (cam_target - cam_pos).normalized()
	var right   := Vector3.UP.cross(forward).normalized()
	var up      := forward.cross(right)
	_camera.transform = Transform3D(Basis(right, up, -forward), cam_pos)
	_scene_root.add_child(_camera)

	# Luz
	_light = DirectionalLight3D.new()
	_light.rotation_degrees = Vector3(-45, 30, 0)
	_light.light_energy = 1.5
	_scene_root.add_child(_light)

	# Luz de relleno (fill light suave)
	var fill := OmniLight3D.new()
	fill.position = Vector3(-1, 1, -1)
	fill.light_energy = 0.4
	fill.omni_range = 5.0
	_scene_root.add_child(fill)

	# Anchor para el modelo (permite rotar sin afectar cámara ni luces)
	_model_anchor = Node3D.new()
	_scene_root.add_child(_model_anchor)


func _build_overlay() -> void:
	# Label de fallback cuando no hay modelo
	_no_preview_label = Label.new()
	_no_preview_label.text = "Sin preview\ndisponible"
	_no_preview_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_no_preview_label.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	_no_preview_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.6, 1.0))
	_no_preview_label.add_theme_font_size_override("font_size", 13)
	_no_preview_label.anchor_right  = 1.0
	_no_preview_label.anchor_bottom = 1.0
	_no_preview_label.visible = true
	add_child(_no_preview_label)


## Carga y muestra el modelo indicado por nombre (ver diccionario MODELS).
func swap_model(model_name: String) -> void:
	if model_name == _current_model_name:
		return
	_current_model_name = model_name

	# Borrar modelo anterior
	for child in _model_anchor.get_children():
		child.queue_free()
	_anim_player = null

	var path: String = MODELS.get(model_name, "")
	if path == "" or not ResourceLoader.exists(path):
		_no_preview_label.visible = true
		return

	var packed: PackedScene = load(path)
	if packed == null:
		_no_preview_label.visible = true
		return

	var instance: Node3D = packed.instantiate()
	_model_anchor.add_child(instance)

	# Escalar: los modelos de KayKit son grandes (~150 units)
	instance.scale = Vector3.ONE * 0.013

	_no_preview_label.visible = false

	# Buscar AnimationPlayer en los hijos
	_anim_player = _find_animation_player(instance)
	if _anim_player:
		_play_idle()


func _play_idle() -> void:
	if _anim_player == null:
		return
	# Intentar reproducir animación "idle" o la primera disponible
	var lib := _anim_player.get_animation_library("")
	if lib == null:
		# Probar library con nombre del modelo
		var libs := _anim_player.get_animation_library_list()
		if libs.is_empty():
			return
		lib = _anim_player.get_animation_library(libs[0])
	if lib == null:
		return

	# Buscar "idle" o "Idle" en la lista de animaciones
	var anims := lib.get_animation_list()
	var idle_name: String = ""
	for a in anims:
		if a.to_lower().contains("idle"):
			idle_name = a
			break
	if idle_name == "" and anims.size() > 0:
		idle_name = anims[0]

	if idle_name != "":
		_anim_player.play(idle_name)


## Devuelve el primer AnimationPlayer encontrado en el árbol.
func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found:
			return found
	return null


## Devuelve la lista de nombres de modelo disponibles.
func get_model_names() -> Array:
	return MODELS.keys()


# ── Rotación por drag ──────────────────────────────────────────

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_drag_active = event.pressed
			if event.pressed:
				_drag_start = event.position

	elif event is InputEventMouseMotion and _drag_active:
		var delta_x: float = event.position.x - _drag_start.x
		_drag_start = event.position
		_model_rotation_y += delta_x * ROT_SPEED * 0.01
		_model_anchor.rotation.y = _model_rotation_y
