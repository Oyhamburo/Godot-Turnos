extends CanvasLayer
class_name BattleHUD
##
## HUD de combate: timeline de turnos, menú de acciones, menú de ataques e ítems.
## Crea toda la UI por código para evitar problemas de escena/nodos.
##

signal action_selected(action: String)       # "attack", "move", "item", "end_turn"
signal attack_selected(index: int)           # 0-3
signal item_selected(index: int)             # 0-2
signal back_from_attack()
signal back_from_item()

const _TurnSlotScene = preload("res://scenes/ui/TurnSlot.tscn")

var timeline_hbox: HBoxContainer
var turn_label: Label

var action_panel: PanelContainer
var attack_btn: Button
var move_btn: Button
var item_btn: Button
var end_turn_btn: Button

var ap_sp_panel: PanelContainer
var ap_label: Label
var sp_label: Label

var attack_panel: PanelContainer
var attack_btn_1: Button
var attack_btn_2: Button
var attack_btn_3: Button
var attack_btn_4: Button
var attack_back_btn: Button

var item_panel: PanelContainer
var item_btn_1: Button
var item_btn_2: Button
var item_btn_3: Button
var item_back_btn: Button


func _ready() -> void:
	layer = 10
	_build_ui()

	# Conectar botones del panel de acciones
	attack_btn.pressed.connect(func() -> void: _on_action("attack"))
	move_btn.pressed.connect(func() -> void: _on_action("move"))
	item_btn.pressed.connect(func() -> void: _on_action("item"))
	end_turn_btn.pressed.connect(func() -> void: _on_action("end_turn"))

	# Conectar botones de ataque
	attack_btn_1.pressed.connect(func() -> void: _on_attack(0))
	attack_btn_2.pressed.connect(func() -> void: _on_attack(1))
	attack_btn_3.pressed.connect(func() -> void: _on_attack(2))
	attack_btn_4.pressed.connect(func() -> void: _on_attack(3))
	attack_back_btn.pressed.connect(_on_attack_back)

	# Conectar botones de items
	item_btn_1.pressed.connect(func() -> void: _on_item(0))
	item_btn_2.pressed.connect(func() -> void: _on_item(1))
	item_btn_3.pressed.connect(func() -> void: _on_item(2))
	item_back_btn.pressed.connect(_on_item_back)

	# Todo oculto al inicio
	hide_all_menus()
	turn_label.text = ""
	print("[BattleHUD] _ready() - HUD inicializado por código")


# ── BUILD UI ───────────────────────────────────────────────

