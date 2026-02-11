extends CharacterBody3D
class_name Unit

const _UnitStats = preload("res://scripts/unit/stats/unit_stats.gd")
const _UnitStatsTemplate = preload("res://scripts/unit/stats/unit_stats_template.gd")
const _FloatingHUDScene = preload("res://scenes/ui/FloatingHUD.tscn")

signal hp_changed(unit: Unit)
signal died(unit: Unit)

enum Team { PLAYER, ENEMY }

## Estados de la máquina de estados de animación (unidades con AnimationPlayer).
enum AnimState {
	NONE,
	IDLE,
	SPAWN,
	HIT,
	DEATH,
	ATTACK,
	WALK
}

@export var data: UnitData
@export var display_name: String = "Unit"
@export_enum("PLAYER", "ENEMY") var team: int = 0
@export var stop_distance: float = 1.35
@export var color: Color = Color.WHITE

## Stats runtime; se crea desde stats_template o desde data.
var stats: UnitStats

@onready var visual: Node3D = $Visual
@onready var selection_ring: MeshInstance3D = $SelectionRing
@onready var collider: CollisionShape3D = $CollisionShape3D

var alive: bool = true
var _start_position: Vector3
var _start_rotation: Vector3
var _idle_tween: Tween
var _mat: StandardMaterial3D
var _base_color: Color
var _mesh_instances: Array[MeshInstance3D] = []
var _mesh_materials: Array[Material] = []
var _use_unit_color: bool = true  # false cuando usamos material del GLB (conservar textura)
var _anim_state: AnimState = AnimState.NONE

## Mapeo ability_index → nombre de animación para ataques diferenciados.
## Las subclases lo populan en _ready(). Fallback: "attack" (Interact genérico).
var _attack_anim_for_ability: Dictionary = {}

# Habilidades por clase: [ { physical, magic, hit_chance, range }, ... ] (4 por clase).
# range: 99 = distancia (siempre disponible), 1 = melee (solo adyacente).
# Ataques 1-2 son a distancia (débiles), ataques 3-4 son melee (fuertes).
const _ABILITIES: Dictionary = {
	"PlayerKnight": [ {"physical": 4, "magic": 0, "hit_chance": 0.95, "range": 99}, {"physical": 8, "magic": 0, "hit_chance": 0.88, "range": 99}, {"physical": 14, "magic": 0, "hit_chance": 0.78, "range": 1}, {"physical": 22, "magic": 0, "hit_chance": 0.60, "range": 1} ],
	"PlayerMage": [ {"physical": 0, "magic": 4, "hit_chance": 0.95, "range": 99}, {"physical": 0, "magic": 9, "hit_chance": 0.88, "range": 99}, {"physical": 0, "magic": 15, "hit_chance": 0.75, "range": 1}, {"physical": 0, "magic": 24, "hit_chance": 0.58, "range": 1} ],
	"PlayerRanger": [ {"physical": 3, "magic": 0, "hit_chance": 0.94, "range": 99}, {"physical": 6, "magic": 3, "hit_chance": 0.86, "range": 99}, {"physical": 10, "magic": 6, "hit_chance": 0.76, "range": 1}, {"physical": 14, "magic": 10, "hit_chance": 0.62, "range": 1} ],
	"PlayerRogue": [ {"physical": 3, "magic": 0, "hit_chance": 0.96, "range": 99}, {"physical": 7, "magic": 0, "hit_chance": 0.88, "range": 99}, {"physical": 12, "magic": 0, "hit_chance": 0.75, "range": 1}, {"physical": 18, "magic": 0, "hit_chance": 0.58, "range": 1} ],
	"PlayerBarbarian": [ {"physical": 5, "magic": 0, "hit_chance": 0.92, "range": 99}, {"physical": 11, "magic": 0, "hit_chance": 0.82, "range": 99}, {"physical": 18, "magic": 0, "hit_chance": 0.68, "range": 1}, {"physical": 26, "magic": 0, "hit_chance": 0.52, "range": 1} ],
	"PlayerRogueHooded": [ {"physical": 3, "magic": 0, "hit_chance": 0.96, "range": 99}, {"physical": 7, "magic": 0, "hit_chance": 0.88, "range": 99}, {"physical": 12, "magic": 0, "hit_chance": 0.75, "range": 1}, {"physical": 18, "magic": 0, "hit_chance": 0.58, "range": 1} ],
}
const _ABILITIES_ENEMY: Array = [ {"physical": 2, "magic": 0, "hit_chance": 0.93, "range": 99}, {"physical": 5, "magic": 0, "hit_chance": 0.85, "range": 99}, {"physical": 9, "magic": 0, "hit_chance": 0.74, "range": 1}, {"physical": 14, "magic": 0, "hit_chance": 0.60, "range": 1} ]

