extends PanelContainer
class_name ShopPanel
##
## Panel de tienda: lista de ítems a comprar (izquierda) + inventario del jugador
## para vender (derecha) + saldo de oro.
## Construido 100% por código.
##

## Emitido al cerrar el panel.
signal panel_closed

const C_BG        := Color(0.07, 0.08, 0.13, 0.97)
const C_PANEL_BG  := Color(0.10, 0.11, 0.18, 0.99)
const C_HEADER    := Color(0.65, 0.72, 0.92, 1.0)
const C_SEPARATOR := Color(0.25, 0.28, 0.40, 1.0)
const C_BTN_BG    := Color(0.18, 0.20, 0.28, 1.0)
const C_BTN_HOVER := Color(0.28, 0.32, 0.45, 1.0)
const C_GOLD      := Color(1.0, 0.85, 0.3, 1.0)
const C_MSG_OK    := Color(0.4, 0.9, 0.45, 1.0)
const C_MSG_ERR   := Color(1.0, 0.4, 0.4, 1.0)
const PANEL_SIZE  := Vector2(700, 480)

var _inventory: Inventory = null
## Lista de ítems que ofrece el comerciante.
var _catalogo: Array = []

var _gold_label: Label
var _msg_label: Label
var _msg_timer: float = 0.0

var _tienda_list: VBoxContainer      # filas del catálogo
var _inventario_list: VBoxContainer  # filas del inventario del jugador


func _init() -> void:
	custom_minimum_size = PANEL_SIZE
	_build_ui()
	_poblar_catalogo_demo()


func _build_ui() -> void:
	var bg := StyleBoxFlat.new()
	bg.bg_color = C_PANEL_BG
	bg.border_color = C_SEPARATOR
	bg.border_width_left   = 2; bg.border_width_right  = 2
	bg.border_width_top    = 2; bg.border_width_bottom = 2
	bg.corner_radius_top_left     = 10; bg.corner_radius_top_right    = 10
	bg.corner_radius_bottom_left  = 10; bg.corner_radius_bottom_right = 10
	add_theme_stylebox_override("panel", bg)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	add_child(vbox)

	# ── Cabecera ──
	var header := HBoxContainer.new()
	vbox.add_child(header)

	var titulo := Label.new()
	titulo.text = "🛒 MERCADO"
	titulo.add_theme_font_size_override("font_size", 16)
	titulo.add_theme_color_override("font_color", C_HEADER)
	titulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(titulo)

	_gold_label = Label.new()
	_gold_label.text = "🪙 Oro: 0"
	_gold_label.add_theme_font_size_override("font_size", 14)
	_gold_label.add_theme_color_override("font_color", C_GOLD)
	header.add_child(_gold_label)

	var btn_cerrar := _make_button("✕", 28, 28)
	btn_cerrar.pressed.connect(_on_cerrar)
	header.add_child(btn_cerrar)

	var sep := HSeparator.new()
	sep.add_theme_color_override("color", C_SEPARATOR)
	vbox.add_child(sep)

	# ── Mensaje temporal ──
	_msg_label = Label.new()
	_msg_label.add_theme_font_size_override("font_size", 12)
	_msg_label.add_theme_color_override("font_color", C_MSG_OK)
	_msg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_msg_label.visible = false
	vbox.add_child(_msg_label)

	# ── Cuerpo: dos columnas ──
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(hbox)

	# Columna izquierda: catálogo
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 4)
	hbox.add_child(left)

	var lbl_cat := Label.new()
	lbl_cat.text = "▼ Artículos disponibles"
	lbl_cat.add_theme_font_size_override("font_size", 12)
	lbl_cat.add_theme_color_override("font_color", C_HEADER)
	left.add_child(lbl_cat)

	var scroll_cat := ScrollContainer.new()
	scroll_cat.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(scroll_cat)

	_tienda_list = VBoxContainer.new()
	_tienda_list.add_theme_constant_override("separation", 3)
	scroll_cat.add_child(_tienda_list)

	# Separador vertical
	var vsep := VSeparator.new()
	vsep.add_theme_color_override("color", C_SEPARATOR)
	hbox.add_child(vsep)

	# Columna derecha: inventario del jugador
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 4)
	hbox.add_child(right)

	var lbl_inv := Label.new()
	lbl_inv.text = "▼ Tu inventario (vender)"
	lbl_inv.add_theme_font_size_override("font_size", 12)
	lbl_inv.add_theme_color_override("font_color", C_HEADER)
	right.add_child(lbl_inv)

	var scroll_inv := ScrollContainer.new()
	scroll_inv.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(scroll_inv)

	_inventario_list = VBoxContainer.new()
	_inventario_list.add_theme_constant_override("separation", 3)
	scroll_inv.add_child(_inventario_list)


