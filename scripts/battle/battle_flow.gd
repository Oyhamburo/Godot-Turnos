extends Node3D
class_name BattleFlow
##
## Precarga scripts para que las clases estén disponibles.
const _Board = preload("res://scripts/battle/board/battle_board.gd")
const _CameraRig = preload("res://scripts/battle/battle_camera_rig.gd")
## Máquina de estados del flujo de batalla.
## Orquesta tablero, cámara, unidades, HUD y sistema de turnos.
##

enum State {
	INTRO_PAN,
	COMBAT_START,
	UNIT_TURN,
	CHOOSING_ACTION,
	CHOOSING_ATTACK,
	CHOOSING_ITEM,
	ENEMY_TURN,
	ANIMATING,
	BATTLE_END
}

@export var battle_config: BattleConfig

@onready var board: BattleBoard = $BattleBoard
@onready var camera_rig: BattleCameraRig = $BattleCameraRig
@onready var units_container: Node3D = $Units
@onready var hud: BattleHUD = $BattleHUD

var _state: State = State.INTRO_PAN
var _spawned_units: Array[Node] = []
var _selected_tile: Tile = null

# Sistema de turnos
var _turn_order: Array = []          # Array de Unit, ordenado por speed
var _current_turn_index: int = 0
var _current_unit: Unit = null
var _selected_ability_index: int = 0


func _ready() -> void:
	print("[BattleFlow] _ready - iniciando batalla")
	var cfg: BattleConfig = battle_config
	# Priorizar BattleLauncher cuando el usuario eligió batalla desde el menú
	var launcher: Node = Engine.get_main_loop().root.get_node_or_null("BattleLauncher")
	if launcher and launcher.has_method("get_battle_config"):
		var launcher_cfg: BattleConfig = launcher.get_battle_config()
		if launcher_cfg:
			cfg = launcher_cfg
	if not cfg:
		cfg = battle_config
	if cfg:
		battle_config = cfg
		print("[BattleFlow] Estado: config cargado, configurando tablero %dx%d" % [battle_config.width, battle_config.height])
		_setup_board()
		_spawn_units()
		print("[BattleFlow] Estado: %d unidades spawneadas, iniciando INTRO_PAN" % _spawned_units.size())
	else:
		print("[BattleFlow] Estado: modo baked (sin config), recolectando unidades de escena")
		# Modo baked: usar tiles y unidades ya colocados por el Encounter Builder.
		if _use_baked_layout():
			_collect_baked_units()
		else:
			push_error("BattleFlow: BattleConfig no asignado y no hay contenido baked.")
			return

	# Conectar señales del HUD
	_connect_hud_signals()

	_start_intro_pan()


func _use_baked_layout() -> bool:
	var tiles_node: Node = board.get_node_or_null("Tiles")
	if not tiles_node or tiles_node.get_child_count() == 0:
		return false
	if not units_container or units_container.get_child_count() == 0:
		return true  # Tiles existentes, unidades vacías
	return true


func _collect_baked_units() -> void:
	_spawned_units.clear()
	if units_container:
		for child in units_container.get_children():
			if "Unit" in child.name or child.name.begins_with("Generated_"):
				_spawned_units.append(child)


func _setup_board() -> void:
	board.units_container = units_container
	board.setup(battle_config)


func _spawn_units() -> void:
	_spawned_units.clear()
	for entry in battle_config.spawns:
		if not entry is SpawnEntry:
			continue
		var se: SpawnEntry = entry as SpawnEntry
		if not se.unit_scene or not se.spawn_coords in board.tiles:
			continue
		var tile: Tile = board.get_tile_at(se.spawn_coords)
		if not tile or not tile.walkable:
			continue
		var unit: Node = board.spawn_unit(se.unit_scene, se.unit_data, se.spawn_coords, se.team)
		if unit:
			_spawned_units.append(unit)
	_apply_unit_facing()


