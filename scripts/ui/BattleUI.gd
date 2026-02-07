extends Control

@export var combat_manager_path: NodePath
@export var camera_path: NodePath

@onready var timeline_hbox: HBoxContainer = %TimelineHBox
@onready var players_list: VBoxContainer = %PlayersList
@onready var enemies_list: VBoxContainer = %EnemiesList
@onready var turn_label: Label = %TurnLabel
@onready var attack_button: Button = %AttackButton
@onready var pass_button: Button = %PassButton
@onready var end_dialog: Control = %EndDialog
@onready var end_label: Label = %EndLabel
@onready var end_accept: Button = %EndAccept

var combat: CombatManager
var cam: Camera3D

var _current: Unit
var _selected_target: Unit
var _enemy_rows := {} # Unit -> Button

var _turn_slot_scene := preload("res://scenes/ui/TurnSlot.tscn")

func _ready() -> void:
	combat = get_node(combat_manager_path)
	cam = get_node(camera_path)

	attack_button.pressed.connect(_on_attack_pressed)
	pass_button.pressed.connect(_on_pass_pressed)
	end_accept.pressed.connect(_on_end_accept)

	end_dialog.visible = false
	attack_button.disabled = true

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

func _on_timeline_updated(order, current) -> void:
	_rebuild_timeline(order, current)

func _on_turn_changed(current: Unit) -> void:
	_current = current
	_selected_target = null
	_clear_enemy_selection_highlights()
	attack_button.disabled = true

	if _current:
		turn_label.text = "Turno: %s" % _current.display_name
	else:
		turn_label.text = "Turno: -"

func _on_state_changed(state: int) -> void:
	var selecting := (state == CombatManager.State.SELECTING_TARGET)
	pass_button.disabled = not selecting
	if not selecting:
		attack_button.disabled = true

func _on_unit_died(_unit: Unit) -> void:
	_rebuild_unit_lists(combat.players, combat.enemies)

func _on_battle_ended(player_won: bool) -> void:
	end_dialog.visible = true
	end_label.text = "¡Ganaste!" if player_won else "Perdiste"
	attack_button.disabled = true
	pass_button.disabled = true

func _on_end_accept() -> void:
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

func _on_attack_pressed() -> void:
	if _current == null or _selected_target == null:
		return
	combat.player_attack(_current, _selected_target)

func _on_pass_pressed() -> void:
	combat.player_pass()

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
	var from: Vector3 = cam.project_ray_origin(screen_pos)
	var to: Vector3 = from + cam.project_ray_normal(screen_pos) * 2000.0

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
	attack_button.disabled = false

	# Also visually mark the row.
	if _enemy_rows.has(target):
		var btn: Button = _enemy_rows[target]
		btn.button_pressed = true

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