## Vincula el inventario del jugador y refresca la UI.
func setup(inv: Inventory) -> void:
	if _inventory and _inventory.inventory_changed.is_connected(_on_inventory_changed):
		_inventory.inventory_changed.disconnect(_on_inventory_changed)
	_inventory = inv
	if inv:
		inv.inventory_changed.connect(_on_inventory_changed)
	refresh()


## Asigna un catálogo de ítems a la tienda (Array de ItemData/ArmorData/WeaponData).
func set_catalogo(items: Array) -> void:
	_catalogo = items
	_rebuild_tienda()


## Refresca toda la UI.
func refresh() -> void:
	_refresh_gold()
	_rebuild_inventario()


func _refresh_gold() -> void:
	if _inventory and _gold_label:
		_gold_label.text = "🪙 Oro: %d" % _inventory.gold


func _rebuild_tienda() -> void:
	for child in _tienda_list.get_children():
		child.queue_free()
	for item in _catalogo:
		var row := ShopItemRow.new(item, true)
		row.comprar_solicitado.connect(_on_comprar)
		_tienda_list.add_child(row)


func _rebuild_inventario() -> void:
	for child in _inventario_list.get_children():
		child.queue_free()
	if _inventory == null:
		return
	# Añadir ítems genéricos
	for item in _inventory.items_genericos:
		var row := ShopItemRow.new(item, false)
		row.vender_solicitado.connect(_on_vender)
		_inventario_list.add_child(row)
	# Añadir armas no equipadas (solo para vender)
	if _inventory.weapons.size() > 0:
		for weapon in _inventory.weapons:
			if weapon == _inventory.equipped_right or weapon == _inventory.equipped_left:
				continue
			var row := ShopItemRow.new(weapon, false)
			row.vender_solicitado.connect(_on_vender)
			_inventario_list.add_child(row)


func _on_comprar(item) -> void:
	if _inventory == null:
		return
	var precio: int = item.buy_price if "buy_price" in item else 0
	if _inventory.gold < precio:
		_mostrar_mensaje("Sin oro suficiente", false)
		return
	if not _inventory.has_space():
		_mostrar_mensaje("Inventario lleno", false)
		return
	_inventory.spend_gold(precio)
	_inventory.add_item_generic(item.duplicate())  # duplicar para no consumir el catálogo
	_mostrar_mensaje("¡%s comprado!" % (item.display_name if "display_name" in item else "Ítem"), true)


func _on_vender(item) -> void:
	if _inventory == null:
		return
	# Verificar que no esté equipado
	if _inventory.equipment:
		for slot_name in _inventory.equipment.slots:
			if _inventory.equipment.slots[slot_name] == item:
				_mostrar_mensaje("No podés vender ítems equipados", false)
				return
	var precio: int = item.sell_price if "sell_price" in item else 0
	if _inventory.has_item_generic(item):
		_inventory.remove_item_generic(item)
		_inventory.add_gold(precio)
		_mostrar_mensaje("Vendido por 🪙 %d" % precio, true)
	elif _inventory.weapons.has(item):
		_inventory.remove_weapon(item)
		_inventory.add_gold(precio)
		_mostrar_mensaje("Vendido por 🪙 %d" % precio, true)


func _mostrar_mensaje(txt: String, ok: bool) -> void:
	_msg_label.text = txt
	_msg_label.add_theme_color_override(
		"font_color",
		C_MSG_OK if ok else C_MSG_ERR
	)
	_msg_label.visible = true
	_msg_timer = 3.0


func _process(delta: float) -> void:
	if _msg_timer > 0.0:
		_msg_timer -= delta
		if _msg_timer <= 0.0:
			_msg_label.visible = false


func _on_inventory_changed() -> void:
	refresh()


