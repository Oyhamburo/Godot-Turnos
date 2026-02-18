extends PanelContainer
class_name InventoryPanel

## slot: 0 = mano derecha, 1 = mano izquierda
signal weapon_equip_requested(weapon: WeaponData, slot: int)
signal weapon_unequip_requested(slot: int)
signal panel_closed()

var _unit: Unit = null
var _close_btn: Button = null
var _content_vbox: VBoxContainer = null

# Etiquetas de slot equipado
var _right_label: Label = null
var _left_label: Label = null

# Botones de desequipar por slot
var _unequip_right_btn: Button = null
var _unequip_left_btn: Button = null


func _init() -> void:
	_build_ui()


func _build_ui() -> void:
	custom_minimum_size = Vector2(280, 140)

	var bg := _make_panel_style(Color(0.08, 0.08, 0.15, 0.92), 8)
	add_theme_stylebox_override("panel", bg)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	add_child(margin)

	_content_vbox = VBoxContainer.new()
	_content_vbox.add_theme_constant_override("separation", 5)
	margin.add_child(_content_vbox)

	# ── Título ──
	var title := Label.new()
	title.text = "Equipamiento"
	title.add_theme_color_override("font_color", Color(0.9, 0.85, 0.5))
	title.add_theme_font_size_override("font_size", 14)
	_content_vbox.add_child(title)

	# ── Fila: Mano Derecha ──
	var right_row := HBoxContainer.new()
	right_row.add_theme_constant_override("separation", 6)
	_content_vbox.add_child(right_row)

	_right_label = Label.new()
	_right_label.text = "⚔ Der: —"
	_right_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	_right_label.add_theme_font_size_override("font_size", 11)
	_right_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_row.add_child(_right_label)

	_unequip_right_btn = _make_small_button("Deseq.")
	_unequip_right_btn.pressed.connect(func() -> void: weapon_unequip_requested.emit(0))
	right_row.add_child(_unequip_right_btn)

	# ── Fila: Mano Izquierda ──
	var left_row := HBoxContainer.new()
	left_row.add_theme_constant_override("separation", 6)
	_content_vbox.add_child(left_row)

	_left_label = Label.new()
	_left_label.text = "🛡 Izq: —"
	_left_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	_left_label.add_theme_font_size_override("font_size", 11)
	_left_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_row.add_child(_left_label)

	_unequip_left_btn = _make_small_button("Deseq.")
	_unequip_left_btn.pressed.connect(func() -> void: weapon_unequip_requested.emit(1))
	left_row.add_child(_unequip_left_btn)

	# ── Separador ──
	_content_vbox.add_child(HSeparator.new())

	# ── Contenedor dinámico de armas disponibles ──
	var weapons_vbox := VBoxContainer.new()
	weapons_vbox.name = "WeaponsVBox"
	weapons_vbox.add_theme_constant_override("separation", 4)
	_content_vbox.add_child(weapons_vbox)

	# ── Separador + Volver ──
	_content_vbox.add_child(HSeparator.new())

	_close_btn = _make_button("Volver")
	_close_btn.pressed.connect(func() -> void: panel_closed.emit())
	_content_vbox.add_child(_close_btn)


func setup(unit: Unit) -> void:
	_unit = unit
	_refresh()


