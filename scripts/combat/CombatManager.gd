extends Node
class_name CombatManager

signal units_spawned(players, enemies)
signal timeline_updated(order, current)
signal turn_changed(current)
signal state_changed(state)
signal unit_died(unit)
signal battle_ended(player_won: bool)

enum State { INIT, SELECTING_TARGET, ANIMATING, ENDED }

@export var player_scene: PackedScene
@export_group("Enemigos Bruto")
@export var enemy_bruto_count: int = 2
@export var enemy_bruto_scene: PackedScene
@export var enemy_bruto_data: UnitData
@export_group("Enemigos Esqueleto")
@export var enemy_skeleton_count: int = 2
@export var enemy_skeleton_scene: PackedScene
@export var enemy_skeleton_data: UnitData
@export_group("Enemigos comunes")
@export var enemy_common_count: int = 1
@export var enemy_common_scene: PackedScene
@export var players_count: int = 1
@export var units_container_path: NodePath = NodePath("../Units")

var players: Array[Unit] = []
var enemies: Array[Unit] = []
var turn_order: Array[Unit] = []
var turn_index: int = 0
var state: int = State.INIT
var _started: bool = false

func _ready() -> void:
	_spawn_units()
	_build_turn_order()
	# Defer first turn so UI can connect to signals.
	call_deferred("_start_if_needed")

func _start_if_needed() -> void:
	if _started:
		return
	_started = true
	_emit_full_refresh()
	_next_turn()

func request_ui_refresh() -> void:
	_emit_full_refresh()

func _emit_full_refresh() -> void:
	var current := _get_current_unit()
	emit_signal("units_spawned", players, enemies)
	emit_signal("timeline_updated", turn_order, current)
	if current:
		emit_signal("turn_changed", current)

func _spawn_units() -> void:
	var units_container: Node3D = get_node_or_null(units_container_path) as Node3D
	if units_container == null:
		push_error("CombatManager: units_container_path inválido o nodo no encontrado: %s" % str(units_container_path))
		return

	# Usar BattleConfig del menú si existe; si no, usar @export del Inspector.
	var cfg: BattleConfig = BattleManager.current_battle_config
	var p_scene: PackedScene = cfg.player_scene if cfg else player_scene
	var p_count: int = cfg.players_count if cfg else players_count
	var e_bruto_count: int = cfg.enemy_bruto_count if cfg else enemy_bruto_count
	var e_bruto_scene: PackedScene = cfg.enemy_bruto_scene if cfg else enemy_bruto_scene
	var e_bruto_data: UnitData = cfg.enemy_bruto_data if cfg else enemy_bruto_data
	var e_common_count: int = cfg.enemy_common_count if cfg else enemy_common_count
	var e_common_scene: PackedScene = cfg.enemy_common_scene if cfg else enemy_common_scene
	var e_skeleton_count: int = cfg.enemy_skeleton_count if cfg else enemy_skeleton_count
	var e_skeleton_scene: PackedScene = cfg.enemy_skeleton_scene if cfg else enemy_skeleton_scene
	var e_skeleton_data: UnitData = cfg.enemy_skeleton_data if cfg else enemy_skeleton_data
	if cfg:
		BattleManager.clear_battle()

	if p_scene == null:
		push_error("CombatManager: player_scene no asignado (ni en BattleConfig ni en Inspector).")
		return
	players.clear()
	enemies.clear()

	# Formation settings (XZ plane). Superficie del piso en y=0; origen del personaje ~0.6 arriba.
	const UNIT_SPAWN_Y := 0.6
	var px := [-2.2, 0.0, 2.2]
	var ex := [-2.2, 0.0, 2.2]
	var pz := 2.5
	var ez := -2.5

	for i in range(p_count):
		var u: Unit = p_scene.instantiate() as Unit
		if u == null:
			continue
		u.display_name = "Player %d" % (i + 1)
		u.max_hp = 34
		u.hp = u.max_hp
		u.speed = 12 - i # slight variation
		u.attack = 9
		u.connect("died", Callable(self, "_on_unit_died"))
		units_container.add_child(u)
		u.global_position = Vector3(px[i % px.size()], UNIT_SPAWN_Y, pz + float(i) / float(px.size()) * 1.8)
		u.reset_start_pose()
		players.append(u)

	var enemy_colors := [Color(1, 0.35, 0.45), Color(0.9, 0.5, 0.2), Color(0.7, 0.35, 0.9), Color(0.3, 0.75, 0.5), Color(0.4, 0.6, 1.0)]
	var spawns: Array[Dictionary] = []
	for _i in range(e_bruto_count):
		spawns.append({"scene": e_bruto_scene, "data": e_bruto_data})
	for _i in range(e_common_count):
		spawns.append({"scene": e_common_scene, "data": null})
	for _i in range(e_skeleton_count):
		spawns.append({"scene": e_skeleton_scene, "data": e_skeleton_data})
	for i in range(spawns.size()):
		var entry: Dictionary = spawns[i]
		var scene: PackedScene = entry.scene
		var data: UnitData = entry.data
		if scene == null:
			push_warning("CombatManager: escena de enemigo no asignada en el spawn %d. Saltando." % i)
			continue
		var u: Unit = scene.instantiate() as Unit
		if u == null:
			continue
		if data:
			u.data = data
		else:
			u.display_name = "Enemy %d" % (i + 1)
			u.max_hp = 28
			u.hp = u.max_hp
			u.speed = 11 - i
			u.attack = 8
		u.connect("died", Callable(self, "_on_unit_died"))
		units_container.add_child(u)
		if not data:
			u.color = enemy_colors[i % enemy_colors.size()]
			u.refresh_visual_color()
		u.global_position = Vector3(ex[i % ex.size()], UNIT_SPAWN_Y, ez - float(i) / float(ex.size()) * 1.8)
		u.reset_start_pose()
		enemies.append(u)