func _build_ui() -> void:
	# Root control (full rect, no bloquea mouse)
	var root := Control.new()
	root.name = "Root"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# ── Timeline (arriba-izquierda) ──
	var timeline_panel := PanelContainer.new()
	timeline_panel.name = "TimelinePanel"
	timeline_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	timeline_panel.position = Vector2(16, 16)
	timeline_panel.custom_minimum_size = Vector2(600, 64)
	timeline_panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.08, 0.08, 0.12, 0.85), 8))
	root.add_child(timeline_panel)

	timeline_hbox = HBoxContainer.new()
	timeline_hbox.name = "TimelineHBox"
	timeline_hbox.add_theme_constant_override("separation", 6)
	timeline_panel.add_child(timeline_hbox)

	# ── Turn Label (arriba-centro) ──
	turn_label = Label.new()
	turn_label.name = "TurnLabel"
	turn_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	turn_label.offset_left = -200
	turn_label.offset_top = 16
	turn_label.offset_right = 200
	turn_label.offset_bottom = 56
	turn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	turn_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	turn_label.add_theme_font_size_override("font_size", 22)
	turn_label.add_theme_color_override("font_color", Color.WHITE)
	turn_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	turn_label.add_theme_constant_override("outline_size", 4)
	root.add_child(turn_label)

	# ── AP/SP Panel (derecha, arriba del action panel) ──
	ap_sp_panel = PanelContainer.new()
	ap_sp_panel.name = "APSPPanel"
	ap_sp_panel.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	ap_sp_panel.anchor_left = 1.0
	ap_sp_panel.anchor_top = 0.5
	ap_sp_panel.anchor_right = 1.0
	ap_sp_panel.anchor_bottom = 0.5
	ap_sp_panel.offset_left = -204 - 16
	ap_sp_panel.offset_top = -230 / 2.0 - 52
	ap_sp_panel.offset_right = -16
	ap_sp_panel.offset_bottom = -230 / 2.0 - 4
	ap_sp_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	ap_sp_panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.08, 0.1, 0.18, 0.9), 8))
	ap_sp_panel.visible = false
	root.add_child(ap_sp_panel)

	var ap_sp_hbox := HBoxContainer.new()
	ap_sp_hbox.add_theme_constant_override("separation", 16)
	ap_sp_panel.add_child(ap_sp_hbox)

	ap_label = Label.new()
	ap_label.text = "AP: 1/1"
	ap_label.add_theme_font_size_override("font_size", 16)
	ap_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	ap_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	ap_label.add_theme_constant_override("outline_size", 3)
	ap_sp_hbox.add_child(ap_label)

	sp_label = Label.new()
	sp_label.text = "SP: 2/2"
	sp_label.add_theme_font_size_override("font_size", 16)
	sp_label.add_theme_color_override("font_color", Color(0.4, 0.85, 1.0))
	sp_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	sp_label.add_theme_constant_override("outline_size", 3)
	ap_sp_hbox.add_child(sp_label)

	# ── Action Panel (derecha-centro) ──
	action_panel = _make_menu_panel(root, "ActionPanel", Vector2(204, 230))
	var action_vbox := VBoxContainer.new()
	action_vbox.add_theme_constant_override("separation", 8)
	action_panel.add_child(action_vbox)
	attack_btn = _make_button("Atacar")
	move_btn = _make_button("Mover")
	item_btn = _make_button("Item")
	end_turn_btn = _make_button("Fin Turno")
	action_vbox.add_child(attack_btn)
	action_vbox.add_child(move_btn)
	action_vbox.add_child(item_btn)
	action_vbox.add_child(end_turn_btn)

	# ── Attack Panel (derecha-centro) ──
	attack_panel = _make_menu_panel(root, "AttackPanel", Vector2(264, 280))
	var attack_vbox := VBoxContainer.new()
	attack_vbox.add_theme_constant_override("separation", 6)
	attack_panel.add_child(attack_vbox)
	attack_btn_1 = _make_button("Ataque 1")
	attack_btn_2 = _make_button("Ataque 2")
	attack_btn_3 = _make_button("Ataque 3")
	attack_btn_4 = _make_button("Ataque 4")
	attack_back_btn = _make_button("Volver")
	attack_vbox.add_child(attack_btn_1)
	attack_vbox.add_child(attack_btn_2)
	attack_vbox.add_child(attack_btn_3)
	attack_vbox.add_child(attack_btn_4)
	attack_vbox.add_child(attack_back_btn)

	# ── Item Panel (derecha-centro) ──
	item_panel = _make_menu_panel(root, "ItemPanel", Vector2(234, 220))
	var item_vbox := VBoxContainer.new()
	item_vbox.add_theme_constant_override("separation", 6)
	item_panel.add_child(item_vbox)
	item_btn_1 = _make_button("Pocion HP")
	item_btn_2 = _make_button("Pocion Mana")
	item_btn_3 = _make_button("Antidoto")
	item_back_btn = _make_button("Volver")
	item_vbox.add_child(item_btn_1)
	item_vbox.add_child(item_btn_2)
	item_vbox.add_child(item_btn_3)
	item_vbox.add_child(item_back_btn)


func _make_menu_panel(parent: Control, panel_name: String, size: Vector2) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = panel_name
	panel.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	panel.anchor_left = 1.0
	panel.anchor_top = 0.5
	panel.anchor_right = 1.0
	panel.anchor_bottom = 0.5
	panel.offset_left = -size.x - 16
	panel.offset_top = -size.y / 2.0
	panel.offset_right = -16
	panel.offset_bottom = size.y / 2.0
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.add_theme_stylebox_override("panel", _make_panel_style(Color(0.1, 0.1, 0.15, 0.9), 10))
	panel.visible = false
	parent.add_child(panel)
	return panel