func _apply_unit_facing() -> void:
	if _spawned_units.is_empty():
		return
	var unit_nodes: Array[Node3D] = []
	var unit_positions: Array[Vector3] = []
	var unit_teams: Array[String] = []
	for u in _spawned_units:
		if u is Node3D:
			unit_nodes.append(u)
			unit_positions.append(u.global_position)
			var team_str: String = "player"
			if "team" in u:
				var t = u.get("team")
				if t != null and int(t) == Unit.Team.ENEMY:
					team_str = "enemy"
			unit_teams.append(team_str)

	var player_positions: Array[Vector3] = []
	var enemy_positions: Array[Vector3] = []
	for i in range(unit_positions.size()):
		if unit_teams[i] == "player":
			player_positions.append(unit_positions[i])
		else:
			enemy_positions.append(unit_positions[i])

	var player_centroid: Vector3 = Vector3.ZERO
	if not player_positions.is_empty():
		for p in player_positions:
			player_centroid += p
		player_centroid /= float(player_positions.size())
	var enemy_centroid: Vector3 = Vector3.ZERO
	if not enemy_positions.is_empty():
		for p in enemy_positions:
			enemy_centroid += p
		enemy_centroid /= float(enemy_positions.size())

	var fixed_dir: Vector3 = battle_config.fixed_facing_dir
	if fixed_dir.length_squared() < 0.0001:
		fixed_dir = Vector3(0, 0, 1)
	fixed_dir = fixed_dir.normalized()

	for i in range(unit_nodes.size()):
		var unit: Node3D = unit_nodes[i]
		var pos: Vector3 = unit_positions[i]
		var team: String = unit_teams[i]
		var opponents: Array[Vector3] = enemy_positions if team == "player" else player_positions
		var target_pos: Vector3
		match battle_config.facing_mode:
			"look_at_opponent_centroid":
				if opponents.is_empty():
					target_pos = pos + fixed_dir
				else:
					target_pos = enemy_centroid if team == "player" else player_centroid
			"look_at_nearest_opponent":
				if opponents.is_empty():
					target_pos = pos + fixed_dir
				else:
					var nearest: Vector3 = opponents[0]
					var dmin: float = pos.distance_squared_to(nearest)
					for o in opponents:
						var d: float = pos.distance_squared_to(o)
						if d < dmin:
							dmin = d
							nearest = o
					target_pos = nearest
			"fixed":
				target_pos = pos + fixed_dir
			_:
				target_pos = pos + fixed_dir

		if target_pos.distance_squared_to(pos) > 0.0001:
			unit.look_at(target_pos, Vector3.UP)


# ── INTRO PAN ──────────────────────────────────────────────

func _start_intro_pan() -> void:
	_state = State.INTRO_PAN
	print("[BattleFlow] Estado: INTRO_PAN - cámara hacia overview del tablero")
	camera_rig.skip_requested.connect(_on_skip_requested, CONNECT_ONE_SHOT)

	if hud:
		hud.hide_hud()

	var center: Vector3 = board.get_board_center()
	var size: Vector2 = board.get_board_size()
	camera_rig.tween_to_overview(center, size, 1.5)
	await get_tree().create_timer(1.5).timeout

	if _state != State.INTRO_PAN:
		return

	# Focus en cada unidad: player primero, luego enemigos
	var player_units: Array[Node] = []
	var enemy_units: Array[Node] = []
	for u in _spawned_units:
		if "team" in u and u.get("team") == Unit.Team.PLAYER:
			player_units.append(u)
		else:
			enemy_units.append(u)

	for u in player_units:
		var focus_pos: Vector3 = u.global_position + Vector3(0, 1, 0)
		print("[BattleFlow] Estado: INTRO_PAN - cámara focus en jugador %s pos=%s" % [u.name, focus_pos])
		camera_rig.tween_to_focus(focus_pos, 0.8)
		await get_tree().create_timer(0.8).timeout
		if _state != State.INTRO_PAN:
			return

	for u in enemy_units:
		var focus_pos: Vector3 = u.global_position + Vector3(0, 1, 0)
		print("[BattleFlow] Estado: INTRO_PAN - cámara focus en enemigo %s pos=%s" % [u.name, focus_pos])
		camera_rig.tween_to_focus(focus_pos, 0.8)
		await get_tree().create_timer(0.8).timeout
		if _state != State.INTRO_PAN:
			return

	_transition_to_combat_start()


