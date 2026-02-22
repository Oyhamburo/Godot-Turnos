extends Control
class_name RogueShopPanel
##
## Panel de tienda del modo RogueLike.
## Permite comprar items, armas y curarse.
## Construido 100% por código en _init().
##

signal continuar_presionado

const C_BG        := Color(0.05, 0.06, 0.10, 0.97)
const C_PANEL     := Color(0.10, 0.11, 0.18, 0.99)
const C_GOLD      := Color(1.0, 0.85, 0.3, 1.0)
const C_HEADER    := Color(0.65, 0.72, 0.92, 1.0)
const C_HEAL      := Color(0.3, 0.85, 0.4, 1.0)
const C_MSG_OK    := Color(0.4, 0.9, 0.45, 1.0)
const C_MSG_ERR   := Color(1.0, 0.4, 0.4, 1.0)

var _gold_label: Label
var _hp_label: Label
var _msg_label: Label
var _heal_btn: Button
var _continuar_btn: Button
var _items_container: VBoxContainer
var _msg_timer: float = 0.0

## Items disponibles para comprar.
var _catalogo: Array = []


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
	panel.custom_minimum_size = Vector2(700, 0)
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
	margin.add_theme_constant_override("margin_left", 26)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 26)
	margin.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	# Título
	var titulo := Label.new()
	titulo.text = "Tienda"
	titulo.add_theme_font_size_override("font_size", 28)
	titulo.add_theme_color_override("font_color", C_HEADER)
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(titulo)

	# Info: oro + HP
	var info_hbox := HBoxContainer.new()
	info_hbox.add_theme_constant_override("separation", 30)
	info_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(info_hbox)

	_gold_label = Label.new()
	_gold_label.add_theme_font_size_override("font_size", 20)
	_gold_label.add_theme_color_override("font_color", C_GOLD)
	info_hbox.add_child(_gold_label)

	_hp_label = Label.new()
	_hp_label.add_theme_font_size_override("font_size", 20)
	_hp_label.add_theme_color_override("font_color", C_HEAL)
	info_hbox.add_child(_hp_label)

	# Separador
	var sep1 := HSeparator.new()
	sep1.modulate = Color(1, 1, 1, 0.2)
	vbox.add_child(sep1)

	# Botón curar
	_heal_btn = Button.new()
	_heal_btn.custom_minimum_size = Vector2(0, 50)
	_heal_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(_heal_btn)

	# Separador
	var sep2 := HSeparator.new()
	sep2.modulate = Color(1, 1, 1, 0.2)
	vbox.add_child(sep2)

	# Label "Items disponibles:"
	var items_titulo := Label.new()
	items_titulo.text = "Items disponibles:"
	items_titulo.add_theme_font_size_override("font_size", 18)
	vbox.add_child(items_titulo)

	# ScrollContainer para items
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 300)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	_items_container = VBoxContainer.new()
	_items_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_items_container.add_theme_constant_override("separation", 6)
	scroll.add_child(_items_container)

	# Mensaje temporal
	_msg_label = Label.new()
	_msg_label.add_theme_font_size_override("font_size", 16)
	_msg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_msg_label.visible = false
	vbox.add_child(_msg_label)

	# Botón continuar
	_continuar_btn = Button.new()
	_continuar_btn.text = "Continuar"
	_continuar_btn.custom_minimum_size = Vector2(200, 50)
	_continuar_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(_continuar_btn)


func _ready() -> void:
	_heal_btn.pressed.connect(_on_curar)
	_continuar_btn.pressed.connect(_on_continuar)


func _process(delta: float) -> void:
	if _msg_timer > 0:
		_msg_timer -= delta
		if _msg_timer <= 0:
			_msg_label.visible = false


## Muestra el panel con el catálogo de items.
func mostrar(ronda: int) -> void:
	_poblar_catalogo()
	_actualizar_info()
	_actualizar_heal_btn(ronda)
	_poblar_items()
	visible = true


