extends Node3D
##
## Jugador de la escena de exploración: solo se mueve entre hexágonos por clic.
## Siempre empieza y se desplaza al centro de un hex.
##

signal move_finished

const MOVE_DURATION := 0.4
const RIG_GENERAL := "res://assets/KayKit_Adventurers_2.0_FREE/Animations/gltf/Rig_Medium/Rig_Medium_General.glb"
const RIG_MOVEMENT := "res://assets/KayKit_Adventurers_2.0_FREE/Animations/gltf/Rig_Medium/Rig_Medium_MovementBasic.glb"

enum State { IDLE, WALKING }

var _current_hex: Vector2i = Vector2i(0, 0)
var _move_tween: Tween
var _state: State = State.IDLE

@onready var visual: Node3D = $Visual
@onready var _ap: AnimationPlayer = $Visual/AnimationPlayer

func _ready() -> void:
	_setup_rig_animations(RIG_GENERAL, {"idle": "Idle_A", "idle_2": "Idle_B"})
	_setup_walk_animation()
	_state = State.IDLE
	_play_idle()

func set_initial_hex(hex: Vector2i) -> void:
	_current_hex = hex
	global_position = HexGrid.hex_to_world(hex.x, hex.y, 0.0)

func get_current_hex() -> Vector2i:
	return _current_hex

func move_to_hex(hex: Vector2i) -> void:
	if _move_tween and _move_tween.is_valid() and _move_tween.is_running():
		return
	_state = State.WALKING
	if _ap and _ap.has_animation("walk"):
		_ap.play("walk")
	var target_pos: Vector3 = HexGrid.hex_to_world(hex.x, hex.y, 0.0)
	_current_hex = hex
	var dir: Vector3 = (target_pos - global_position).normalized()
	dir.y = 0.0
	if dir.length_squared() > 0.01:
		look_at(global_position + dir, Vector3.UP)
	_move_tween = create_tween()
	_move_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_move_tween.tween_property(self, "global_position", target_pos, MOVE_DURATION)
	_move_tween.tween_callback(_on_move_done)

func _on_move_done() -> void:
	_state = State.IDLE
	_play_idle()
	emit_signal("move_finished")

func _play_idle() -> void:
	if not _ap:
		return
	if _ap.has_animation("idle") and _ap.has_animation("idle_2"):
		_ap.play("idle" if randf() > 0.5 else "idle_2")
	elif _ap.has_animation("idle"):
		_ap.play("idle")
	elif _ap.has_animation("idle_2"):
		_ap.play("idle_2")

func _setup_rig_animations(rig_glb_path: String, anim_map: Dictionary) -> void:
	if not _ap:
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
		push_error("ExplorePlayer: no se pudo cargar rig %s" % rig_glb_path)
		return
	var anim_source: Node = scene.instantiate()
	var source_ap: AnimationPlayer = _find_animation_player(anim_source)
	if not source_ap:
		anim_source.queue_free()
		return
	var list: PackedStringArray = _ap.get_animation_library_list()
	if not list.has(""):
		_ap.add_animation_library("", AnimationLibrary.new())
	var lib: AnimationLibrary = _ap.get_animation_library("")
	if not lib:
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
		anim.loop_mode = Animation.LOOP_LINEAR
		lib.add_animation(local_name, anim)
	anim_source.queue_free()

func _setup_walk_animation() -> void:
	var walk_name := _discover_walk_anim_name()
	if walk_name.is_empty():
		return
	_setup_rig_animations(RIG_MOVEMENT, {"walk": walk_name})

func _discover_walk_anim_name() -> String:
	var scene: PackedScene = load(RIG_MOVEMENT) as PackedScene
	if not scene:
		return ""
	var inst: Node = scene.instantiate()
	var source_ap: AnimationPlayer = _find_animation_player(inst)
	var name_out := ""
	if source_ap:
		if source_ap.has_animation("Walk"):
			name_out = "Walk"
		elif source_ap.has_animation("Walking"):
			name_out = "Walking"
	inst.queue_free()
	return name_out

func _find_animation_player(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n as AnimationPlayer
	for c in n.get_children():
		var ap := _find_animation_player(c)
		if ap:
			return ap
	return null
