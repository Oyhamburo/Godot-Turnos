extends Control

@export var combat_manager_path: NodePath
@export var main_camera_path: NodePath
@export var transition_camera_path: NodePath
@export var enemy_camera_path: NodePath
@export var presentation_camera_path: NodePath

@onready var timeline_hbox: HBoxContainer = %TimelineHBox
@onready var players_list: VBoxContainer = %PlayersList
@onready var enemies_list: VBoxContainer = %EnemiesList
@onready var turn_label: Label = %TurnLabel
@onready var attack_button: Button = %AttackButton
@onready var pass_button: Button = %PassButton
@onready var next_target_button: Button = %NextTargetButton
@onready var end_dialog: Control = %EndDialog
@onready var end_label: Label = %EndLabel
@onready var end_accept: Button = %EndAccept
@onready var attack_options_panel: PanelContainer = %AttackOptionsPanel
@onready var attack_option_1: Button = %AttackOption1
@onready var attack_option_2: Button = %AttackOption2
@onready var attack_option_3: Button = %AttackOption3
@onready var attack_option_4: Button = %AttackOption4
@onready var turn_action_panel: PanelContainer = %TurnActionPanel
@onready var choose_attack_button: Button = %ChooseAttackButton
@onready var use_item_button: Button = %UseItemButton
@onready var flee_button: Button = %FleeButton

var combat: CombatManager
var main_cam: Camera3D
var transition_cam: Camera3D
var enemy_cam: Camera3D
var presentation_cam: Camera3D

const CAMERA_TRANSITION_DURATION := 0.7
const PRESENTATION_DURATION := 2.5
# Posición de la cámara close-up respecto al jugador (mismo offset que tenía CloseUpCamera en las escenas)
const CLOSEUP_OFFSET_LOCAL := Vector3(3, 2, -5)
const CLOSEUP_OFFSET_OPPOSITE := Vector3(-3, 2, 5)
const ENEMY_CLOSEUP_OFFSET_LOCAL := Vector3(0, 2, -4)
const CLOSEUP_FOV := 45.0

# Cuatro nombres de ataque por clase de jugador (todos ejecutan el mismo ataque).
const ATTACK_NAMES_BY_CLASS: Dictionary = {
	"PlayerKnight": ["Golpe de espada", "Embestida", "Corte pesado", "Ataque definitivo"],
	"PlayerMage": ["Bola de fuego", "Rayo de hielo", "Descarga", "Explosión"],
	"PlayerRanger": ["Flecha rápida", "Disparo doble", "Tiro certero", "Lluvia de flechas"],
	"PlayerRogue": ["Puñalada", "Golpe sigiloso", "Corte rápido", "Ataque letal"],
	"PlayerBarbarian": ["Tajo salvaje", "Grito de guerra", "Golpe demoledor", "Furia"],
	"PlayerRogueHooded": ["Puñalada", "Golpe sigiloso", "Corte rápido", "Ataque letal"]
}
const ATTACK_NAMES_FALLBACK: Array[String] = ["Ataque 1", "Ataque 2", "Ataque 3", "Ataque 4"]
const ATTACK_PANEL_OFFSET := Vector2(80, -40)
const ATTACK_PANEL_SIZE := Vector2(500, 80)

var _current: Unit
var _selected_target: Unit
var _selected_ability_index: int = -1
var _enemy_rows := {} # Unit -> Button
var _camera_tween: Tween
var _transition_done_callback: Callable = Callable()
var _intro_done := true

var _turn_slot_scene := preload("res://scenes/ui/TurnSlot.tscn")

