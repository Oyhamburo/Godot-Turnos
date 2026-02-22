extends Control
class_name RogueRewardPanel
##
## Panel de recompensa del modo RogueLike.
## Muestra oro ganado, interés, 3 items para elegir y poción bonus.
## Construido 100% por código en _init().
##

signal continuar_presionado

const C_BG        := Color(0.05, 0.06, 0.10, 0.97)
const C_PANEL     := Color(0.10, 0.11, 0.18, 0.99)
const C_GOLD      := Color(1.0, 0.85, 0.3, 1.0)
const C_HEADER    := Color(0.65, 0.72, 0.92, 1.0)
const C_BUFF      := Color(0.3, 0.85, 0.4, 1.0)
const C_ITEM_BG   := Color(0.14, 0.15, 0.22, 1.0)
const C_ITEM_HOVER := Color(0.22, 0.25, 0.38, 1.0)
const C_SELECTED  := Color(0.3, 0.6, 1.0, 1.0)

var _titulo_label: Label
var _oro_label: Label
var _interes_label: Label
var _items_container: HBoxContainer
var _pocion_label: Label
var _continuar_btn: Button

var _items_ofrecidos: Array = []
var _item_elegido = null
var _item_buttons: Array[Button] = []
var _pocion_bonus: ItemData = null


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	# Fondo oscuro
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.6)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	# Centro
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	# Panel principal
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(900, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = C_PANEL
	style.corner_radius_top_left = 12; style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12; style.corner_radius_bottom_right = 12
	style.border_color = Color(0.3, 0.35, 0.5, 1.0)
	style.border_width_left = 2; style.border_width_right = 2
	style.border_width_top = 2; style.border_width_bottom = 2
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_bottom", 24)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	margin.add_child(vbox)

	# Título
	_titulo_label = Label.new()
	_titulo_label.text = "Recompensa"
	_titulo_label.add_theme_font_size_override("font_size", 28)
	_titulo_label.add_theme_color_override("font_color", C_HEADER)
	_titulo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_titulo_label)

	# Oro ganado
	_oro_label = Label.new()
	_oro_label.add_theme_font_size_override("font_size", 20)
	_oro_label.add_theme_color_override("font_color", C_GOLD)
	_oro_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_oro_label)

	# Interés
	_interes_label = Label.new()
	_interes_label.add_theme_font_size_override("font_size", 16)
	_interes_label.add_theme_color_override("font_color", C_BUFF)
	_interes_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_interes_label)

	# Separador
	var sep1 := HSeparator.new()
	sep1.modulate = Color(1, 1, 1, 0.2)
	vbox.add_child(sep1)

	# Label "Elige un objeto:"
	var elegir_lbl := Label.new()
	elegir_lbl.text = "Elige un objeto:"
	elegir_lbl.add_theme_font_size_override("font_size", 18)
	elegir_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(elegir_lbl)

	# Contenedor de items (3 cards)
	_items_container = HBoxContainer.new()
	_items_container.add_theme_constant_override("separation", 16)
	_items_container.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(_items_container)

	# Poción bonus
	_pocion_label = Label.new()
	_pocion_label.add_theme_font_size_override("font_size", 16)
	_pocion_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pocion_label.visible = false
	vbox.add_child(_pocion_label)

	# Separador
	var sep2 := HSeparator.new()
	sep2.modulate = Color(1, 1, 1, 0.2)
	vbox.add_child(sep2)

	# Botón continuar
	_continuar_btn = Button.new()
	_continuar_btn.text = "Continuar"
	_continuar_btn.custom_minimum_size = Vector2(200, 50)
	_continuar_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_continuar_btn.disabled = true
	vbox.add_child(_continuar_btn)


func _ready() -> void:
	_continuar_btn.pressed.connect(_on_continuar)