func _on_skip_requested() -> void:
	if _state == State.INTRO_PAN:
		camera_rig.cancel_tween()
		_transition_to_combat_start()


# ── COMBAT START ───────────────────────────────────────────

func _transition_to_combat_start() -> void:
	_state = State.COMBAT_START
	print("[BattleFlow] Estado: COMBAT_START - construyendo orden de turnos")
	_build_turn_order()
	_current_turn_index = 0

	# Conectar señal de muerte para rebuild de turnos
	for u in _spawned_units:
		if u is Unit and not u.died.is_connected(_on_unit_died):
			u.died.connect(_on_unit_died)

	# Mantener tile selection para debug (tecla T)
	_setup_tile_selection()

	_start_next_turn()


## Construye el orden de turnos por velocidad descendente.
## Tie-break: players van primero.
func _build_turn_order() -> void:
	_turn_order.clear()
	for u in _spawned_units:
		if u is Unit and u.alive:
			_turn_order.append(u)

	_turn_order.sort_custom(func(a: Unit, b: Unit) -> bool:
		var speed_a: int = a.stats.speed if a.stats else 0
		var speed_b: int = b.stats.speed if b.stats else 0
		if speed_a != speed_b:
			return speed_a > speed_b  # Mayor speed primero
		# Tie-break: player antes que enemy
		return a.team < b.team
	)

	var order_str: String = ""
	for i in range(_turn_order.size()):
		var u: Unit = _turn_order[i]
		var spd: int = u.stats.speed if u.stats else 0
		order_str += "%s(spd:%d) " % [u.display_name, spd]
	print("[BattleFlow] Orden de turnos: %s" % order_str.strip_edges())


# ── TURN SYSTEM ────────────────────────────────────────────

func _start_next_turn() -> void:
	# Buscar siguiente unidad viva
	var attempts: int = 0
	while attempts < _turn_order.size():
		if _current_turn_index >= _turn_order.size():
			_current_turn_index = 0
		_current_unit = _turn_order[_current_turn_index] as Unit
		if _current_unit and _current_unit.alive:
			break
		_current_turn_index += 1
		attempts += 1

	if not _current_unit or not _current_unit.alive:
		_check_battle_end()
		return

	# Actualizar HUD
	if hud:
		hud.update_timeline(_turn_order, _current_turn_index)
		hud.show_turn_label(_current_unit.display_name)

	print("[BattleFlow] ─── Turno: %s (speed: %d, team: %s) ───" % [
		_current_unit.display_name,
		_current_unit.stats.speed if _current_unit.stats else 0,
		"PLAYER" if _current_unit.team == Unit.Team.PLAYER else "ENEMY"
	])

	if _current_unit.team == Unit.Team.PLAYER:
		_start_player_turn()
	else:
		_start_enemy_turn()


func _start_player_turn() -> void:
	_state = State.CHOOSING_ACTION
	print("[BattleFlow] Estado: CHOOSING_ACTION - mostrando menú de acciones")

	# Cámara enfoca al personaje con ángulo lateral para menú
	camera_rig.tween_to_action_view(_current_unit.global_position)

	# Mostrar menú de acciones
	if hud:
		hud.show_action_menu()


func _start_enemy_turn() -> void:
	_state = State.ENEMY_TURN
	print("[BattleFlow] Estado: ENEMY_TURN - %s ataca automáticamente" % _current_unit.display_name)

	if hud:
		hud.hide_all_menus()

	# Cámara enfoca al enemigo
	camera_rig.tween_to_focus(_current_unit.global_position + Vector3(0, 1, 0), 0.5)
	await get_tree().create_timer(0.6).timeout

	if _state != State.ENEMY_TURN:
		return

	# Auto-seleccionar target: player vivo aleatorio
	var alive_players: Array[Unit] = []
	for u in _turn_order:
		if u is Unit and u.alive and u.team == Unit.Team.PLAYER:
			alive_players.append(u)

	if alive_players.is_empty():
		_check_battle_end()
		return

	var target: Unit = alive_players[randi() % alive_players.size()]
	var ability_idx: int = randi() % 4

	print("[BattleFlow] Enemigo %s ataca a %s con ataque %d" % [
		_current_unit.display_name, target.display_name, ability_idx
	])

	_state = State.ANIMATING
	await _current_unit.attack_target(target, ability_idx)

	# Pequeña pausa después del ataque
	await get_tree().create_timer(0.3).timeout

	_advance_turn()