func _ready() -> void:
	combat = get_node(combat_manager_path)
	main_cam = get_node(main_camera_path) if main_camera_path else null
	transition_cam = get_node(transition_camera_path) if transition_camera_path else null
	enemy_cam = get_node(enemy_camera_path) if enemy_camera_path else null
	presentation_cam = get_node(presentation_camera_path) if presentation_camera_path else null
	if presentation_cam:
		_intro_done = false
		presentation_cam.current = true
		if main_cam:
			main_cam.current = false
		if transition_cam:
			transition_cam.current = false
		if enemy_cam:
			enemy_cam.current = false
	else:
		if main_cam:
			main_cam.current = (enemy_cam == null)
		if transition_cam:
			transition_cam.current = false
		if enemy_cam:
			enemy_cam.current = true

	attack_button.pressed.connect(_on_attack_pressed)
	pass_button.pressed.connect(_on_pass_pressed)
	if next_target_button:
		next_target_button.pressed.connect(_on_next_target_pressed)
	end_accept.pressed.connect(_on_end_accept)
	attack_option_1.pressed.connect(_on_attack_option_pressed.bind(0))
	attack_option_2.pressed.connect(_on_attack_option_pressed.bind(1))
	attack_option_3.pressed.connect(_on_attack_option_pressed.bind(2))
	attack_option_4.pressed.connect(_on_attack_option_pressed.bind(3))
	if choose_attack_button:
		choose_attack_button.pressed.connect(_on_choose_attack_pressed)
	if use_item_button:
		use_item_button.pressed.connect(_on_use_item_pressed)
	if flee_button:
		flee_button.pressed.connect(_on_flee_pressed)

	end_dialog.visible = false
	attack_button.disabled = true
	attack_button.visible = true
	if next_target_button:
		next_target_button.visible = false
		next_target_button.disabled = true
	attack_options_panel.visible = false
	if turn_action_panel:
		turn_action_panel.visible = false

	combat.units_spawned.connect(_on_units_spawned)
	combat.timeline_updated.connect(_on_timeline_updated)
	combat.turn_changed.connect(_on_turn_changed)
	combat.state_changed.connect(_on_state_changed)
	combat.unit_died.connect(_on_unit_died)
	combat.battle_ended.connect(_on_battle_ended)

	# Get initial state even if CombatManager already emitted before we connected.
	combat.request_ui_refresh()

func _on_units_spawned(players, enemies) -> void:
	_rebuild_unit_lists(players, enemies)
	if presentation_cam and not _intro_done:
		presentation_cam.current = true
		if main_cam:
			main_cam.current = false
		if transition_cam:
			transition_cam.current = false
		if enemy_cam:
			enemy_cam.current = false
		get_tree().create_timer(PRESENTATION_DURATION).timeout.connect(_on_presentation_ended)
	elif enemy_cam:
		enemy_cam.current = true
		if main_cam:
			main_cam.current = false
		if transition_cam:
			transition_cam.current = false
	elif main_cam:
		main_cam.current = true

func _on_timeline_updated(order, current) -> void:
	_rebuild_timeline(order, current)

func _on_turn_changed(current: Unit) -> void:
	_current = current
	_selected_target = null
	_selected_ability_index = -1
	_clear_enemy_selection_highlights()
	attack_button.disabled = true
	attack_button.visible = true
	if next_target_button:
		next_target_button.visible = false
		next_target_button.disabled = true
	_hide_attack_options()
	_hide_turn_action_menu()

	if _current:
		turn_label.text = "Turno: %s" % _current.display_name
		if _intro_done or presentation_cam == null:
			_apply_camera_for_current_turn()
	else:
		turn_label.text = "Turno: -"

func _on_presentation_ended() -> void:
	_intro_done = true
	_apply_camera_for_current_turn()

func _apply_camera_for_current_turn() -> void:
	if _current == null:
		return
	if _current.team != Unit.Team.PLAYER:
		_use_main_camera()
		_switch_camera_for_turn(_current)
	else:
		_switch_camera_for_turn(_current, _show_turn_action_menu, true)

func _transition_to_player_then_show_attacks(unit: Unit) -> void:
	_switch_camera_for_turn(unit, _show_attack_options)