## Configura y muestra el panel con los datos de la recompensa.
func mostrar(ronda: int, paso_nombre: String, oro_ganado: int, interes: int, items: Array, pocion: ItemData) -> void:
	_titulo_label.text = "Ronda %d - %s" % [ronda + 1, paso_nombre]
	_oro_label.text = "Oro ganado: +%d" % oro_ganado
	if interes > 0:
		_interes_label.text = "Interés: +%d (oro/%d = %d, max %d)" % [interes, 5, interes, 5]
		_interes_label.visible = true
	else:
		_interes_label.visible = false

	_items_ofrecidos = items
	_item_elegido = null
	_item_buttons.clear()
	_pocion_bonus = pocion
	_continuar_btn.disabled = true

	# Limpiar cards previas
	for child in _items_container.get_children():
		child.queue_free()

	# Crear cards de items
	for i in range(items.size()):
		var item = items[i]
		var card := _crear_card_item(item, i)
		_items_container.add_child(card)

	# Poción bonus
	if pocion:
		_pocion_label.text = "Poción bonus: %s" % pocion.display_name
		_pocion_label.add_theme_color_override("font_color", C_BUFF)
		_pocion_label.visible = true
	else:
		_pocion_label.visible = false

	visible = true


func _crear_card_item(item, index: int) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(250, 160)
	var style := StyleBoxFlat.new()
	style.bg_color = C_ITEM_BG
	style.corner_radius_top_left = 8; style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8; style.corner_radius_bottom_right = 8
	card.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	card.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	# Nombre del item
	var nombre := Label.new()
	nombre.text = item.display_name if "display_name" in item else str(item)
	nombre.add_theme_font_size_override("font_size", 18)
	nombre.add_theme_color_override("font_color", C_HEADER)
	nombre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(nombre)

	# Stats resumidos
	var stats_text := ""
	if item is WeaponData:
		var w: WeaponData = item as WeaponData
		if w.bonus_physical_damage > 0:
			stats_text += "Fis: +%d  " % w.bonus_physical_damage
		if w.bonus_magic_damage > 0:
			stats_text += "Mag: +%d  " % w.bonus_magic_damage
		if w.bonus_armor > 0:
			stats_text += "Arm: +%d  " % w.bonus_armor
		if w.bonus_evasion > 0:
			stats_text += "Eva: +%d%%  " % int(w.bonus_evasion * 100)
		var tipo_nombre: String = WeaponData.WeaponType.keys()[w.weapon_type] if w.weapon_type < WeaponData.WeaponType.size() else "?"
		stats_text = tipo_nombre + "\n" + stats_text
	elif item is ArmorData:
		stats_text = "Armadura"

	var stats_lbl := Label.new()
	stats_lbl.text = stats_text.strip_edges()
	stats_lbl.add_theme_font_size_override("font_size", 14)
	stats_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	stats_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(stats_lbl)

	# Botón elegir
	var btn := Button.new()
	btn.text = "Elegir"
	btn.custom_minimum_size = Vector2(0, 36)
	btn.pressed.connect(_on_item_elegido.bind(index))
	vbox.add_child(btn)
	_item_buttons.append(btn)

	return card


func _on_item_elegido(index: int) -> void:
	if index < 0 or index >= _items_ofrecidos.size():
		return
	_item_elegido = _items_ofrecidos[index]

	# Visual: desactivar otros botones, resaltar el elegido
	for i in range(_item_buttons.size()):
		_item_buttons[i].disabled = true
		if i == index:
			_item_buttons[i].text = "Elegido"

	# Agregar al inventario
	var rm: Node = Engine.get_main_loop().root.get_node_or_null("RogueManager")
	if rm and rm.rogue_inventory:
		if _item_elegido is WeaponData:
			rm.rogue_inventory.add_weapon(_item_elegido)
		else:
			rm.rogue_inventory.add_item_generic(_item_elegido)

	# Agregar poción bonus si hay
	if _pocion_bonus and rm and rm.rogue_inventory:
		rm.rogue_inventory.add_item(_pocion_bonus)

	_continuar_btn.disabled = false


func _on_continuar() -> void:
	visible = false
	continuar_presionado.emit()
