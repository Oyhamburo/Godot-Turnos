extends Unit
class_name EnemyUnit

# Animaciones disponibles en Rig_Medium_General.glb (orden igual que en el GLB).
enum RigAnim {
	DEATH_A,
	DEATH_A_POSE,
	DEATH_B,
	DEATH_B_POSE,
	HIT_A,
	HIT_B,
	IDLE_A,
	IDLE_B,
	INTERACT,
	PICK_UP,
	SPAWN_AIR,
	SPAWN_GROUND,
	T_POSE,
	THROW,
	USE_ITEM
}

# Mapeo enum -> nombre real de la animación en el GLB.
const RIG_ANIM_NAMES: Array[String] = [
	"Death_A", "Death_A_Pose", "Death_B", "Death_B_Pose",
	"Hit_A", "Hit_B", "Idle_A", "Idle_B", "Interact", "PickUp",
	"Spawn_Air", "Spawn_Ground", "T-Pose", "Throw", "Use_Item"
]

# Ruta al GLB que contiene las animaciones del rig KayKit (mismo esqueleto que Skeleton_Warrior).
const RIG_ANIMATION_GLB := "res://assets/KayKit_Skeletons_1.1_FREE/Animations/gltf/Rig_Medium/Rig_Medium_General.glb"

# Animaciones que usamos: nombre interno en nuestro AnimationPlayer -> RigAnim.
const SKELETON_ANIMS := {
	"spawn_air": RigAnim.SPAWN_AIR,
	"idle": RigAnim.IDLE_B,
	"death": RigAnim.DEATH_A,
	"hit": RigAnim.HIT_B,
	"attack": RigAnim.INTERACT
}

func _ready() -> void:
	team = Team.ENEMY
	_setup_skeleton_animations()
	super._ready()
	# Máquina de estados: al aparecer reproducir SPAWN; al terminar _on_animation_finished pasa a IDLE.
	set_animation_state(AnimState.SPAWN)

## Carga el GLB del rig, copia las animaciones spawn_air, idle, death y hit,
## reasigna las rutas al nodo esqueleto (GLB bajo Visual) y las registra en nuestro AnimationPlayer.
func _setup_skeleton_animations() -> void:
	var ap: AnimationPlayer = visual.get_node_or_null("AnimationPlayer")
	if not ap:
		return
	var skel_root: Node = null
	for c in visual.get_children():
		if c is AnimationPlayer:
			continue
		skel_root = c
		break
	if not skel_root:
		return

	var scene: PackedScene = load(RIG_ANIMATION_GLB) as PackedScene
	if not scene:
		push_error("EnemyUnit: no se pudo cargar %s" % RIG_ANIMATION_GLB)
		return
	var anim_source: Node = scene.instantiate()
	var source_ap: AnimationPlayer = _find_animation_player(anim_source)
	if not source_ap:
		anim_source.queue_free()
		return

	if not ap.get_animation_library(""):
		ap.add_animation_library("", AnimationLibrary.new())
	var lib: AnimationLibrary = ap.get_animation_library("")
	var source_root_name := anim_source.name
	var target_root_name := skel_root.name

	for local_name in SKELETON_ANIMS:
		var rig_anim: RigAnim = SKELETON_ANIMS[local_name]
		var rig_anim_name: String = RIG_ANIM_NAMES[rig_anim]
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
		if local_name == "idle":
			anim.loop_mode = Animation.LOOP_LINEAR
		lib.add_animation(local_name, anim)

	anim_source.queue_free()

## Busca recursivamente un nodo AnimationPlayer dentro del árbol dado (p. ej. la escena del GLB).
func _find_animation_player(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n as AnimationPlayer
	for c in n.get_children():
		var ap := _find_animation_player(c)
		if ap:
			return ap
	return null