func _show_turn_action_menu() -> void:
	if attack_options_panel:
		attack_options_panel.visible = false
	_hide_target_selection_ui()
	if turn_action_panel:
		turn_action_panel.visible = true

func _hide_turn_action_menu() -> void:
	if turn_action_panel:
		turn_action_panel.visible = false

func _on_choose_attack_pressed() -> void:
	if _current == null:
		return
	_hide_turn_action_menu()
	_transition_to_closeup(_current, _show_attack_options, CLOSEUP_OFFSET_LOCAL)

func _on_use_item_pressed() -> void:
	pass

func _on_flee_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

func _on_state_changed(state: int) -> void:
	var selecting := (state == CombatManager.State.SELECTING_TARGET)
	pass_button.disabled = not selecting
	if not selecting:
		attack_button.disabled = true
		_hide_attack_options()
		_hide_target_selection_ui()
		_hide_turn_action_menu()
	if state == CombatManager.State.ANIMATING:
		_hide_attack_options()
		_hide_target_selection_ui()
		_hide_turn_action_menu()
		call_deferred("_maybe_use_main_camera")

func _on_unit_died(_unit: Unit) -> void:
	_rebuild_unit_lists(combat.players, combat.enemies)

func _on_battle_ended(player_won: bool) -> void:
	end_dialog.visible = true
	end_label.text = "¡Ganaste!" if player_won else "Perdiste"
	attack_button.disabled = true
	pass_button.disabled = true
	_hide_attack_options()
	_hide_turn_action_menu()

func _on_end_accept() -> void:
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

func _on_attack_pressed() -> void:
	if _current == null:
		return
	if _selected_target != null and _selected_ability_index >= 0:
		_use_main_camera()
		combat.player_attack(_current, _selected_target, _selected_ability_index)
		_hide_target_selection_ui()
		return
	if _selected_target == null:
		return
	var look_back: Variant = _current.global_position + Vector3(0, 1.2, 0)
	_use_main_camera(look_back)
	combat.player_attack(_current, _selected_target)

func _on_attack_option_pressed(ability_index: int) -> void:
	if _current == null:
		return
	_selected_ability_index = ability_index
	var alive: Array[Unit] = []
	for e in combat.enemies:
		if is_instance_valid(e) and e.alive:
			alive.append(e)
	if alive.is_empty():
		_selected_ability_index = -1
		return
	_selected_target = alive[0]
	_clear_enemy_selection_highlights()
	_selected_target.set_selected(true)
	if _enemy_rows.has(_selected_target):
		var btn: Button = _enemy_rows[_selected_target]
		btn.button_pressed = true
	_transition_to_enemy_closeup(_selected_target, _show_target_selection_ui)

func _show_target_selection_ui() -> void:
	attack_options_panel.visible = false
	attack_button.visible = true
	attack_button.disabled = false
	attack_button.text = "Atacar"
	if next_target_button:
		next_target_button.visible = true
		next_target_button.disabled = false

func _hide_target_selection_ui() -> void:
	attack_button.disabled = true
	attack_button.text = "Atacar"
	if next_target_button:
		next_target_button.visible = false
		next_target_button.disabled = true
	_selected_ability_index = -1

func _on_next_target_pressed() -> void:
	var alive: Array[Unit] = []
	for e in combat.enemies:
		if is_instance_valid(e) and e.alive:
			alive.append(e)
	if alive.is_empty() or _selected_target == null:
		return
	var idx: int = alive.find(_selected_target)
	if idx < 0:
		idx = 0
	idx = (idx + 1) % alive.size()
	_selected_target = alive[idx]
	_clear_enemy_selection_highlights()
	_selected_target.set_selected(true)
	for u in _enemy_rows.keys():
		var btn: Button = _enemy_rows[u]
		if btn:
			btn.button_pressed = (u == _selected_target)
	_transition_to_enemy_closeup(_selected_target, Callable())

