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
	CHOOSING_TARGET,
	CHOOSING_ITEM,
	CHOOSING_EQUIPO,
	CHOOSING_MOVE,
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

# Sistema de movimiento
var _valid_move_tiles: Array[Vector2i] = []
var _hovered_tile: Tile = null

# Sistema de selección de objetivo
var _valid_target_tiles: Array[Vector2i] = []


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
	_current_unit._blocking = false  # La guardia baja al empezar tu propio turno
	_current_unit.stats.reset_turn_actions()
	print("[BattleFlow] Estado: CHOOSING_ACTION - mostrando menú de acciones (AP:%d SP:%d)" % [
		_current_unit.stats.current_ap, _current_unit.stats.current_sp
	])

	# Cámara enfoca al personaje con ángulo lateral para menú
	camera_rig.tween_to_action_view(_current_unit.global_position)

	# Mostrar menú de acciones
	if hud:
		hud.show_action_menu()
		_update_hud_actions()


func _start_enemy_turn() -> void:
	_state = State.ENEMY_TURN
	_current_unit._blocking = false  # La guardia baja al empezar el turno
	_current_unit.stats.reset_turn_actions()  # Resetear AP/SP para que pueda atacar y moverse
	print("[BattleFlow] Estado: ENEMY_TURN - %s actúa (AP:%d SP:%d)" % [
		_current_unit.display_name,
		_current_unit.stats.current_ap,
		_current_unit.stats.current_sp
	])

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

	# Seleccionar habilidad respetando rango
	var attacker_coord: Vector2i = board.get_coords_for_unit(_current_unit)
	var has_adjacent: bool = _has_adjacent_player(_current_unit)

	# Construir lista de habilidades válidas (que tengan target en rango, excluyendo defensivas)
	var all_enemy_abilities: Array[Dictionary] = Unit.get_all_abilities(_current_unit)
	var ability_count: int = maxi(1, all_enemy_abilities.size())

	var valid_abilities: Array[int] = []
	for i in range(ability_count):
		var ab: Dictionary = Unit.get_ability(_current_unit, i)
		# Excluir habilidades defensivas como "block_next" (Defender)
		if ab.get("effect", "") != "":
			continue
		var atk_range: int = ab.get("range", 99)
		var check_target: Unit = _find_player_target_in_range(attacker_coord, atk_range)
		if check_target:
			valid_abilities.append(i)

	if valid_abilities.is_empty():
		# No hay ataques válidos en rango — intentar acercarse al jugador más cercano
		print("[BattleFlow] Enemigo %s no tiene ataques en rango, intenta acercarse" % _current_unit.display_name)
		await _enemy_try_move_closer(_current_unit)
		_advance_turn()
		return

	# Preferir melee si hay adyacente (más daño), sino usar a distancia
	var ability_idx: int
	if has_adjacent:
		# Intentar usar melee (índices 2,3 tienen range 1 = más daño)
		var melee_abilities: Array[int] = []
		for i in valid_abilities:
			var ab: Dictionary = Unit.get_ability(_current_unit, i)
			if ab.get("range", 99) <= 1:
				melee_abilities.append(i)
		if not melee_abilities.is_empty():
			ability_idx = melee_abilities[randi() % melee_abilities.size()]
		else:
			ability_idx = valid_abilities[randi() % valid_abilities.size()]
	else:
		# Solo usar ataques a distancia
		var ranged_abilities: Array[int] = []
		for i in valid_abilities:
			var ab: Dictionary = Unit.get_ability(_current_unit, i)
			if ab.get("range", 99) > 1:
				ranged_abilities.append(i)
		if not ranged_abilities.is_empty():
			ability_idx = ranged_abilities[randi() % ranged_abilities.size()]
		else:
			ability_idx = valid_abilities[randi() % valid_abilities.size()]

	# Buscar target para la habilidad elegida
	var chosen_ab: Dictionary = Unit.get_ability(_current_unit, ability_idx)
	var chosen_range: int = chosen_ab.get("range", 99)
	var target: Unit = _find_player_target_in_range(attacker_coord, chosen_range)

	if not target:
		# Fallback: no debería pasar, pero por seguridad
		target = alive_players[randi() % alive_players.size()]

	var range_label: String = "melee" if chosen_range <= 1 else "distancia"
	print("[BattleFlow] Enemigo %s ataca a %s con ataque %d (%s, rango %d)" % [
		_current_unit.display_name, target.display_name, ability_idx, range_label, chosen_range
	])

	_state = State.ANIMATING

	# Cámara encuadra a ambos personajes durante el ataque
	camera_rig.tween_to_combat_view(_current_unit.global_position, target.global_position)

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
	hud.return_to_main_menu.connect(_on_return_to_main_menu)
	hud.equip_weapon_requested.connect(_on_hud_equip_weapon)
	hud.unequip_weapon_requested.connect(_on_hud_unequip_weapon)
	hud.back_from_equipo.connect(_on_hud_back_from_equipo)
	print("[BattleFlow] Señales del HUD conectadas")