static func get_ability(unit: Unit, ability_index: int) -> Dictionary:
	if unit == null or ability_index < 0 or ability_index > 3:
		return {"physical": 0, "magic": 0, "hit_chance": 1.0}
	var class_key: String = unit.scene_file_path.get_file().get_basename() if not unit.scene_file_path.is_empty() else ""
	var arr: Array = Unit._ABILITIES.get(class_key, Unit._ABILITIES_ENEMY) if class_key in Unit._ABILITIES else Unit._ABILITIES_ENEMY
	return arr[clampi(ability_index, 0, arr.size() - 1)]

func _get_visual_meshes() -> Array[MeshInstance3D]:
	var list: Array[MeshInstance3D] = []
	if visual is MeshInstance3D:
		list.append(visual as MeshInstance3D)
	else:
		for c in visual.find_children("*", "MeshInstance3D", true, false):
			list.append(c as MeshInstance3D)
	return list

func _get_mesh_surface_material(mi: MeshInstance3D) -> Material:
	if mi.material_override:
		return mi.material_override.duplicate(true)
	if mi.mesh and mi.mesh.get_surface_count() > 0:
		var surf_mat: Material = mi.mesh.surface_get_material(0)
		if surf_mat:
			return surf_mat.duplicate(true)
	return null

func _ready() -> void:
	if data:
		_apply_data()
	else:
		_create_default_stats()
	_ensure_stats()
	add_floating_hud()
	_start_position = global_position
	_start_rotation = global_rotation

	_mesh_instances = _get_visual_meshes()
	if _mesh_instances.is_empty():
		push_error("Unit: Visual no tiene MeshInstance3D")
		return

	# Usar material del mesh (GLB con textura) cuando no hay material_override; si no, material plano.
	var first_mat: Material = _get_mesh_surface_material(_mesh_instances[0])
	if first_mat == null:
		first_mat = StandardMaterial3D.new()
		_use_unit_color = true
	else:
		_use_unit_color = false

	for i in range(_mesh_instances.size()):
		var mi: MeshInstance3D = _mesh_instances[i]
		var mat: Material = first_mat if i == 0 else _get_mesh_surface_material(mi)
		if mat == null:
			mat = StandardMaterial3D.new()
		mi.material_override = mat
		_mesh_materials.append(mat)

	_mat = first_mat as StandardMaterial3D
	if _mat:
		if _use_unit_color:
			_base_color = color
			_mat.albedo_color = _base_color
		else:
			_base_color = _mat.albedo_color
	else:
		_base_color = color
	selection_ring.visible = false
	var ap: AnimationPlayer = _get_anim_ap()
	if ap:
		ap.animation_finished.connect(_on_animation_finished)
	set_animation_state(AnimState.IDLE)

func _physics_process(delta: float) -> void:
	if not alive:
		return
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y += get_gravity().y * delta
	move_and_slide()

func _apply_data() -> void:
	display_name = data.display_name
	team = data.team
	stop_distance = data.stop_distance
	color = data.color
	var t: UnitStatsTemplate
	if data.stats_template:
		t = data.stats_template
	else:
		t = _build_template_from_data()
	stats = _UnitStats.from_template(t)
	if stats and stats.template:
		display_name = stats.template.display_name
		team = stats.template.team