func _on_pass_pressed() -> void:
	combat.player_pass()

func _maybe_use_main_camera() -> void:
	# Llamado con call_deferred para que is_running() sea ya true si el ataque inició la transición inversa
	var has_tween: bool = _camera_tween != null and _camera_tween.is_valid()
	var running: bool = has_tween and _camera_tween.is_running()
	print("[CAM] _maybe_use_main_camera deferred: has_tween=%s is_running=%s" % [has_tween, running])
	if not has_tween or not running:
		print("[CAM] _maybe_use_main_camera -> calling _use_main_camera() (no look_at)")
		_use_main_camera()

func _use_main_camera(look_at_point: Variant = null) -> void:
	var active_name: String = ""
	var active: Camera3D = get_viewport().get_camera_3d()
	if active:
		active_name = active.name
	if main_cam == null:
		print("[CAM] _use_main_camera: main_cam null, return")
		return
	if active == main_cam:
		print("[CAM] _use_main_camera: active==main_cam (%s), return" % active_name)
		return
	if transition_cam and active:
		print("[CAM] _use_main_camera: active=%s -> _transition_to_camera(main_cam, look_at=%s)" % [active_name, look_at_point is Vector3])
		_transition_to_camera(main_cam, Callable(), look_at_point)
	else:
		print("[CAM] _use_main_camera: cut to main (transition_cam=%s active=%s)" % [transition_cam != null, active != null])
		main_cam.current = true
		if active and active != main_cam:
			active.current = false

func _switch_camera_for_turn(unit: Unit, on_closeup_done: Callable = Callable(), use_opposite_side: bool = false) -> void:
	if main_cam == null:
		return
	if unit.team != Unit.Team.PLAYER:
		_use_main_camera()
		return
	var offset_to_use: Vector3 = CLOSEUP_OFFSET_OPPOSITE if use_opposite_side else CLOSEUP_OFFSET_LOCAL
	var active: Camera3D = get_viewport().get_camera_3d()
	if transition_cam and active:
		if active == transition_cam and _current == unit and not use_opposite_side:
			if on_closeup_done.is_valid():
				on_closeup_done.call()
			return
		_transition_to_closeup(unit, on_closeup_done, offset_to_use)
		return
	if on_closeup_done.is_valid():
		on_closeup_done.call()

func _transition_to_closeup(unit: Unit, on_done: Callable = Callable(), offset_local: Vector3 = CLOSEUP_OFFSET_LOCAL) -> void:
	if transition_cam == null or unit == null:
		return
	_transition_done_callback = on_done
	if _camera_tween and _camera_tween.is_valid():
		_camera_tween.kill()
	var from_cam: Camera3D = get_viewport().get_camera_3d()
	if from_cam == null:
		if main_cam:
			main_cam.current = true
		if _transition_done_callback.is_valid():
			_transition_done_callback.call()
			_transition_done_callback = Callable()
		return
	var from_position: Vector3 = from_cam.global_position
	var target_position: Vector3 = unit.global_position + unit.global_transform.basis * offset_local
	var look_at_point: Vector3 = unit.global_position + Vector3(0, 1.2, 0)

	transition_cam.global_transform = from_cam.global_transform
	transition_cam.fov = CLOSEUP_FOV
	transition_cam.current = true
	from_cam.current = false

	_camera_tween = create_tween()
	_camera_tween.set_ease(Tween.EASE_IN_OUT)
	_camera_tween.set_trans(Tween.TRANS_SINE)
	_camera_tween.tween_method(
		func(t: float) -> void:
			transition_cam.global_position = from_position.lerp(target_position, t)
			transition_cam.look_at(look_at_point),
		0.0, 1.0, CAMERA_TRANSITION_DURATION
	)
	_camera_tween.tween_callback(func() -> void:
		if _transition_done_callback.is_valid():
			_transition_done_callback.call()
			_transition_done_callback = Callable()
	)
	return