func _on_hud_action_selected(action: String) -> void:
	if _state != State.CHOOSING_ACTION:
		return

	match action:
		"attack":
			if _current_unit.stats.current_ap <= 0:
				print("[BattleFlow] Sin AP para atacar")
				return
			var melee_ok: bool = _has_adjacent_enemy()
			_state = State.CHOOSING_ATTACK
			print("[BattleFlow] Estado: CHOOSING_ATTACK - mostrando ataques (melee: %s)" % melee_ok)
			camera_rig.tween_to_attack_view(_current_unit.global_position)
			if hud:
				hud.show_attack_menu(_current_unit, melee_ok)

		"move":
			if _current_unit.stats.current_sp <= 0:
				print("[BattleFlow] Sin SP para moverse")
				return
			_start_choosing_move()

		"item":
			_state = State.CHOOSING_ITEM
			print("[BattleFlow] Estado: CHOOSING_ITEM - mostrando ítems")
			camera_rig.tween_to_item_view(_current_unit.global_position)
			if hud:
				hud.show_item_menu()

		"equipo":
			if _current_unit.inventory == null:
				print("[BattleFlow] Esta unidad no tiene inventario")
				return
			_state = State.CHOOSING_EQUIPO
			print("[BattleFlow] Estado: CHOOSING_EQUIPO")
			camera_rig.tween_to_action_view(_current_unit.global_position)
			if hud:
				hud.show_equipo_panel(_current_unit)

		"end_turn":
			print("[BattleFlow] Fin de turno manual")
			_advance_turn()


func _on_hud_attack_selected(index: int) -> void:
	if _state != State.CHOOSING_ATTACK:
		return

	_selected_ability_index = index
	var ab: Dictionary = Unit.get_ability(_current_unit, index)
	var atk_range: int = ab.get("range", 99)
	print("[BattleFlow] ► Ataque %d seleccionado por %s: phys=%d mag=%d hit=%.0f%% rango=%d" % [
		index,
		_current_unit.display_name,
		ab.get("physical", 0),
		ab.get("magic", 0),
		ab.get("hit_chance", 1.0) * 100.0,
		atk_range
	])

	# ── Habilidad defensiva: "block_next" (Defender) ──────────
	if ab.get("effect", "") == "block_next":
		_state = State.ANIMATING
		if hud:
			hud.hide_all_menus()
		_current_unit.stats.spend_ap(1)
		_current_unit._blocking = true
		print("[BattleFlow] %s se pone en posición defensiva (bloqueará el próximo golpe)" % _current_unit.display_name)
		# Animación de "ponerse en guardia" (reutiliza melee_punch como placeholder)
		var ap_node: AnimationPlayer = _current_unit._get_anim_ap()
		if ap_node and ap_node.has_animation(ab.get("anim_name", "")):
			ap_node.play(ab.get("anim_name", ""))
			await ap_node.animation_finished
		else:
			await get_tree().create_timer(0.4).timeout
		await get_tree().create_timer(0.2).timeout
		_check_turn_end_or_continue()
		return

	# ── Ataque normal: entrar a CHOOSING_TARGET ─────────────
	var attacker_coord: Vector2i = board.get_coords_for_unit(_current_unit)

	# Verificar que haya al menos 1 enemigo en rango antes de entrar al estado
	if not _find_target_in_range(attacker_coord, atk_range):
		print("[BattleFlow] No hay enemigos en rango %d para este ataque" % atk_range)
		return  # Mantener en CHOOSING_ATTACK

	_start_choosing_target(index)


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
	_return_to_action_menu()


