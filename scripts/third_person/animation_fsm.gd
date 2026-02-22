extends Node
class_name AnimationFSM
##
## Máquina de estados finita para animaciones del player 3ra persona.
## Gobierna un AnimationPlayer con transiciones:
##   IDLE ↔ WALK ↔ RUN, cualquiera → JUMP → FALL → LAND → IDLE.
##
## Carga animaciones desde los GLBs del pack KayKit.
## Nombres reales de las animaciones en los GLBs:
##   General.glb      → Idle_A, Idle_B
##   MovementBasic.glb → Walking_A, Walking_B, Walking_C,
##                        Running_A, Running_B,
##                        Jump_Full_Short, Jump_Full_Long, Jump_Start, Jump_Idle, Jump_Land
##

enum Estado { IDLE, WALK, RUN, JUMP, FALL, LAND }

const RIG_GENERAL := "res://assets/KayKit_Character_Animations_1.1/Animations/gltf/Rig_Medium/Rig_Medium_General.glb"
const RIG_MOVEMENT := "res://assets/KayKit_Character_Animations_1.1/Animations/gltf/Rig_Medium/Rig_Medium_MovementBasic.glb"

const LAND_DURATION := 0.2

var _estado: Estado = Estado.IDLE
var _ap: AnimationPlayer
var _visual_root_name: String = ""
var _land_timer: float = 0.0

# Flags de animaciones disponibles
var _has_idle := false
var _has_walk := false
var _has_run := false
var _has_jump := false


func setup(ap: AnimationPlayer, visual: Node3D) -> void:
	_ap = ap
	if not _ap:
		push_error("AnimationFSM: AnimationPlayer no encontrado.")
		return
	# Encontrar el nodo raíz del rig (primer hijo de Visual que NO es AnimationPlayer)
	for c in visual.get_children():
		if c is AnimationPlayer:
			continue
		_visual_root_name = c.name
		break
	print("[AnimationFSM] Visual root name: '%s'" % _visual_root_name)
	_cargar_animaciones()


func _cargar_animaciones() -> void:
	if not _ap or _visual_root_name.is_empty():
		push_warning("AnimationFSM: No se pudo configurar. AP=%s, root='%s'" % [_ap != null, _visual_root_name])
		return

	# Idle desde General.glb — nombres exactos: Idle_A, Idle_B
	_has_idle = _importar_desde_rig(RIG_GENERAL, {"idle": "Idle_A", "idle_2": "Idle_B"})

	# Walk, Run, Jump — TODOS están en MovementBasic.glb
	# Nombres exactos: Walking_A, Running_A, Jump_Full_Short
	var movement_map: Dictionary = {
		"walk": "Walking_A",
		"run": "Running_A",
		"jump": "Jump_Full_Short",
	}
	_importar_desde_rig(RIG_MOVEMENT, movement_map)

	_has_walk = _ap.has_animation("walk")
	_has_run = _ap.has_animation("run")
	_has_jump = _ap.has_animation("jump")

	if not _has_walk:
		push_warning("AnimationFSM: No se encontró anim 'walk'.")
	if not _has_run:
		push_warning("AnimationFSM: No se encontró anim 'run'. Usando walk como fallback.")
	if not _has_jump:
		push_warning("AnimationFSM: No se encontró anim 'jump'. Salto sin animación.")

	# Diagnóstico
	print("[AnimationFSM] idle=%s walk=%s run=%s jump=%s" % [_has_idle, _has_walk, _has_run, _has_jump])
	if _ap:
		var diag_list: PackedStringArray = _ap.get_animation_library_list()
		if diag_list.has(""):
			var diag_lib: AnimationLibrary = _ap.get_animation_library("")
			if diag_lib:
				print("[AnimationFSM] Animaciones cargadas: %s" % str(diag_lib.get_animation_list()))

	_play("idle")


func _process(delta: float) -> void:
	if _estado == Estado.LAND:
		_land_timer -= delta
		if _land_timer <= 0.0:
			_cambiar_estado(Estado.IDLE)