func _transition_to_enemy_closeup(enemy: Unit, on_done: Callable = Callable()) -> void:
	if transition_cam == null or enemy == null:
		return
	_transition_done_callback = on_done
	if _camera_tween and _camera_tween.is_valid():
		_camera_tween.kill()
	var from_cam: Camera3D = get_viewport().get_camera_3d()
	if from_cam == null:
		if main_cam:
			main_cam.current = true
		if _transition_done_callback.is_valid():
			_transition_done_callback.call()
			_transition_done_callback = Callable()
		return

	var target_position: Vector3 = enemy.global_position + enemy.global_transform.basis * ENEMY_CLOSEUP_OFFSET_LOCAL
	var look_at_point: Vector3 = enemy.global_position + Vector3(0, 1.2, 0)

	if from_cam == transition_cam:
		# Ya estamos en close-up de otro enemigo: corte directo, sin transición intermedia
		transition_cam.global_position = target_position
		transition_cam.look_at(look_at_point)
		transition_cam.fov = CLOSEUP_FOV
		transition_cam.current = true
		if _transition_done_callback.is_valid():
			_transition_done_callback.call()
			_transition_done_callback = Callable()
		return

	var from_position: Vector3 = from_cam.global_position
	transition_cam.global_transform = from_cam.global_transform
	transition_cam.fov = CLOSEUP_FOV
	transition_cam.current = true
	from_cam.current = false

	_camera_tween = create_tween()
	_camera_tween.set_ease(Tween.EASE_IN_OUT)
	_camera_tween.set_trans(Tween.TRANS_SINE)
	_camera_tween.tween_method(
		func(t: float) -> void:
			transition_cam.global_position = from_position.lerp(target_position, t)
			transition_cam.look_at(look_at_point),
		0.0, 1.0, CAMERA_TRANSITION_DURATION
	)
	_camera_tween.tween_callback(func() -> void:
		if _transition_done_callback.is_valid():
			_transition_done_callback.call()
			_transition_done_callback = Callable()
	)

func _transition_to_camera(target: Camera3D, on_done: Callable = Callable(), look_at_point: Variant = null) -> void:
	var target_name: String = (target.name as String) if target else ""
	if target == null or transition_cam == null:
		print("[CAM] _transition_to_camera: target=%s or transition_cam null, return" % target_name)
		return
	_transition_done_callback = on_done
	if _camera_tween and _camera_tween.is_valid():
		print("[CAM] _transition_to_camera: killing previous tween")
		_camera_tween.kill()
	var from_cam: Camera3D = get_viewport().get_camera_3d()
	var from_name: String = (from_cam.name as String) if from_cam else ""
	if from_cam == null or from_cam == target:
		print("[CAM] _transition_to_camera: early return from_cam=%s target=%s" % [from_name, target_name])
		if target:
			target.current = true
		if from_cam and from_cam != target:
			from_cam.current = false
		if _transition_done_callback.is_valid():
			_transition_done_callback.call()
			_transition_done_callback = Callable()
		return
	var use_look_at: bool = look_at_point is Vector3
	print("[CAM] _transition_to_camera START from=%s -> target=%s use_look_at=%s" % [from_name, target_name, use_look_at])
	# Posición + (opcional) look_at durante el tween
	transition_cam.global_transform = from_cam.global_transform
	transition_cam.fov = from_cam.fov
	if from_cam == transition_cam and target == main_cam:
		transition_cam.fov = main_cam.fov
	transition_cam.current = true
	from_cam.current = false
	var from_position: Vector3 = from_cam.global_position
	var target_position: Vector3 = target.global_position
	var look_at_vec: Vector3 = look_at_point if use_look_at else Vector3.ZERO

	_camera_tween = create_tween()
	print("[CAM] _transition_to_camera: tween created, is_running()=%s" % _camera_tween.is_running())
	_camera_tween.set_ease(Tween.EASE_IN_OUT)
	_camera_tween.set_trans(Tween.TRANS_SINE)

	if use_look_at:
		_camera_tween.tween_method(
			func(t: float) -> void:
				transition_cam.global_position = from_position.lerp(target_position, t)
				transition_cam.look_at(look_at_vec),
			0.0, 1.0, CAMERA_TRANSITION_DURATION
		)
	else:
		_camera_tween.tween_property(transition_cam, "global_position", target_position, CAMERA_TRANSITION_DURATION)

	_camera_tween.tween_callback(func() -> void:
		print("[CAM] _transition_to_camera DONE -> %s" % target_name)
		target.current = true
		transition_cam.current = false
		if _transition_done_callback.is_valid():
			_transition_done_callback.call()
			_transition_done_callback = Callable()
	)