func _build_template_from_data() -> UnitStatsTemplate:
	var t := _UnitStatsTemplate.new()
	t.display_name = data.display_name
	t.team = data.team
	t.max_hp = data.max_hp
	t.max_mana = 0
	t.speed = data.speed
	t.armor = data.armor
	t.magic_resist = data.magic_resist
	t.physical_damage = data.physical_damage if data.physical_damage > 0 else data.attack
	t.magic_damage = data.magic_damage
	t.evasion = data.dodge_chance
	t.crit_chance = data.crit_chance
	return t


func _create_default_stats() -> void:
	var t := _UnitStatsTemplate.new()
	t.display_name = display_name
	t.team = team
	t.max_hp = 30
	t.max_mana = 0
	t.speed = 10
	t.armor = 0
	t.magic_resist = 0
	t.physical_damage = 8
	t.magic_damage = 0
	t.evasion = 0.05
	t.crit_chance = 0.05
	stats = _UnitStats.from_template(t)


func _ensure_stats() -> void:
	if not stats:
		_create_default_stats()


func add_floating_hud() -> void:
	if not stats:
		print("[Unit] %s: add_floating_hud - stats es null!" % display_name)
		return
	var hud: Node3D = _FloatingHUDScene.instantiate()
	add_child(hud)
	hud.position = Vector3(0.0, 1.85, 0.0)
	if hud is FloatingHUD:
		hud.setup(stats, display_name, team)
		stats.hp_changed.connect(_on_stats_hp_changed)
		print("[Unit] %s: FloatingHUD creado - HP %d/%d - team: %d - pos: %s" % [display_name, stats.hp, stats.max_hp, team, hud.position])
	else:
		print("[Unit] %s: hud instanciado pero no es FloatingHUD!" % display_name)


func _on_stats_hp_changed(_current: int, _max_val: int) -> void:
	print("[Unit] %s: hp_changed -> %d/%d" % [display_name, _current, _max_val])
	emit_signal("hp_changed", self)

func refresh_visual_color() -> void:
	if not _use_unit_color:
		return
	_base_color = color
	for m in _mesh_materials:
		if m is StandardMaterial3D:
			(m as StandardMaterial3D).albedo_color = _base_color

func reset_start_pose() -> void:
	_start_position = global_position
	_start_rotation = global_rotation

func set_selected(selected: bool) -> void:
	if not alive:
		selection_ring.visible = false
		return
	selection_ring.visible = selected

func _get_anim_ap() -> AnimationPlayer:
	return visual.get_node_or_null("AnimationPlayer") as AnimationPlayer

## Carga un GLB de rig (p. ej. Rig_Medium_General), reasigna las pistas al nodo bajo Visual
## y registra las animaciones en nuestro AnimationPlayer. anim_map: nombre_local -> nombre_en_glb.
func _setup_rig_animations(rig_glb_path: String, anim_map: Dictionary) -> void:
	var ap: AnimationPlayer = visual.get_node_or_null("AnimationPlayer")
	if not ap:
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
		push_error("Unit: no se pudo cargar rig %s" % rig_glb_path)
		return
	var anim_source: Node = scene.instantiate()
	var source_ap: AnimationPlayer = _find_animation_player(anim_source)
	if not source_ap:
		anim_source.queue_free()
		return
	# No llamar get_animation_library("") si no existe: en Godot 4 puede fallar y devolver Ref inválida
	var list: PackedStringArray = ap.get_animation_library_list()
	if not list.has(""):
		ap.add_animation_library("", AnimationLibrary.new())
	var lib: AnimationLibrary = ap.get_animation_library("")
	if not lib:
		push_error("Unit: no se pudo obtener la biblioteca de animación por defecto")
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
		if local_name == "idle" or local_name == "walk":
			anim.loop_mode = Animation.LOOP_LINEAR
		lib.add_animation(local_name, anim)
	anim_source.queue_free()