## Catálogo de demo para el Mercado.
## Los modelos 3D usan assets del KayKit Dungeon Remastered pack.
func _poblar_catalogo_demo() -> void:
	const DUNGEON := "res://assets/KayKit_DungeonRemastered_1.1_FREE/Assets/gltf/"

	# Escudo / espada (sword_shield_gold.gltf)
	var escudo := ArmorData.new()
	escudo.display_name = "Escudo de Madera"
	escudo.description  = "Protección básica."
	escudo.armor_slot   = ArmorData.ArmorSlot.OFFHAND
	escudo.stats_mod    = {"def": 3, "weight": 5}
	escudo.buy_price    = 40
	escudo.sell_price   = 15
	escudo.model_path   = DUNGEON + "sword_shield.gltf"

	# Casco → cofre dorado como placeholder visualmente atractivo (chest_gold.gltf)
	var casco := ArmorData.new()
	casco.display_name = "Casco de Cuero"
	casco.description  = "Ligero y resistente."
	casco.armor_slot   = ArmorData.ArmorSlot.HEAD
	casco.stats_mod    = {"def": 2, "weight": 3}
	casco.buy_price    = 30
	casco.sell_price   = 10
	casco.model_path   = DUNGEON + "chest_gold.gltf"

	# Botas → llave como placeholder (key.gltf)
	var botas := ArmorData.new()
	botas.display_name = "Botas de Viaje"
	botas.description  = "Aumentan la velocidad."
	botas.armor_slot   = ArmorData.ArmorSlot.BOOTS
	botas.stats_mod    = {"speed": 2, "weight": 2}
	botas.buy_price    = 25
	botas.sell_price   = 8
	botas.model_path   = DUNGEON + "key.gltf"

	# Poción de HP → botella verde (bottle_A_green.gltf)
	var pocion := ItemData.new()
	pocion.display_name = "Poción de Vida"
	pocion.description  = "Recupera 30 HP."
	pocion.item_type    = ItemData.ItemType.HEAL_HP
	pocion.effect_value = 30
	pocion.buy_price    = 20
	pocion.sell_price   = 5
	pocion.model_path   = DUNGEON + "bottle_A_green.gltf"

	# Poción de maná → botella marrón (bottle_B_brown.gltf)
	var mana := ItemData.new()
	mana.display_name = "Poción de Maná"
	mana.description  = "Recupera 20 MP."
	mana.item_type    = ItemData.ItemType.HEAL_MANA
	mana.effect_value = 20
	mana.buy_price    = 18
	mana.sell_price   = 4
	mana.model_path   = DUNGEON + "bottle_B_brown.gltf"

	# Monedas (coin_stack_medium.gltf) — material de economía
	var monedas := ItemData.new()
	monedas.display_name = "Monedas Extra"
	monedas.description  = "Un puñado de monedas."
	monedas.item_type    = ItemData.ItemType.MATERIAL
	monedas.effect_value = 0
	monedas.buy_price    = 10
	monedas.sell_price   = 10
	monedas.model_path   = DUNGEON + "coin_stack_medium.gltf"

	# Anillo / accesorio → keyring (keyring.gltf)
	var anillo := ArmorData.new()
	anillo.display_name = "Anillo de Fuerza"
	anillo.description  = "Aumenta el ataque."
	anillo.armor_slot   = ArmorData.ArmorSlot.ACCESSORY
	anillo.stats_mod    = {"atk": 3, "weight": 1}
	anillo.buy_price    = 60
	anillo.sell_price   = 25
	anillo.model_path   = DUNGEON + "keyring.gltf"

	_catalogo = [escudo, casco, botas, pocion, mana, monedas, anillo]
	_rebuild_tienda()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		_on_cerrar()
		get_viewport().set_input_as_handled()


func _on_cerrar() -> void:
	visible = false
	panel_closed.emit()


func _make_button(txt: String, min_w: int, min_h: int) -> Button:
	return ShopPanel._make_kenney_button(txt, min_w, min_h)


## Crea un botón estilizado con las texturas Kenney UI Pack RPG Expansion.
static func _make_kenney_button(txt: String, min_w: int, min_h: int) -> Button:
	const TEX_NORMAL  := "res://assets/kenney_ui-pack-rpg-expansion/PNG/buttonLong_blue.png"
	const TEX_PRESSED := "res://assets/kenney_ui-pack-rpg-expansion/PNG/buttonLong_blue_pressed.png"
	var btn := Button.new()
	btn.text = txt
	btn.add_theme_font_size_override("font_size", 12)
	btn.add_theme_color_override("font_color", Color(0.10, 0.12, 0.20, 1.0))
	btn.custom_minimum_size = Vector2(min_w, min_h)
	if ResourceLoader.exists(TEX_NORMAL):
		var tex_n: Texture2D = load(TEX_NORMAL)
		var style_n := StyleBoxTexture.new()
		style_n.texture = tex_n
		style_n.texture_margin_left = 6; style_n.texture_margin_right = 6
		style_n.texture_margin_top = 4; style_n.texture_margin_bottom = 4
		btn.add_theme_stylebox_override("normal", style_n)
		btn.add_theme_stylebox_override("hover",  style_n)
		btn.add_theme_stylebox_override("focus",  style_n)
	if ResourceLoader.exists(TEX_PRESSED):
		var tex_p: Texture2D = load(TEX_PRESSED)
		var style_p := StyleBoxTexture.new()
		style_p.texture = tex_p
		style_p.texture_margin_left = 6; style_p.texture_margin_right = 6
		style_p.texture_margin_top = 4; style_p.texture_margin_bottom = 4
		btn.add_theme_stylebox_override("pressed", style_p)
	return btn