func _get_player_class(unit: Unit) -> String:
	if unit == null:
		return ""
	var path: String = unit.scene_file_path
	if path.is_empty():
		return ""
	return path.get_file().get_basename()

func _show_attack_options() -> void:
	if _current == null or not attack_options_panel:
		return
	var class_key: String = _get_player_class(_current)
	var names: Array = ATTACK_NAMES_BY_CLASS.get(class_key, ATTACK_NAMES_FALLBACK)
	attack_option_1.text = names[0] if names.size() > 0 else ATTACK_NAMES_FALLBACK[0]
	attack_option_2.text = names[1] if names.size() > 1 else ATTACK_NAMES_FALLBACK[1]
	attack_option_3.text = names[2] if names.size() > 2 else ATTACK_NAMES_FALLBACK[2]
	attack_option_4.text = names[3] if names.size() > 3 else ATTACK_NAMES_FALLBACK[3]
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam:
		var viewport_size: Vector2 = get_viewport().get_visible_rect().size
		var pos_3d: Vector3 = _current.global_position + Vector3(0.0, 1.2, 0.0)
		var pos_screen: Vector2 = cam.unproject_position(pos_3d)
		pos_screen += ATTACK_PANEL_OFFSET
		pos_screen.x = clampf(pos_screen.x, 20.0, viewport_size.x - ATTACK_PANEL_SIZE.x - 20.0)
		pos_screen.y = clampf(pos_screen.y, 20.0, viewport_size.y - ATTACK_PANEL_SIZE.y - 20.0)
		attack_options_panel.position = pos_screen
	attack_options_panel.visible = true

func _hide_attack_options() -> void:
	if attack_options_panel:
		attack_options_panel.visible = false
	_hide_turn_action_menu()
	attack_button.visible = true

func _input(event: InputEvent) -> void:
	# 3D click/tap target selection only on player's selecting state.
	if combat.state != CombatManager.State.SELECTING_TARGET:
		return
	if _current == null or _current.team != Unit.Team.PLAYER:
		return

	# If mouse is over an interactive UI Control, don't treat it as world selection.
	var hovered := get_viewport().gui_get_hovered_control()
	if hovered != null:
		# Allow clicks on empty, but block if hovering any button/panel/etc.
		# (Our layout containers use MOUSE_FILTER_IGNORE, so this tends to mean "real" UI).
		return

	var click_pos: Vector2
	var pressed := false

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		click_pos = event.position
		pressed = true
	elif event is InputEventScreenTouch and event.pressed:
		click_pos = event.position
		pressed = true

	if not pressed:
		return

	var target := _raycast_unit(click_pos)
	if target and target.team == Unit.Team.ENEMY and target.alive:
		_select_enemy_target(target)
		
