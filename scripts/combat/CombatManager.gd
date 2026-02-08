extends Node
class_name CombatManager

signal units_spawned(players, enemies)
signal timeline_updated(order, current)
signal turn_changed(current)
signal state_changed(state)
signal unit_died(unit)
signal battle_ended(player_won: bool)

enum State { INIT, SELECTING_TARGET, ANIMATING, ENDED }

@export_group("Caballero")
@export var player_knight_count: int = 0
@export var player_knight_scene: PackedScene
@export var player_knight_data: UnitData
@export_group("Mago")
@export var player_mage_count: int = 0
@export var player_mage_scene: PackedScene
@export var player_mage_data: UnitData
@export_group("Ranger")
@export var player_ranger_count: int = 0
@export var player_ranger_scene: PackedScene
@export var player_ranger_data: UnitData
@export_group("Pícaro")
@export var player_rogue_count: int = 0
@export var player_rogue_scene: PackedScene
@export var player_rogue_data: UnitData
@export_group("Bárbaro")
@export var player_barbarian_count: int = 0
@export var player_barbarian_scene: PackedScene
@export var player_barbarian_data: UnitData
@export_group("Pícaro con capucha")
@export var player_rogue_hooded_count: int = 0
@export var player_rogue_hooded_scene: PackedScene
@export var player_rogue_hooded_data: UnitData
@export_group("Esqueleto Guerrero")
@export var enemy_skeleton_warrior_count: int = 0
@export var enemy_skeleton_warrior_scene: PackedScene
@export var enemy_skeleton_warrior_data: UnitData
@export_group("Esqueleto Mago")
@export var enemy_skeleton_mage_count: int = 0
@export var enemy_skeleton_mage_scene: PackedScene
@export var enemy_skeleton_mage_data: UnitData
@export_group("Esqueleto Minion")
@export var enemy_skeleton_minion_count: int = 0
@export var enemy_skeleton_minion_scene: PackedScene
@export var enemy_skeleton_minion_data: UnitData
@export_group("Esqueleto Pícaro")
@export var enemy_skeleton_rogue_count: int = 0
@export var enemy_skeleton_rogue_scene: PackedScene
@export var enemy_skeleton_rogue_data: UnitData
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
	var p_knight_count: int = cfg.player_knight_count if cfg else player_knight_count
	var p_knight_scene: PackedScene = cfg.player_knight_scene if cfg else player_knight_scene
	var p_knight_data: UnitData = cfg.player_knight_data if cfg else player_knight_data
	var p_mage_count: int = cfg.player_mage_count if cfg else player_mage_count
	var p_mage_scene: PackedScene = cfg.player_mage_scene if cfg else player_mage_scene
	var p_mage_data: UnitData = cfg.player_mage_data if cfg else player_mage_data
	var p_ranger_count: int = cfg.player_ranger_count if cfg else player_ranger_count
	var p_ranger_scene: PackedScene = cfg.player_ranger_scene if cfg else player_ranger_scene
	var p_ranger_data: UnitData = cfg.player_ranger_data if cfg else player_ranger_data
	var p_rogue_count: int = cfg.player_rogue_count if cfg else player_rogue_count
	var p_rogue_scene: PackedScene = cfg.player_rogue_scene if cfg else player_rogue_scene
	var p_rogue_data: UnitData = cfg.player_rogue_data if cfg else player_rogue_data
	var p_barbarian_count: int = cfg.player_barbarian_count if cfg else player_barbarian_count
	var p_barbarian_scene: PackedScene = cfg.player_barbarian_scene if cfg else player_barbarian_scene
	var p_barbarian_data: UnitData = cfg.player_barbarian_data if cfg else player_barbarian_data
	var p_rogue_hooded_count: int = cfg.player_rogue_hooded_count if cfg else player_rogue_hooded_count
	var p_rogue_hooded_scene: PackedScene = cfg.player_rogue_hooded_scene if cfg else player_rogue_hooded_scene
	var p_rogue_hooded_data: UnitData = cfg.player_rogue_hooded_data if cfg else player_rogue_hooded_data
	var e_warrior_count: int = cfg.enemy_skeleton_warrior_count if cfg else enemy_skeleton_warrior_count
	var e_warrior_scene: PackedScene = cfg.enemy_skeleton_warrior_scene if cfg else enemy_skeleton_warrior_scene
	var e_warrior_data: UnitData = cfg.enemy_skeleton_warrior_data if cfg else enemy_skeleton_warrior_data
	var e_mage_count: int = cfg.enemy_skeleton_mage_count if cfg else enemy_skeleton_mage_count
	var e_mage_scene: PackedScene = cfg.enemy_skeleton_mage_scene if cfg else enemy_skeleton_mage_scene
	var e_mage_data: UnitData = cfg.enemy_skeleton_mage_data if cfg else enemy_skeleton_mage_data
	var e_minion_count: int = cfg.enemy_skeleton_minion_count if cfg else enemy_skeleton_minion_count
	var e_minion_scene: PackedScene = cfg.enemy_skeleton_minion_scene if cfg else enemy_skeleton_minion_scene
	var e_minion_data: UnitData = cfg.enemy_skeleton_minion_data if cfg else enemy_skeleton_minion_data
	var e_rogue_count: int = cfg.enemy_skeleton_rogue_count if cfg else enemy_skeleton_rogue_count
	var e_rogue_scene: PackedScene = cfg.enemy_skeleton_rogue_scene if cfg else enemy_skeleton_rogue_scene
	var e_rogue_data: UnitData = cfg.enemy_skeleton_rogue_data if cfg else enemy_skeleton_rogue_data
	if cfg:
		BattleManager.clear_battle()

	players.clear()
	enemies.clear()

	const UNIT_SPAWN_Y := 0.6
	var px := [-2.2, 0.0, 2.2]
	var ex := [-2.2, 0.0, 2.2]
	var pz := 2.5
	var ez := -2.5

	var player_spawns: Array[Dictionary] = []
	for _i in range(p_knight_count):
		player_spawns.append({"scene": p_knight_scene, "data": p_knight_data})
	for _i in range(p_mage_count):
		player_spawns.append({"scene": p_mage_scene, "data": p_mage_data})
	for _i in range(p_ranger_count):
		player_spawns.append({"scene": p_ranger_scene, "data": p_ranger_data})
	for _i in range(p_rogue_count):
		player_spawns.append({"scene": p_rogue_scene, "data": p_rogue_data})
	for _i in range(p_barbarian_count):
		player_spawns.append({"scene": p_barbarian_scene, "data": p_barbarian_data})
	for _i in range(p_rogue_hooded_count):
		player_spawns.append({"scene": p_rogue_hooded_scene, "data": p_rogue_hooded_data})

	for i in range(player_spawns.size()):
		var entry: Dictionary = player_spawns[i]
		var p_scene: PackedScene = entry.scene
		var p_data: UnitData = entry.data
		if p_scene == null:
			push_warning("CombatManager: escena de jugador no asignada en el spawn %d. Saltando." % i)
			continue
		var u: Unit = p_scene.instantiate() as Unit
		if u == null:
			continue
		if p_data:
			u.data = p_data
		else:
			u.display_name = "Player %d" % (i + 1)
			u.max_hp = 34
			u.hp = u.max_hp
			u.speed = 12 - i
			u.attack = 9
		u.connect("died", Callable(self, "_on_unit_died"))
		units_container.add_child(u)
		u.global_position = Vector3(px[i % px.size()], UNIT_SPAWN_Y, pz + float(i) / float(px.size()) * 1.8)
		u.reset_start_pose()
		players.append(u)

	var enemy_colors := [Color(1, 0.35, 0.45), Color(0.9, 0.5, 0.2), Color(0.7, 0.35, 0.9), Color(0.3, 0.75, 0.5), Color(0.4, 0.6, 1.0)]
	var spawns: Array[Dictionary] = []
	for _i in range(e_warrior_count):
		spawns.append({"scene": e_warrior_scene, "data": e_warrior_data})
	for _i in range(e_mage_count):
		spawns.append({"scene": e_mage_scene, "data": e_mage_data})
	for _i in range(e_minion_count):
		spawns.append({"scene": e_minion_scene, "data": e_minion_data})
	for _i in range(e_rogue_count):
		spawns.append({"scene": e_rogue_scene, "data": e_rogue_data})
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
		# Enemigos miran hacia el lado de los jugadores (Z positivo) para no quedar de espalda.
		var look_target := Vector3(0.0, UNIT_SPAWN_Y, pz)
		u.look_at(look_target, Vector3.UP)
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

func player_attack(attacker: Unit, target: Unit, ability_index: int = 0) -> void:
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
	await _resolve_attack(attacker, target, ability_index)

func player_pass() -> void:
	if state != State.SELECTING_TARGET:
		return
	_end_turn()

func _enemy_take_turn(attacker: Unit) -> void:
	var target := _pick_enemy_target()
	if target == null:
		_end_battle(false)
		return
	var ability_index: int = randi() % 4
	await _resolve_attack(attacker, target, ability_index)

func _pick_enemy_target() -> Unit:
	# Simple AI: pick alive player with lowest HP (deterministic).
	var best: Unit = null
	for p in players:
		if is_instance_valid(p) and p.alive:
			if best == null or p.hp < best.hp:
				best = p
	return best

func _resolve_attack(attacker: Unit, target: Unit, ability_index: int = 0) -> void:
	if attacker == null or target == null:
		_end_turn()
		return

	await attacker.attack_target(target, ability_index)

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