# ── EQUIPO HANDLERS ────────────────────────────────────────

## slot: 0 = mano derecha, 1 = mano izquierda
func _on_hud_equip_weapon(weapon: WeaponData, slot: int) -> void:
	if _state != State.CHOOSING_EQUIPO:
		return
	var unit: Unit = _current_unit
	if not unit or not unit.inventory:
		return

	# Cambiar arma en un slot que ya tiene arma cuesta 1 SP; slot vacío es gratis
	var had_weapon_in_slot: bool = unit.inventory.get_equipped_in_slot(slot) != null
	if had_weapon_in_slot:
		if unit.stats.current_sp <= 0:
			print("[BattleFlow] Sin SP para cambiar arma en slot %d" % slot)
			return
		unit.stats.spend_sp(1)

	# Actualizar inventario
	unit.inventory.set_equipped_in_slot(slot, weapon)
	# Arma 2H: marcar también el otro slot como ocupado
	if weapon.slot == WeaponData.SlotMode.TWO_HANDED:
		unit.inventory.set_equipped_in_slot(1 - slot, weapon)

	# Aplicar visualmente y en stats
	unit.equip_weapon_data(weapon, slot as Unit.WeaponSlot)

	print("[BattleFlow] %s equipó '%s' en slot %d (SP gastado: %s)" % [
		unit.display_name, weapon.display_name, slot, str(had_weapon_in_slot)
	])

	# Refrescar panel para reflejar el nuevo estado
	if hud and hud.equipo_panel:
		hud.equipo_panel.setup(unit)

	_return_to_action_menu()


## slot: 0 = mano derecha, 1 = mano izquierda
func _on_hud_unequip_weapon(slot: int) -> void:
	if _state != State.CHOOSING_EQUIPO:
		return
	var unit: Unit = _current_unit
	if not unit or not unit.inventory:
		return
	var weapon: WeaponData = unit.inventory.get_equipped_in_slot(slot)
	if weapon == null:
		return

	# Inventario: limpiar slot(s)
	unit.inventory.set_equipped_in_slot(slot, null)
	if weapon.slot == WeaponData.SlotMode.TWO_HANDED:
		unit.inventory.set_equipped_in_slot(1 - slot, null)

	unit.unequip_weapon_data(slot as Unit.WeaponSlot)

	print("[BattleFlow] %s desequipó arma del slot %d" % [unit.display_name, slot])
	_return_to_action_menu()


func _on_hud_back_from_equipo() -> void:
	if _state != State.CHOOSING_EQUIPO:
		return
	print("[BattleFlow] Volviendo al menú de acciones desde equipo")
	_return_to_action_menu()


## Vuelve al estado CHOOSING_ACTION y muestra el menú de acciones.
func _return_to_action_menu() -> void:
	_state = State.CHOOSING_ACTION
	camera_rig.tween_to_action_view(_current_unit.global_position)
	_update_hud_actions()
	if hud:
		hud.show_action_menu()


# ── MOVEMENT ──────────────────────────────────────────────

func _start_choosing_move() -> void:
	var origin: Vector2i = board.get_coords_for_unit(_current_unit)
	if origin == Vector2i(-1, -1):
		print("[BattleFlow] No se encontró tile de la unidad actual")
		return

	var max_steps: int = _current_unit.stats.current_sp
	_valid_move_tiles = board.get_movement_range(origin, max_steps)

	if _valid_move_tiles.is_empty():
		print("[BattleFlow] No hay tiles disponibles para moverse")
		return

	_state = State.CHOOSING_MOVE
	print("[BattleFlow] Estado: CHOOSING_MOVE - %d tiles disponibles (rango: %d)" % [_valid_move_tiles.size(), max_steps])

	board.highlight_tiles(_valid_move_tiles)
	board.highlight_unreachable_tiles(_valid_move_tiles)
	camera_rig.tween_to_overview(board.get_board_center(), board.get_board_size(), 0.7)

	if hud:
		hud.hide_all_menus()