func _build_turn_order() -> void:
	turn_order = _get_alive_units()
	turn_order.sort_custom(Callable(self, "_sort_initiative"))
	turn_index = 0

func _sort_initiative(a: Unit, b: Unit) -> bool:
	# Higher speed first. Tie-break: PLAYER first. Then stable by instance_id.
	if a.speed != b.speed:
		return a.speed > b.speed
	if a.team != b.team:
		return a.team == Unit.Team.PLAYER
	return a.get_instance_id() < b.get_instance_id()

func _get_alive_units() -> Array[Unit]:
	var out: Array[Unit] = []
	for u in players:
		if is_instance_valid(u) and u.alive:
			out.append(u)
	for u in enemies:
		if is_instance_valid(u) and u.alive:
			out.append(u)
	return out

func _get_current_unit() -> Unit:
	if turn_order.is_empty():
		return null
	if turn_index < 0 or turn_index >= turn_order.size():
		turn_index = 0
	var u := turn_order[turn_index]
	if is_instance_valid(u) and u.alive:
		return u
	return null

func _advance_index() -> void:
	if turn_order.is_empty():
		return
	turn_index = (turn_index + 1) % turn_order.size()

func _next_turn() -> void:
	if state == State.ENDED:
		return

	_cleanup_dead_from_order()

	if turn_order.is_empty():
		_end_battle(true)
		return

	var current := _get_current_unit()
	# If current is dead (edge cases), skip.
	var safety := 0
	while current == null and safety < 64:
		_advance_index()
		current = _get_current_unit()
		safety += 1

	if current == null:
		_end_battle(true)
		return

	emit_signal("timeline_updated", turn_order, current)
	emit_signal("turn_changed", current)

	if current.team == Unit.Team.PLAYER:
		state = State.SELECTING_TARGET
		emit_signal("state_changed", state)
	else:
		state = State.ANIMATING
		emit_signal("state_changed", state)
		await _enemy_take_turn(current)

func player_attack(attacker: Unit, target: Unit) -> void:
	# Called by UI during player's turn.
	if state != State.SELECTING_TARGET:
		return
	if attacker == null or target == null:
		return
	if not attacker.alive or not target.alive:
		return
	if attacker.team != Unit.Team.PLAYER:
		return
	if target.team != Unit.Team.ENEMY:
		return

	state = State.ANIMATING
	emit_signal("state_changed", state)
	await _resolve_attack(attacker, target)

func player_pass() -> void:
	if state != State.SELECTING_TARGET:
		return
	_end_turn()

func _enemy_take_turn(attacker: Unit) -> void:
	var target := _pick_enemy_target()
	if target == null:
		_end_battle(false)
		return
	await _resolve_attack(attacker, target)

func _pick_enemy_target() -> Unit:
	# Simple AI: pick alive player with lowest HP (deterministic).
	var best: Unit = null
	for p in players:
		if is_instance_valid(p) and p.alive:
			if best == null or p.hp < best.hp:
				best = p
	return best

func _resolve_attack(attacker: Unit, target: Unit) -> void:
	if attacker == null or target == null:
		_end_turn()
		return

	await attacker.attack_target(target)

	# Check battle end after action finishes.
	if _are_all_dead(enemies):
		_end_battle(true)
		return
	if _are_all_dead(players):
		_end_battle(false)
		return

	_end_turn()

func _end_turn() -> void:
	_advance_index()
	state = State.INIT
	emit_signal("state_changed", state)
	_next_turn()

func _are_all_dead(arr: Array[Unit]) -> bool:
	for u in arr:
		if is_instance_valid(u) and u.alive:
			return false
	return true

func _cleanup_dead_from_order() -> void:
	# Remove dead units from turn order (keeps timeline correct).
	var current := _get_current_unit()
	var new_order: Array[Unit] = []
	for u in turn_order:
		if is_instance_valid(u) and u.alive:
			new_order.append(u)
	turn_order = new_order

	# Fix index: keep pointing to the same current unit when possible.
	if is_instance_valid(current) and current.alive:
		turn_index = turn_order.find(current)
		if turn_index == -1:
			turn_index = 0
	else:
		turn_index = clamp(turn_index, 0, max(turn_order.size() - 1, 0))

func _on_unit_died(unit: Unit) -> void:
	emit_signal("unit_died", unit)
	_cleanup_dead_from_order()
	emit_signal("timeline_updated", turn_order, _get_current_unit())

func _end_battle(player_won: bool) -> void:
	state = State.ENDED
	emit_signal("state_changed", state)
	emit_signal("battle_ended", player_won)