func _make_button(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.add_theme_stylebox_override("normal", _make_btn_style(Color(0.18, 0.2, 0.28, 1.0)))
	btn.add_theme_stylebox_override("hover", _make_btn_style(Color(0.28, 0.32, 0.45, 1.0)))
	btn.add_theme_stylebox_override("pressed", _make_btn_style(Color(0.35, 0.45, 0.65, 1.0)))
	var focus_style := _make_btn_style(Color(0.22, 0.26, 0.38, 1.0))
	focus_style.border_width_left = 2
	focus_style.border_width_top = 2
	focus_style.border_width_right = 2
	focus_style.border_width_bottom = 2
	focus_style.border_color = Color(0.55, 0.7, 1.0, 0.8)
	btn.add_theme_stylebox_override("focus", focus_style)
	return btn


func _make_panel_style(color: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.content_margin_left = 16
	style.content_margin_top = 12
	style.content_margin_right = 16
	style.content_margin_bottom = 12
	return style


func _make_btn_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 16
	style.content_margin_top = 10
	style.content_margin_right = 16
	style.content_margin_bottom = 10
	return style


# ── PUBLIC API ─────────────────────────────────────────────

## Construye/actualiza la timeline con el orden de turnos.
func update_timeline(turn_order: Array, current_index: int) -> void:
	for child in timeline_hbox.get_children():
		child.queue_free()

	for i in range(turn_order.size()):
		var unit: Unit = turn_order[i] as Unit
		if not unit or not unit.alive:
			continue
		var slot: PanelContainer = _TurnSlotScene.instantiate()
		timeline_hbox.add_child(slot)
		slot.setup(unit, i == current_index)

	print("[BattleHUD] Timeline actualizada: %d unidades, turno actual: %d" % [turn_order.size(), current_index])


func show_turn_label(unit_name: String) -> void:
	turn_label.text = "Turno: %s" % unit_name
	print("[BattleHUD] Turno: %s" % unit_name)


func show_action_menu() -> void:
	hide_all_menus()
	action_panel.visible = true
	ap_sp_panel.visible = true
	attack_btn.grab_focus()
	print("[BattleHUD] Mostrando menú de acciones")


func show_attack_menu(unit: Unit, melee_available: bool = false) -> void:
	hide_all_menus()
	attack_panel.visible = true

	var buttons: Array[Button] = [attack_btn_1, attack_btn_2, attack_btn_3, attack_btn_4]
	for i in range(4):
		var ab: Dictionary = Unit.get_ability(unit, i)
		var phys: int = ab.get("physical", 0)
		var mag: int = ab.get("magic", 0)
		var hit: float = ab.get("hit_chance", 1.0)
		var atk_range: int = ab.get("range", 99)
		var is_melee: bool = atk_range <= 1
		var type_str: String = "Fís" if phys > 0 else "Mág"
		var dmg: int = phys if phys > 0 else mag
		var range_icon: String = "⚔" if is_melee else "🏹"

		buttons[i].text = "%s %s %d, %d%%" % [range_icon, type_str, dmg, int(hit * 100)]

		# Deshabilitar ataques melee si no hay enemigo adyacente
		if is_melee and not melee_available:
			buttons[i].disabled = true
			buttons[i].modulate = Color(0.5, 0.5, 0.5, 0.7)
			buttons[i].text += " (fuera de rango)"
		else:
			buttons[i].disabled = false
			buttons[i].modulate = Color.WHITE

	attack_btn_1.grab_focus()
	print("[BattleHUD] Mostrando menú de ataques para %s (melee: %s)" % [unit.display_name, melee_available])


func show_item_menu() -> void:
	hide_all_menus()
	item_panel.visible = true
	item_btn_1.grab_focus()
	print("[BattleHUD] Mostrando menú de ítems")


func hide_all_menus() -> void:
	action_panel.visible = false
	attack_panel.visible = false
	item_panel.visible = false
	ap_sp_panel.visible = false


func hide_hud() -> void:
	hide_all_menus()
	turn_label.text = ""
	for child in timeline_hbox.get_children():
		child.queue_free()


## Actualiza los labels de AP y SP.
func update_ap_sp(ap: int, max_ap: int, sp: int, max_sp: int) -> void:
	if ap_label:
		ap_label.text = "AP: %d/%d" % [ap, max_ap]
	if sp_label:
		sp_label.text = "SP: %d/%d" % [sp, max_sp]


## Habilita/deshabilita el botón Atacar (AP > 0).
func set_attack_enabled(enabled: bool) -> void:
	if attack_btn:
		attack_btn.disabled = not enabled
		attack_btn.modulate = Color.WHITE if enabled else Color(0.5, 0.5, 0.5, 0.7)


## Habilita/deshabilita el botón Mover (SP > 0).
func set_move_enabled(enabled: bool) -> void:
	if move_btn:
		move_btn.disabled = not enabled
		move_btn.modulate = Color.WHITE if enabled else Color(0.5, 0.5, 0.5, 0.7)


# ── SIGNAL HANDLERS ────────────────────────────────────────

func _on_action(action: String) -> void:
	print("[BattleHUD] Acción seleccionada: %s" % action)
	action_selected.emit(action)


func _on_attack(index: int) -> void:
	print("[BattleHUD] Ataque seleccionado: %d" % index)
	attack_selected.emit(index)


func _on_item(index: int) -> void:
	print("[BattleHUD] Item seleccionado: %d" % index)
	item_selected.emit(index)


func _on_attack_back() -> void:
	print("[BattleHUD] Volver desde ataques")
	back_from_attack.emit()


func _on_item_back() -> void:
	print("[BattleHUD] Volver desde ítems")
	back_from_item.emit()