func _cancel_move() -> void:
	print("[BattleFlow] Movimiento cancelado")
	board.clear_all_highlights()
	_valid_move_tiles.clear()
	_hovered_tile = null
	_current_unit.set_animation_state(Unit.AnimState.IDLE)
	_state = State.CHOOSING_ACTION
	camera_rig.tween_to_action_view(_current_unit.global_position)
	if hud:
		hud.show_action_menu()


func _execute_move(tile: Tile) -> void:
	_state = State.ANIMATING
	board.clear_all_highlights()

	# Actualizar ocupación de tiles
	var old_coord: Vector2i = board.get_coords_for_unit(_current_unit)
	var old_tile: Tile = board.get_tile_at(old_coord)
	if old_tile:
		old_tile.occupied_by = null
	tile.occupied_by = _current_unit

	# Gastar SP = distancia real recorrida en tiles (no siempre 1)
	var dist: int = board.get_tile_distance(old_coord, tile.coords)
	_current_unit.stats.spend_sp(dist)

	print("[BattleFlow] Moviendo %s de %s a %s (distancia: %d tiles, SP restante: %d)" % [
		_current_unit.display_name, old_coord, tile.coords, dist, _current_unit.stats.current_sp
	])

	await _current_unit.move_to_tile(tile.world_position)

	# Girar hacia el último enemigo atacado (si sigue vivo) o el más cercano
	var opponents: Array = _get_alive_opponents(_current_unit)
	if not opponents.is_empty():
		var facing_target: Unit = _current_unit.get_facing_target_after_move(opponents)
		if facing_target:
			_current_unit._face_target(facing_target.global_position)

	_current_unit.reset_start_pose()

	_valid_move_tiles.clear()
	_hovered_tile = null

	# Verificar si el turno continúa o termina
	_check_turn_end_or_continue()


## Entra al estado de selección de objetivo para un ataque dado.
## Resalta el rango de ataque en naranja y muestra el prompt en el HUD.
func _start_choosing_target(ability_index: int) -> void:
	_selected_ability_index = ability_index
	var ab: Dictionary = Unit.get_ability(_current_unit, ability_index)
	var atk_range: int = ab.get("range", 99)
	var attacker_coord: Vector2i = board.get_coords_for_unit(_current_unit)

	# Recopilar tiles que contienen enemigos en rango
	_valid_target_tiles.clear()
	for u in _turn_order:
		if u is Unit and u.alive and u.team == Unit.Team.ENEMY:
			var coord: Vector2i = board.get_coords_for_unit(u)
			if board.get_tile_distance(attacker_coord, coord) <= atk_range:
				_valid_target_tiles.append(coord)

	_state = State.CHOOSING_TARGET
	board.clear_all_highlights()
	board.highlight_attack_range(attacker_coord, atk_range)

	if hud:
		hud.show_target_selection_prompt(ab.get("display_name", "Ataque"))

	camera_rig.tween_to_overview(board.get_board_center(), board.get_board_size(), 0.5)
	print("[BattleFlow] Estado: CHOOSING_TARGET — '%s' rango=%d, %d targets válidos" % [
		ab.get("display_name", ""), atk_range, _valid_target_tiles.size()
	])


## Cancela la selección de objetivo y vuelve al menú de ataque.
func _cancel_target_selection() -> void:
	board.clear_all_highlights()
	if _hovered_tile:
		_hovered_tile.set_hover_highlighted(false)
		_hovered_tile = null
	_valid_target_tiles.clear()
	_state = State.CHOOSING_ATTACK
	if hud:
		hud.hide_all_menus()
		hud.show_attack_menu(_current_unit, _has_adjacent_enemy())
	camera_rig.tween_to_attack_view(_current_unit.global_position)
	print("[BattleFlow] Selección de target cancelada, volviendo al menú de ataque")