func _raycast_unit(screen_pos: Vector2) -> Unit:
	var active_cam: Camera3D = get_viewport().get_camera_3d()
	if active_cam == null:
		return null
	var from: Vector3 = active_cam.project_ray_origin(screen_pos)
	var to: Vector3 = from + active_cam.project_ray_normal(screen_pos) * 2000.0

	var space: PhysicsDirectSpaceState3D = get_viewport().get_world_3d().direct_space_state
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = true
	query.collide_with_bodies = true

	var hit: Dictionary = space.intersect_ray(query)
	if hit.is_empty():
		return null

	var col: Variant = hit.get("collider")
	if col is Unit:
		return col as Unit
	return null


func _select_enemy_target(target: Unit) -> void:
	_selected_target = target
	_clear_enemy_selection_highlights()
	target.set_selected(true)
	if _enemy_rows.has(target):
		var btn: Button = _enemy_rows[target]
		btn.button_pressed = true

	if _selected_ability_index >= 0:
		_transition_to_enemy_closeup(target, _show_target_selection_ui if (not next_target_button or not next_target_button.visible) else Callable())
	else:
		_selected_ability_index = 0
		_transition_to_enemy_closeup(target, _show_target_selection_ui)

func _clear_enemy_selection_highlights() -> void:
	for e in combat.enemies:
		if e:
			e.set_selected(false)
	for u in _enemy_rows.keys():
		var b: Button = _enemy_rows[u]
		if b:
			b.button_pressed = false

func _rebuild_timeline(order, current: Unit) -> void:
	for c in timeline_hbox.get_children():
		c.queue_free()

	for u in order:
		var slot := _turn_slot_scene.instantiate()
		timeline_hbox.add_child(slot)   # ✅ primero al árbol
		slot.setup(u, u == current)     # ✅ después


func _rebuild_unit_lists(players, enemies) -> void:
	for c in players_list.get_children():
		_disconnect_hp_and_free(c)
	for c in enemies_list.get_children():
		_disconnect_hp_and_free(c)
	_enemy_rows.clear()

	for p in players:
		if p == null: continue
		var row := _make_unit_row(p, false)
		players_list.add_child(row)

	for e in enemies:
		if e == null: continue
		var row := _make_unit_row(e, true)
		enemies_list.add_child(row)
		_enemy_rows[e] = row

func _disconnect_hp_and_free(row: Control) -> void:
	if row.has_meta("_unit_hp") and row.has_meta("_hp_callable"):
		var u: Unit = row.get_meta("_unit_hp")
		var callable: Callable = row.get_meta("_hp_callable")
		if is_instance_valid(u) and u.hp_changed.is_connected(callable):
			u.hp_changed.disconnect(callable)
	row.queue_free()

func _make_unit_row(u: Unit, clickable: bool) -> Button:
	var btn := Button.new()
	btn.text = ""
	btn.toggle_mode = clickable
	btn.button_mask = MOUSE_BUTTON_MASK_LEFT
	btn.focus_mode = Control.FOCUS_NONE
	btn.flat = true
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.custom_minimum_size = Vector2(0, 72)

	var outer := HBoxContainer.new()
	outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_theme_constant_override("separation", 12)
	outer.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var name_label := Label.new()
	name_label.text = u.display_name
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var hp := ProgressBar.new()
	hp.min_value = 0
	hp.max_value = u.max_hp
	hp.value = u.hp
	hp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hp.custom_minimum_size = Vector2(220, 20)
	hp.mouse_filter = Control.MOUSE_FILTER_IGNORE

	outer.add_child(name_label)
	outer.add_child(hp)

	btn.add_child(outer)

	var update_hp := func(_unit: Unit) -> void:
		if not is_instance_valid(hp):
			return
		hp.max_value = _unit.max_hp
		hp.value = _unit.hp
	u.hp_changed.connect(update_hp)
	btn.set_meta("_unit_hp", u)
	btn.set_meta("_hp_callable", update_hp)

	if clickable:
		btn.pressed.connect(func():
			if combat.state == CombatManager.State.SELECTING_TARGET and _current and _current.team == Unit.Team.PLAYER and u.alive:
				_select_enemy_target(u)
		)

	return btn