func _find_animation_player(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n as AnimationPlayer
	for c in n.get_children():
		var ap := _find_animation_player(c)
		if ap:
			return ap
	return null

func _anim_name_for_state(s: AnimState) -> String:
	match s:
		AnimState.IDLE: return "idle"
		AnimState.SPAWN: return "spawn_air"
		AnimState.HIT: return "hit"
		AnimState.DEATH: return "death"
		AnimState.ATTACK: return "attack"
		AnimState.WALK: return "walk"
		_: return ""

## Máquina de estados de animación: transiciona al estado indicado y reproduce la animación correspondiente.
## Transiciones IDLE↔WALK usan cross-fade (blend) de 0.25s para suavidad.
func set_animation_state(s: AnimState) -> void:
	if s == AnimState.NONE:
		_stop_idle()
		_anim_state = AnimState.NONE
		return
	if not alive and s != AnimState.DEATH:
		return
	if _anim_state == s and s == AnimState.IDLE:
		return

	var prev_state: AnimState = _anim_state
	var ap: AnimationPlayer = _get_anim_ap()
	var anim_name := _anim_name_for_state(s)
	if ap and anim_name != "" and ap.has_animation(anim_name):
		# Blend suave para transiciones IDLE↔WALK; instantáneo para el resto
		var use_blend: bool = (
			(prev_state == AnimState.IDLE and s == AnimState.WALK) or
			(prev_state == AnimState.WALK and s == AnimState.IDLE)
		)
		_stop_idle_tween()  # Matar tween de breathing/bounce, sin parar AnimationPlayer
		_anim_state = s
		if use_blend:
			ap.play(anim_name, 0.25)  # Cross-fade 0.25s
		else:
			ap.play(anim_name)
	elif s == AnimState.WALK:
		# Fallback: bounce vertical simulando caminar
		_stop_idle()
		_anim_state = AnimState.WALK
		_idle_tween = create_tween()
		_idle_tween.set_loops()
		_idle_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_idle_tween.tween_property(visual, "position:y", 0.08, 0.15)
		_idle_tween.tween_property(visual, "position:y", 0.0, 0.15)
	elif s == AnimState.SPAWN:
		set_animation_state(AnimState.IDLE)
	elif s == AnimState.IDLE:
		_stop_idle()
		if not alive:
			return
		_anim_state = AnimState.IDLE
		_idle_tween = create_tween()
		_idle_tween.set_loops()
		_idle_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_idle_tween.tween_property(visual, "scale", Vector3(1.04, 0.98, 1.04), 0.6)
		_idle_tween.tween_property(visual, "scale", Vector3.ONE, 0.6)

func play_idle() -> void:
	set_animation_state(AnimState.IDLE)

## Detiene solo el tween de breathing/bounce, sin tocar el AnimationPlayer.
## Usado para transiciones con blend donde el AP necesita seguir corriendo.
func _stop_idle_tween() -> void:
	if _idle_tween and _idle_tween.is_running():
		_idle_tween.kill()
	_idle_tween = null
	visual.scale = Vector3.ONE
	visual.position.y = 0.0


func _stop_idle() -> void:
	_stop_idle_tween()
	var ap: AnimationPlayer = _get_anim_ap()
	if ap and ap.is_playing():
		ap.stop()

func _on_animation_finished(_anim_name: StringName) -> void:
	if _anim_state == AnimState.SPAWN or _anim_state == AnimState.HIT or _anim_state == AnimState.ATTACK:
		set_animation_state(AnimState.IDLE)

func take_damage(amount: int) -> void:
	take_damage_split(amount, 0)

## Aplica daño físico y mágico ya reducido por armadura y resistencia mágica.
func take_damage_split(physical: int, magic: int) -> void:
	if not alive or not stats:
		return
	stats.apply_damage_direct(physical, magic)
	if stats.hp <= 0:
		die()
	else:
		_play_hurt_fx()
		set_animation_state(AnimState.HIT)

func die() -> void:
	if not alive:
		return
	print("[Unit] %s: murio" % display_name)
	alive = false
	set_selected(false)
	collider.disabled = true
	set_physics_process(false)
	velocity = Vector3.ZERO
	_stop_idle()

	var ap: AnimationPlayer = _get_anim_ap()
	if ap and ap.has_animation("death"):
		set_animation_state(AnimState.DEATH)
		await ap.animation_finished
	else:
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
	for m in _mesh_materials:
		if m is StandardMaterial3D:
			t.parallel().tween_property(m, "albedo_color", Color(1, 0.35, 0.35, 1), 0.08)
	t.parallel().tween_property(visual, "position:x", visual.position.x + 0.06, 0.06)
	t.tween_property(visual, "position:x", visual.position.x - 0.06, 0.06)
	for m in _mesh_materials:
		if m is StandardMaterial3D:
			t.parallel().tween_property(m, "albedo_color", _base_color, 0.12)

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

## Mueve la unidad al tile destino con animación de caminar.
func move_to_tile(target_pos: Vector3) -> void:
	if not alive:
		return
	var dest := target_pos + Vector3(0, 0.1, 0)
	_face_target(dest)

	# Intentar animación walk
	set_animation_state(AnimState.WALK)

	var move_tween := create_tween()
	move_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	var distance: float = global_position.distance_to(dest)
	var duration: float = clampf(distance / 3.0, 0.3, 1.5)
	move_tween.tween_property(self, "global_position", dest, duration)
	await move_tween.finished

	set_animation_state(AnimState.IDLE)


func attack_target(target: Unit, ability_index: int = 0) -> void:
	# Async action: approach (melee) o stay (ranged) -> attack anim -> resolve -> return.
	if not alive or not target or not target.alive:
		return

	set_animation_state(AnimState.NONE)
	set_selected(false)

	var ab: Dictionary = Unit.get_ability(self, ability_index)
	var is_melee: bool = ab.get("range", 99) <= 1
	var start_pos := global_position
	var start_rot := global_rotation

	_face_target(target.global_position)

	if is_melee:
		# Melee: acercarse al enemigo
		var approach := _approach_position(target)
		var t_move := create_tween()
		t_move.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t_move.tween_property(self, "global_position", approach, 0.35)
		await t_move.finished

	await _play_attack_animation(ability_index)

	_resolve_attack_damage(target, ability_index)

	if is_melee:
		# Solo volver si se acercó
		var t_back := create_tween()
		t_back.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
		t_back.tween_property(self, "global_position", start_pos, 0.35)
		await t_back.finished

	# Restore original rotation por el camino más corto (evita giro de 360° por Euler ±PI).
	var current_y := global_rotation.y
	var target_y := current_y + wrapf(start_rot.y - current_y, -PI, PI)
	var final_rot := Vector3(start_rot.x, target_y, start_rot.z)
	var t_rot := create_tween()
	t_rot.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t_rot.tween_property(self, "global_rotation", final_rot, 0.18)
	await t_rot.finished

	set_animation_state(AnimState.IDLE)

func _resolve_attack_damage(target: Unit, ability_index: int) -> void:
	if not stats or not target.stats:
		return
	var ab: Dictionary = Unit.get_ability(self, ability_index)
	if randf() < target.stats.evasion:
		target.show_floating_text("Esquive", Color.YELLOW)
		return
	if randf() > ab.get("hit_chance", 1.0):
		target.show_floating_text("Falló", Color(0.55, 0.55, 0.55))
		return
	var crit_mult: float = 2.0 if randf() < stats.crit_chance else 1.0
	var phys: int = int((stats.physical_damage + ab.get("physical", 0)) * crit_mult)
	var mag: int = int((stats.magic_damage + ab.get("magic", 0)) * crit_mult)
	var phys_taken: int = max(0, phys - target.stats.armor)
	var magic_taken: int = max(0, mag - target.stats.magic_resist)
	var phys_blocked: int = phys - phys_taken
	var magic_blocked: int = mag - magic_taken

	var v_offset: float = 0.0
	var line_height: float = 0.4
	var delay_step: float = 0.14
	var popup_delay: float = 0.0
	if crit_mult >= 2.0:
		target.show_floating_text("¡Crítico!", Color(1.0, 0.55, 0.0), v_offset, popup_delay)
		v_offset += line_height
		popup_delay += delay_step
	if phys_taken > 0:
		target.show_floating_text("-%d" % phys_taken, Color(1.0, 0.25, 0.25), v_offset, popup_delay)
		v_offset += line_height
		popup_delay += delay_step
	if magic_taken > 0:
		target.show_floating_text("-%d" % magic_taken, Color(0.75, 0.35, 1.0), v_offset, popup_delay)
		v_offset += line_height
		popup_delay += delay_step
	if phys_blocked > 0:
		target.show_floating_text("Armadura %d" % phys_blocked, Color(0.25, 0.5, 1.0), v_offset, popup_delay)
		v_offset += line_height
		popup_delay += delay_step
	if magic_blocked > 0:
		target.show_floating_text("Resist. %d" % magic_blocked, Color(0.2, 0.75, 1.0), v_offset, popup_delay)

	target.take_damage_split(phys_taken, magic_taken)

## Muestra un popup flotante sobre la unidad (esquive, daño, bloqueos, etc.).
## delay_sec: segundos antes de mostrar este popup (evita que se superpongan).
## DESACTIVADO temporalmente para testear FloatingHUD (barra de vida 3D).
func show_floating_text(text: String, text_color: Color, vertical_offset: float = 0.0, delay_sec: float = 0.0) -> void:
	return  # DESACTIVADO: texto flotante deshabilitado mientras se testea FloatingHUD
	if delay_sec > 0.0:
		var timer: SceneTreeTimer = get_tree().create_timer(delay_sec)
		timer.timeout.connect(_spawn_one_floating_text.bind(text, text_color, vertical_offset))
		return
	_spawn_one_floating_text(text, text_color, vertical_offset)

func _spawn_one_floating_text(text: String, text_color: Color, vertical_offset: float) -> void:
	var parent: Node = get_parent()
	if parent == null or not is_instance_valid(self):
		return
	var label: Label3D = Label3D.new()
	label.text = text
	label.modulate = text_color
	label.font_size = 16
	label.outline_size = 4
	label.outline_modulate = Color(0.0, 0.0, 0.0, 0.9)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.fixed_size = true
	label.no_depth_test = true
	parent.add_child(label)
	label.global_position = global_position + Vector3(0.0, 1.45 + vertical_offset, 0.0)

	var duration: float = 0.85
	var start_y: float = label.global_position.y
	var end_y: float = start_y + 0.7
	var start_mod: Color = text_color
	var end_mod: Color = Color(start_mod.r, start_mod.g, start_mod.b, 0.0)

	var t := create_tween()
	t.set_parallel(true)
	t.tween_method(func(v: float) -> void: label.global_position.y = lerpf(start_y, end_y, v), 0.0, 1.0, duration)
	t.tween_method(func(v: float) -> void: label.modulate = start_mod.lerp(end_mod, v), 0.0, 1.0, duration)
	t.set_parallel(false)
	t.tween_callback(label.queue_free)

## Reproduce la animación de ataque correspondiente al ability_index.
## Busca en _attack_anim_for_ability; fallback a "attack" (Interact genérico).
func _play_attack_animation(ability_index: int = 0) -> void:
	var ap: AnimationPlayer = _get_anim_ap()
	if not ap:
		await _fallback_attack_tween()
		return

	# Buscar animación específica para esta habilidad
	var anim_name: String = _attack_anim_for_ability.get(ability_index, "attack")
	if not ap.has_animation(anim_name):
		anim_name = "attack"  # Fallback a genérico (Interact)

	if ap.has_animation(anim_name):
		_stop_idle()
		_anim_state = AnimState.ATTACK
		ap.play(anim_name)
		await ap.animation_finished
	else:
		await _fallback_attack_tween()


## Fallback visual: squash + flash para unidades sin animación de ataque.
func _fallback_attack_tween() -> void:
	var t := create_tween()
	t.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(visual, "scale", Vector3(1.12, 0.88, 1.12), 0.12)
	t.tween_property(visual, "scale", Vector3.ONE, 0.12)
	for m in _mesh_materials:
		if m is StandardMaterial3D:
			t.parallel().tween_property(m, "albedo_color", _base_color.lightened(0.25), 0.10)
			t.parallel().tween_property(m, "albedo_color", _base_color, 0.20)
	await t.finished