## Ejecuta el ataque sobre el target confirmado (llamado desde _input al hacer click).
func _execute_attack_on_target(target: Unit) -> void:
	board.clear_all_highlights()
	if _hovered_tile:
		_hovered_tile.set_hover_highlighted(false)
		_hovered_tile = null
	_valid_target_tiles.clear()

	_state = State.ANIMATING
	if hud:
		hud.hide_all_menus()

	_current_unit.stats.spend_ap(1)

	# Cámara encuadra a ambos personajes durante el ataque
	camera_rig.tween_to_combat_view(_current_unit.global_position, target.global_position)

	print("[BattleFlow] Atacando a %s con habilidad %d" % [target.display_name, _selected_ability_index])
	await _current_unit.attack_target(target, _selected_ability_index)

	# Pequeña pausa después del ataque
	await get_tree().create_timer(0.3).timeout

	_check_turn_end_or_continue()


## Raycast de tile desde posición del mouse. Devuelve el Tile o null.
func _raycast_tile_at_mouse(mouse_pos: Vector2) -> Tile:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if not camera:
		return null

	var from: Vector3 = camera.project_ray_origin(mouse_pos)
	var to: Vector3 = from + camera.project_ray_normal(mouse_pos) * 1000.0

	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 4
	query.collide_with_areas = true  # Los tiles usan Area3D, no PhysicsBody3D
	query.collide_with_bodies = false

	var result: Dictionary = space_state.intersect_ray(query)
	if result.is_empty():
		return null

	var collider: Object = result.collider
	if collider is Area3D:
		var tile_node: Node = collider.get_parent()
		if tile_node is Tile:
			return tile_node as Tile
	return null


# ── AP/SP HELPERS ──────────────────────────────────────────

## Actualiza el HUD con el estado actual de AP/SP y habilita/deshabilita botones.
func _update_hud_actions() -> void:
	if not hud or not _current_unit or not _current_unit.stats:
		return
	var s: UnitStats = _current_unit.stats
	hud.update_ap_sp(s.current_ap, s.max_primary_actions, s.current_sp, s.max_secondary_actions)
	hud.set_attack_enabled(s.current_ap > 0)
	hud.set_move_enabled(s.current_sp > 0)
	# Equipo disponible si la unidad tiene inventario (y SP para posible cambio de arma)
	var has_inventory: bool = _current_unit.inventory != null
	hud.set_equipo_enabled(has_inventory)


## Después de una acción, verifica si el turno continúa o termina.
## Regla: gastar la acción primaria (AP=0) termina el turno inmediatamente,
## independientemente de los SP restantes (que se descartan).
## Solo moverse (gasta SP pero no AP) permite continuar el turno.
func _check_turn_end_or_continue() -> void:
	if _check_battle_end():
		return
	# Si se gastó la acción primaria, el turno termina
	if _current_unit.stats.current_ap <= 0:
		print("[BattleFlow] AP gastada — fin de turno (SP descartados: %d)" % _current_unit.stats.current_sp)
		_advance_turn()
		return
	# Solo hay SP restantes: el turno continúa (el jugador puede moverse o hacer acciones sin AP)
	_state = State.CHOOSING_ACTION
	camera_rig.tween_to_action_view(_current_unit.global_position)
	_update_hud_actions()
	if hud:
		hud.show_action_menu()
	print("[BattleFlow] Turno continúa (AP:%d SP:%d)" % [
		_current_unit.stats.current_ap, _current_unit.stats.current_sp
	])


# ── RANGE HELPERS ─────────────────────────────────────────

## Comprueba si hay algún enemigo adyacente (Manhattan distance ≤ 1) al _current_unit.
func _has_adjacent_enemy() -> bool:
	var attacker_coord: Vector2i = board.get_coords_for_unit(_current_unit)
	if attacker_coord == Vector2i(-1, -1):
		return false
	for u in _turn_order:
		if u is Unit and u.alive and u.team == Unit.Team.ENEMY:
			var enemy_coord: Vector2i = board.get_coords_for_unit(u)
			if board.get_tile_distance(attacker_coord, enemy_coord) <= 1:
				return true
	return false