# ── HUD SIGNALS ────────────────────────────────────────────

func _connect_hud_signals() -> void:
	if not hud:
		push_warning("[BattleFlow] BattleHUD no encontrado, HUD deshabilitado")
		return
	hud.action_selected.connect(_on_hud_action_selected)
	hud.attack_selected.connect(_on_hud_attack_selected)
	hud.item_selected.connect(_on_hud_item_selected)
	hud.back_from_attack.connect(_on_hud_back_from_attack)
	hud.back_from_item.connect(_on_hud_back_from_item)
	print("[BattleFlow] Señales del HUD conectadas")


func _on_hud_action_selected(action: String) -> void:
	if _state != State.CHOOSING_ACTION:
		return

	match action:
		"attack":
			_state = State.CHOOSING_ATTACK
			print("[BattleFlow] Estado: CHOOSING_ATTACK - mostrando ataques")
			camera_rig.tween_to_attack_view(_current_unit.global_position)
			if hud:
				hud.show_attack_menu(_current_unit)

		"item":
			_state = State.CHOOSING_ITEM
			print("[BattleFlow] Estado: CHOOSING_ITEM - mostrando ítems")
			camera_rig.tween_to_item_view(_current_unit.global_position)
			if hud:
				hud.show_item_menu()

		"exit":
			print("[BattleFlow] Saliendo al menú principal...")
			get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")


func _on_hud_attack_selected(index: int) -> void:
	if _state != State.CHOOSING_ATTACK:
		return

	_selected_ability_index = index
	var ab: Dictionary = Unit.get_ability(_current_unit, index)
	print("[BattleFlow] ► Ataque %d seleccionado por %s: phys=%d mag=%d hit=%.0f%%" % [
		index,
		_current_unit.display_name,
		ab.get("physical", 0),
		ab.get("magic", 0),
		ab.get("hit_chance", 1.0) * 100.0
	])

	# Placeholder: auto-seleccionar primer enemigo vivo como target
	var alive_enemies: Array[Unit] = []
	for u in _turn_order:
		if u is Unit and u.alive and u.team == Unit.Team.ENEMY:
			alive_enemies.append(u)

	if alive_enemies.is_empty():
		print("[BattleFlow] No hay enemigos vivos!")
		_check_battle_end()
		return

	var target: Unit = alive_enemies[0]
	print("[BattleFlow] Target auto-seleccionado: %s" % target.display_name)

	# Ejecutar ataque
	_state = State.ANIMATING
	if hud:
		hud.hide_all_menus()

	await _current_unit.attack_target(target, _selected_ability_index)

	# Pequeña pausa después del ataque
	await get_tree().create_timer(0.3).timeout

	_advance_turn()


func _on_hud_item_selected(index: int) -> void:
	if _state != State.CHOOSING_ITEM:
		return

	print("[BattleFlow] ► Item %d seleccionado (placeholder - no hace nada)" % index)
	# Placeholder: los ítems no hacen nada por ahora, vuelve al menú de acciones
	_state = State.CHOOSING_ACTION
	camera_rig.tween_to_action_view(_current_unit.global_position)
	if hud:
		hud.show_action_menu()


func _on_hud_back_from_attack() -> void:
	if _state != State.CHOOSING_ATTACK:
		return
	print("[BattleFlow] Volviendo al menú de acciones desde ataques")
	_state = State.CHOOSING_ACTION
	camera_rig.tween_to_action_view(_current_unit.global_position)
	if hud:
		hud.show_action_menu()