## Llamado cada frame por player_controller con datos actuales.
func actualizar(velocidad_xz: float, en_piso: bool, corriendo: bool, vel_y: float) -> void:
	# El estado LAND se maneja solo con timer
	if _estado == Estado.LAND:
		return

	if not en_piso:
		if vel_y > 0.5:
			_cambiar_estado(Estado.JUMP)
		else:
			_cambiar_estado(Estado.FALL)
		return

	# En piso
	if _estado == Estado.JUMP or _estado == Estado.FALL:
		# Aterrizaje
		_land_timer = LAND_DURATION
		_cambiar_estado(Estado.LAND)
		return

	if velocidad_xz < 0.5:
		_cambiar_estado(Estado.IDLE)
	elif corriendo and _has_run:
		_cambiar_estado(Estado.RUN)
	else:
		_cambiar_estado(Estado.WALK)


func _cambiar_estado(nuevo: Estado) -> void:
	if nuevo == _estado:
		return
	_estado = nuevo
	match nuevo:
		Estado.IDLE:
			_play("idle")
		Estado.WALK:
			_play("walk" if _has_walk else "idle")
		Estado.RUN:
			_play("run" if _has_run else ("walk" if _has_walk else "idle"))
		Estado.JUMP:
			_play("jump" if _has_jump else ("walk" if _has_walk else "idle"))
		Estado.FALL:
			_play("jump" if _has_jump else "idle")
		Estado.LAND:
			_play("idle")


func _play(anim_name: String) -> void:
	if not _ap:
		return
	if _ap.has_animation(anim_name) and _ap.current_animation != anim_name:
		_ap.play(anim_name)
	elif anim_name == "idle" and _ap.has_animation("idle_2"):
		# Alternar idle
		if _ap.current_animation != "idle" and _ap.current_animation != "idle_2":
			_ap.play("idle" if randf() > 0.5 else "idle_2")


# ── Carga de animaciones desde GLBs ───────────────────────────────────────

func _importar_desde_rig(rig_path: String, anim_map: Dictionary) -> bool:
	if anim_map.is_empty():
		return false
	var scene: PackedScene = load(rig_path) as PackedScene
	if not scene:
		push_warning("AnimationFSM: No se pudo cargar %s" % rig_path)
		return false
	var inst: Node = scene.instantiate()
	var source_ap: AnimationPlayer = _find_ap(inst)
	if not source_ap:
		push_warning("AnimationFSM: No se encontró AnimationPlayer en %s" % rig_path)
		inst.queue_free()
		return false

	# Listar todas las animaciones disponibles en el source para diagnóstico
	var source_anims: PackedStringArray = PackedStringArray()
	for lib_name in source_ap.get_animation_library_list():
		var slib: AnimationLibrary = source_ap.get_animation_library(lib_name)
		if slib:
			for anim_name in slib.get_animation_list():
				source_anims.append(str(anim_name))
	print("[AnimationFSM] Animaciones en %s: %s" % [rig_path.get_file(), str(source_anims)])

	var list: PackedStringArray = _ap.get_animation_library_list()
	if not list.has(""):
		_ap.add_animation_library("", AnimationLibrary.new())
	var lib: AnimationLibrary = _ap.get_animation_library("")
	if not lib:
		inst.queue_free()
		return false
	var source_root := str(inst.name)
	var target_root := _visual_root_name
	var any := false
	for local_name in anim_map:
		var rig_name: String = anim_map[local_name]
		if not source_ap.has_animation(rig_name):
			push_warning("AnimationFSM: Anim '%s' no encontrada en %s" % [rig_name, rig_path.get_file()])
			continue
		var anim: Animation = source_ap.get_animation(rig_name).duplicate()
		for i in range(anim.get_track_count()):
			var path: NodePath = anim.track_get_path(i)
			var path_str := str(path)
			var new_path: String
			if path_str.begins_with(source_root + "/"):
				new_path = target_root + path_str.substr(source_root.length())
			elif path_str == source_root:
				new_path = target_root
			else:
				new_path = target_root + "/" + path_str
			anim.track_set_path(i, NodePath(new_path))
		# Jump no debe repetirse en bucle; el resto sí
		if local_name == "jump":
			anim.loop_mode = Animation.LOOP_NONE
		else:
			anim.loop_mode = Animation.LOOP_LINEAR
		if lib.has_animation(local_name):
			lib.remove_animation(local_name)
		lib.add_animation(local_name, anim)
		any = true
	inst.queue_free()
	return any


func _find_ap(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n as AnimationPlayer
	for c in n.get_children():
		var ap := _find_ap(c)
		if ap:
			return ap
	return null