## Busca el enemigo vivo más cercano dentro del rango dado (desde la perspectiva del player).
func _find_target_in_range(attacker_coord: Vector2i, atk_range: int) -> Unit:
	var best_target: Unit = null
	var best_distance: int = 999
	for u in _turn_order:
		if u is Unit and u.alive and u.team == Unit.Team.ENEMY:
			var enemy_coord: Vector2i = board.get_coords_for_unit(u)
			var dist: int = board.get_tile_distance(attacker_coord, enemy_coord)
			if dist <= atk_range and dist < best_distance:
				best_distance = dist
				best_target = u
	return best_target


## Comprueba si hay algún jugador adyacente (Manhattan distance ≤ 1) al enemigo dado.
func _has_adjacent_player(enemy_unit: Unit) -> bool:
	var enemy_coord: Vector2i = board.get_coords_for_unit(enemy_unit)
	if enemy_coord == Vector2i(-1, -1):
		return false
	for u in _turn_order:
		if u is Unit and u.alive and u.team == Unit.Team.PLAYER:
			var player_coord: Vector2i = board.get_coords_for_unit(u)
			if board.get_tile_distance(enemy_coord, player_coord) <= 1:
				return true
	return false


## Mueve al enemigo hacia el jugador más cercano usando todos sus SP disponibles.
## Elige el tile alcanzable que minimiza la distancia al target.
## Devuelve true si el enemigo se pudo mover.
func _enemy_try_move_closer(enemy: Unit) -> bool:
	var enemy_coord: Vector2i = board.get_coords_for_unit(enemy)
	if enemy_coord == Vector2i(-1, -1):
		return false

	# Encontrar el jugador más cercano
	var best_player: Unit = null
	var best_dist: int = 999
	for u in _turn_order:
		if u is Unit and u.alive and u.team == Unit.Team.PLAYER:
			var pc: Vector2i = board.get_coords_for_unit(u)
			var d: int = board.get_tile_distance(enemy_coord, pc)
			if d < best_dist:
				best_dist = d
				best_player = u

	if not best_player:
		return false

	var target_coord: Vector2i = board.get_coords_for_unit(best_player)

	var max_steps: int = enemy.stats.current_sp
	if max_steps <= 0:
		return false

	var reachable: Array[Vector2i] = board.get_movement_range(enemy_coord, max_steps)
	if reachable.is_empty():
		return false

	# Elegir el tile alcanzable más cercano al target
	var best_tile_coord: Vector2i = Vector2i(-1, -1)
	var best_tile_dist: int = 999
	for coord in reachable:
		var d: int = board.get_tile_distance(coord, target_coord)
		if d < best_tile_dist:
			best_tile_dist = d
			best_tile_coord = coord

	if best_tile_coord == Vector2i(-1, -1):
		return false

	var dest_tile: Tile = board.get_tile_at(best_tile_coord)
	if not dest_tile:
		return false

	print("[BattleFlow] Enemigo %s se mueve hacia %s (destino: %s, dist al target: %d)" % [
		enemy.display_name, best_player.display_name, best_tile_coord, best_tile_dist
	])

	# Actualizar ocupación de tiles
	var old_tile: Tile = board.get_tile_at(enemy_coord)
	if old_tile:
		old_tile.occupied_by = null
	dest_tile.occupied_by = enemy

	# Gastar SP proporcional a la distancia
	var move_dist: int = board.get_tile_distance(enemy_coord, best_tile_coord)
	enemy.stats.spend_sp(move_dist)

	# Cámara sigue al enemigo durante el movimiento
	camera_rig.tween_to_focus(enemy.global_position + Vector3(0, 1, 0), 0.3)
	await enemy.move_to_tile(dest_tile.world_position)

	# Girar hacia el jugador objetivo
	enemy._face_target(best_player.global_position)
	enemy.reset_start_pose()
	return true


## Devuelve todos los oponentes vivos de la unidad dada (equipo contrario).
func _get_alive_opponents(unit: Unit) -> Array:
	var result: Array = []
	for u in _spawned_units:
		if u is Unit and (u as Unit).alive and (u as Unit).team != unit.team:
			result.append(u)
	return result


