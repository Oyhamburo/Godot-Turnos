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
@export var enemy_scene: PackedScene
@export var players_count: int = 3
@export var enemies_count: int = 3
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
	var units_container: Node3D = get_node(units_container_path)
	players.clear()
	enemies.clear()

	# Formation settings (XZ plane)
	var px := [-2.2, 0.0, 2.2]
	var ex := [-2.2, 0.0, 2.2]
	var pz := 2.5
	var ez := -2.5

	for i in range(players_count):
		var u: Unit = player_scene.instantiate()
		u.display_name = "Player %d" % (i + 1)
		u.max_hp = 34
		u.hp = u.max_hp
		u.speed = 12 - i # slight variation
		u.attack = 9
		u.connect("died", Callable(self, "_on_unit_died"))
		units_container.add_child(u)
		u.global_position = Vector3(px[i % px.size()], 0.6, pz + float(i) / float(px.size()) * 1.8)
		u.reset_start_pose()
		players.append(u)

	for i in range(enemies_count):
		var u: Unit = enemy_scene.instantiate()
		u.display_name = "Enemy %d" % (i + 1)
		u.max_hp = 28
		u.hp = u.max_hp
		u.speed = 11 - i
		u.attack = 8
		u.connect("died", Callable(self, "_on_unit_died"))
		units_container.add_child(u)
		u.global_position = Vector3(ex[i % ex.size()], 0.6, ez - float(i) / float(ex.size()) * 1.8)
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
		if u and u.alive: out.append(u)
	for u in enemies:
		if u and u.alive: out.append(u)
	return out

func _get_current_unit() -> Unit:
	if turn_order.is_empty():
		return null
	if turn_index < 0 or turn_index >= turn_order.size():
		turn_index = 0
	var u := turn_order[turn_index]
	if u and u.alive:
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
		if p and p.alive:
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
		if u and u.alive:
			return false
	return true

func _cleanup_dead_from_order() -> void:
	# Remove dead units from turn order (keeps timeline correct).
	var current := _get_current_unit()
	var new_order: Array[Unit] = []
	for u in turn_order:
		if u and u.alive:
			new_order.append(u)
	turn_order = new_order

	# Fix index: keep pointing to the same current unit when possible.
	if current and current.alive:
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