func _actualizar_info() -> void:
	var rm: Node = Engine.get_main_loop().root.get_node_or_null("RogueManager")
	if rm and rm.rogue_inventory:
		_gold_label.text = "Oro: %d" % rm.rogue_inventory.gold
	else:
		_gold_label.text = "Oro: 0"
	if rm:
		_hp_label.text = "HP: %d/%d" % [rm.player_hp, rm.player_max_hp]
	else:
		_hp_label.text = "HP: ?/?"


func _actualizar_heal_btn(ronda: int) -> void:
	var costo: int = 30 + 10 * ronda
	var rm: Node = Engine.get_main_loop().root.get_node_or_null("RogueManager")
	var ya_curado: bool = rm and rm.player_hp >= rm.player_max_hp
	_heal_btn.text = "Curar completamente — %d oro" % costo
	_heal_btn.disabled = ya_curado
	# Guardar costo para usar en _on_curar
	_heal_btn.set_meta("costo", costo)


func _poblar_catalogo() -> void:
	_catalogo.clear()
	# Pociones básicas
	var paths: Array[String] = [
		"res://data/items/pocion_vida.tres",
		"res://data/items/pocion_mana.tres",
		"res://data/items/antidoto.tres",
		"res://data/items/pocion_fuerza.tres",
		"res://data/items/pocion_sigilo.tres",
	]
	for path in paths:
		if ResourceLoader.exists(path):
			var item: ItemData = load(path) as ItemData
			if item:
				_catalogo.append(item)


func _poblar_items() -> void:
	for child in _items_container.get_children():
		child.queue_free()
	for item in _catalogo:
		var row := _crear_fila_item(item)
		_items_container.add_child(row)


func _crear_fila_item(item: ItemData) -> HBoxContainer:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)

	var nombre := Label.new()
	nombre.text = item.display_name
	nombre.add_theme_font_size_override("font_size", 16)
	nombre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(nombre)

	var desc := Label.new()
	desc.text = item.description if item.description else ""
	desc.add_theme_font_size_override("font_size", 14)
	desc.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(desc)

	var precio := Label.new()
	precio.text = "%d oro" % item.buy_price
	precio.add_theme_font_size_override("font_size", 16)
	precio.add_theme_color_override("font_color", C_GOLD)
	precio.custom_minimum_size = Vector2(80, 0)
	precio.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hbox.add_child(precio)

	var btn := Button.new()
	btn.text = "Comprar"
	btn.custom_minimum_size = Vector2(100, 34)
	btn.pressed.connect(_on_comprar.bind(item))
	hbox.add_child(btn)

	return hbox


func _on_comprar(item: ItemData) -> void:
	var rm: Node = Engine.get_main_loop().root.get_node_or_null("RogueManager")
	if not rm or not rm.rogue_inventory:
		return
	if rm.rogue_inventory.spend_gold(item.buy_price):
		rm.rogue_inventory.add_item(item)
		_mostrar_msg("Comprado: %s" % item.display_name, true)
		_actualizar_info()
	else:
		_mostrar_msg("Oro insuficiente", false)


func _on_curar() -> void:
	var rm: Node = Engine.get_main_loop().root.get_node_or_null("RogueManager")
	if not rm or not rm.rogue_inventory:
		return
	var costo: int = _heal_btn.get_meta("costo", 50) as int
	if rm.rogue_inventory.spend_gold(costo):
		rm.curar_completo()
		_mostrar_msg("Curado completamente!", true)
		_actualizar_info()
		_heal_btn.disabled = true
	else:
		_mostrar_msg("Oro insuficiente para curar", false)


func _mostrar_msg(texto: String, ok: bool) -> void:
	_msg_label.text = texto
	_msg_label.add_theme_color_override("font_color", C_MSG_OK if ok else C_MSG_ERR)
	_msg_label.visible = true
	_msg_timer = 3.0


func _on_continuar() -> void:
	visible = false
	continuar_presionado.emit()