## Busca el jugador vivo más cercano dentro del rango dado (desde la perspectiva del enemigo).
func _find_player_target_in_range(attacker_coord: Vector2i, atk_range: int) -> Unit:
	var best_target: Unit = null
	var best_distance: int = 999
	for u in _turn_order:
		if u is Unit and u.alive and u.team == Unit.Team.PLAYER:
			var player_coord: Vector2i = board.get_coords_for_unit(u)
			var dist: int = board.get_tile_distance(attacker_coord, player_coord)
			if dist <= atk_range and dist < best_distance:
				best_distance = dist
				best_target = u
	return best_target


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
			hud.show_result_screen(false, _spawned_units)
		return true

	if enemies_alive == 0:
		_state = State.BATTLE_END
		print("[BattleFlow] ══════════════════════════════")
		print("[BattleFlow] BATALLA TERMINADA - VICTORIA")
		print("[BattleFlow] ══════════════════════════════")
		if hud:
			hud.show_result_screen(true, _spawned_units)
		return true

	return false


## Vuelve al menú principal al pulsar el botón correspondiente en la pantalla de resultado.
func _on_return_to_main_menu() -> void:
	print("[BattleFlow] Volviendo al menú principal")
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")


# ── LEGACY: tile selection (mantener para debug con T) ─────

func _setup_tile_selection() -> void:
	if not board.tile_selected.is_connected(_on_tile_selected):
		board.tile_selected.connect(_on_tile_selected)


func _on_tile_selected(tile: Tile) -> void:
	_selected_tile = tile


func _input(event: InputEvent) -> void:
	# ── CHOOSING_TARGET: hover, click en enemigo, cancelar ──
	if _state == State.CHOOSING_TARGET:
		# Cancelar con ESC
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			_cancel_target_selection()
			get_viewport().set_input_as_handled()
			return

		# Cancelar con click derecho
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
			_cancel_target_selection()
			get_viewport().set_input_as_handled()
			return

		# Hover: resaltar tile bajo el cursor (verde si tiene enemigo en rango, naranja si no)
		if event is InputEventMouseMotion:
			var tile: Tile = _raycast_tile_at_mouse(event.position)
			if tile:
				if _hovered_tile and _hovered_tile != tile:
					_hovered_tile.set_hover_highlighted(false)
				var is_valid: bool = tile.coords in _valid_target_tiles
				tile.set_hover_highlighted(true, is_valid)
				_hovered_tile = tile
			elif _hovered_tile:
				_hovered_tile.set_hover_highlighted(false)
				_hovered_tile = null
			return

		# Click izquierdo: confirmar target si el tile tiene un enemigo en rango
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			var tile: Tile = _raycast_tile_at_mouse(event.position)
			if tile and tile.coords in _valid_target_tiles:
				var target: Unit = tile.occupied_by as Unit
				if target and target.alive:
					get_viewport().set_input_as_handled()
					_execute_attack_on_target(target)
			return

		return  # No procesar otros eventos durante CHOOSING_TARGET

	# ── CHOOSING_MOVE: hover, click, cancelar ──
	if _state == State.CHOOSING_MOVE:
		# Cancelar con ESC
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			_cancel_move()
			get_viewport().set_input_as_handled()
			return

		# Cancelar con click derecho
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
			_cancel_move()
			get_viewport().set_input_as_handled()
			return

		# Hover: resaltar tile bajo el cursor (verde si válido, rojo si no)
		if event is InputEventMouseMotion:
			var tile: Tile = _raycast_tile_at_mouse(event.position)
			if tile:
				if _hovered_tile and _hovered_tile != tile:
					_hovered_tile.set_hover_highlighted(false)
				var is_valid: bool = tile.coords in _valid_move_tiles
				tile.set_hover_highlighted(true, is_valid)
				_hovered_tile = tile
			elif _hovered_tile:
				_hovered_tile.set_hover_highlighted(false)
				_hovered_tile = null
			return

		# Click izquierdo: seleccionar tile destino
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			var tile: Tile = _raycast_tile_at_mouse(event.position)
			if tile and tile.coords in _valid_move_tiles:
				get_viewport().set_input_as_handled()
				_execute_move(tile)
			return

		return  # No procesar otros eventos durante CHOOSING_MOVE

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
	if _state in [State.CHOOSING_ACTION, State.CHOOSING_ATTACK, State.CHOOSING_TARGET, State.CHOOSING_ITEM, State.CHOOSING_EQUIPO]:
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