func _on_hud_back_from_item() -> void:
	if _state != State.CHOOSING_ITEM:
		return
	print("[BattleFlow] Volviendo al menú de acciones desde ítems")
	_state = State.CHOOSING_ACTION
	camera_rig.tween_to_action_view(_current_unit.global_position)
	if hud:
		hud.show_action_menu()


# ── ADVANCE / END ──────────────────────────────────────────

func _advance_turn() -> void:
	# Chequear si la batalla terminó
	if _check_battle_end():
		return

	_current_turn_index += 1
	if _current_turn_index >= _turn_order.size():
		_current_turn_index = 0
		print("[BattleFlow] ═══ Nueva ronda de turnos ═══")

	_start_next_turn()


func _on_unit_died(unit: Unit) -> void:
	print("[BattleFlow] Unidad muerta: %s - reconstruyendo turnos" % unit.display_name)
	# Remover de la lista de turnos
	var idx: int = _turn_order.find(unit)
	if idx >= 0:
		_turn_order.remove_at(idx)
		# Ajustar el índice si la unidad removida estaba antes del turno actual
		if idx < _current_turn_index:
			_current_turn_index -= 1
		elif idx == _current_turn_index:
			# La unidad del turno actual murió, decrementar para que _advance_turn lo suba
			_current_turn_index -= 1

	# Actualizar timeline
	if hud:
		hud.update_timeline(_turn_order, _current_turn_index)


func _check_battle_end() -> bool:
	var players_alive: int = 0
	var enemies_alive: int = 0
	for u in _turn_order:
		if u is Unit and u.alive:
			if u.team == Unit.Team.PLAYER:
				players_alive += 1
			else:
				enemies_alive += 1

	if players_alive == 0:
		_state = State.BATTLE_END
		print("[BattleFlow] ══════════════════════════════")
		print("[BattleFlow] BATALLA TERMINADA - DERROTA")
		print("[BattleFlow] ══════════════════════════════")
		if hud:
			hud.hide_all_menus()
			hud.show_turn_label("DERROTA")
		return true

	if enemies_alive == 0:
		_state = State.BATTLE_END
		print("[BattleFlow] ══════════════════════════════")
		print("[BattleFlow] BATALLA TERMINADA - VICTORIA")
		print("[BattleFlow] ══════════════════════════════")
		if hud:
			hud.hide_all_menus()
			hud.show_turn_label("VICTORIA!")
		return true

	return false


# ── LEGACY: tile selection (mantener para debug con T) ─────

func _setup_tile_selection() -> void:
	if not board.tile_selected.is_connected(_on_tile_selected):
		board.tile_selected.connect(_on_tile_selected)


func _on_tile_selected(tile: Tile) -> void:
	_selected_tile = tile


func _input(event: InputEvent) -> void:
	# Test damage: tecla T aplica 5 de daño físico a la unidad del tile seleccionado
	if event is InputEventKey and event.pressed and event.keycode == KEY_T:
		if _selected_tile and _selected_tile.occupied_by is Unit:
			var unit: Unit = _selected_tile.occupied_by as Unit
			if unit.stats:
				unit.stats.apply_damage_physical(5)
		return

	# Raycast para selección de tile por click (solo para debug de daño con T)
	if not event is InputEventMouseButton or not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
		return
	# Solo permitir selección de tiles en estados que no son de menú
	if _state in [State.CHOOSING_ACTION, State.CHOOSING_ATTACK, State.CHOOSING_ITEM]:
		return

	var camera: Camera3D = get_viewport().get_camera_3d()
	if not camera:
		return

	var from: Vector3 = camera.project_ray_origin(event.position)
	var to: Vector3 = from + camera.project_ray_normal(event.position) * 1000.0

	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 4  # Layer de Area3D de los tiles

	var result: Dictionary = space_state.intersect_ray(query)
	if result.is_empty():
		board.clear_selection()
		_selected_tile = null
		return

	var collider: Object = result.collider
	if collider is CollisionObject3D:
		var area_parent: Node = collider.get_parent()
		if area_parent is Area3D:
			var tile: Node = area_parent.get_parent()
			if tile is Tile:
				tile.tile_clicked.emit(tile)