func _refresh() -> void:
	if not _unit or not _unit.inventory:
		return

	var inv: Inventory = _unit.inventory
	var eq_r: WeaponData = inv.equipped_right
	var eq_l: WeaponData = inv.equipped_left

	# ── Etiquetas de slots ──
	_right_label.text = "⚔ Der: " + (eq_r.display_name if eq_r else "—")
	_unequip_right_btn.disabled = (eq_r == null)
	_unequip_right_btn.modulate = Color.WHITE if eq_r else Color(0.5, 0.5, 0.5, 0.7)

	# Mano izquierda: si es 2H, mostrarla como bloqueada
	if eq_r != null and eq_r == eq_l:
		_left_label.text = "🛡 Izq: (2H — bloqueada)"
		_left_label.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
		_unequip_left_btn.disabled = true
		_unequip_left_btn.modulate = Color(0.5, 0.5, 0.5, 0.7)
	else:
		_left_label.text = "🛡 Izq: " + (eq_l.display_name if eq_l else "—")
		_left_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
		_unequip_left_btn.disabled = (eq_l == null)
		_unequip_left_btn.modulate = Color.WHITE if eq_l else Color(0.5, 0.5, 0.5, 0.7)

	# ── Limpiar botones de armas disponibles ──
	var weapons_vbox: VBoxContainer = _content_vbox.get_node("WeaponsVBox")
	for c in weapons_vbox.get_children():
		c.queue_free()

	var available: Array[WeaponData] = inv.get_available_weapons()
	if available.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "Sin armas adicionales"
		empty_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		empty_lbl.add_theme_font_size_override("font_size", 11)
		weapons_vbox.add_child(empty_lbl)
	else:
		for weapon in available:
			var w := weapon  # captura local para closures
			if w.slot == WeaponData.SlotMode.TWO_HANDED:
				# Arma 2H: un solo botón que equipa en mano derecha
				var row := HBoxContainer.new()
				row.add_theme_constant_override("separation", 4)
				weapons_vbox.add_child(row)
				var lbl := Label.new()
				lbl.text = w.display_name + " (2M)"
				lbl.add_theme_color_override("font_color", Color(0.9, 0.75, 0.3))
				lbl.add_theme_font_size_override("font_size", 11)
				lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				row.add_child(lbl)
				var equip_btn := _make_small_button("Equipar")
				equip_btn.pressed.connect(func() -> void: weapon_equip_requested.emit(w, 0))
				row.add_child(equip_btn)
			else:
				# Arma 1H: botones "→R" y "→L"
				var row := HBoxContainer.new()
				row.add_theme_constant_override("separation", 4)
				weapons_vbox.add_child(row)
				var lbl := Label.new()
				lbl.text = w.display_name
				lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
				lbl.add_theme_font_size_override("font_size", 11)
				lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				row.add_child(lbl)
				var btn_r := _make_small_button("→R")
				btn_r.pressed.connect(func() -> void: weapon_equip_requested.emit(w, 0))
				row.add_child(btn_r)
				var btn_l := _make_small_button("→L")
				btn_l.pressed.connect(func() -> void: weapon_equip_requested.emit(w, 1))
				row.add_child(btn_l)

	# ── Ajustar tamaño mínimo según contenido ──
	var row_count: int = maxi(1, available.size()) + 6
	custom_minimum_size.y = row_count * 32 + 40


func _make_button(label_text: String) -> Button:
	var btn := Button.new()
	btn.text = label_text
	btn.custom_minimum_size = Vector2(0, 28)
	btn.add_theme_font_size_override("font_size", 12)

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.15, 0.15, 0.28, 0.9)
	normal.corner_radius_top_left = 4
	normal.corner_radius_top_right = 4
	normal.corner_radius_bottom_left = 4
	normal.corner_radius_bottom_right = 4
	btn.add_theme_stylebox_override("normal", normal)

	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.22, 0.22, 0.42, 1.0)
	btn.add_theme_stylebox_override("hover", hover)

	var pressed_style := normal.duplicate() as StyleBoxFlat
	pressed_style.bg_color = Color(0.1, 0.1, 0.22, 1.0)
	btn.add_theme_stylebox_override("pressed", pressed_style)

	btn.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))
	return btn


func _make_small_button(label_text: String) -> Button:
	var btn := _make_button(label_text)
	btn.custom_minimum_size = Vector2(48, 24)
	btn.add_theme_font_size_override("font_size", 10)
	return btn


func _make_panel_style(color: Color, radius: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.corner_radius_top_left = radius
	sb.corner_radius_top_right = radius
	sb.corner_radius_bottom_left = radius
	sb.corner_radius_bottom_right = radius
	return sb
