extends PanelContainer
class_name WeaponShopRow
##
## Fila seleccionable de un arma en la Herrería.
## Muestra: emoji tipo + nombre + subtítulo (tipo·slot) + precio.
## Construida 100% por código.
##

## Emitido al hacer click en la fila.
signal seleccionado(weapon: WeaponData)

const C_TEXT      := Color(0.88, 0.90, 0.98, 1.0)
const C_SUBTEXT   := Color(0.55, 0.58, 0.72, 1.0)
const C_PRECIO    := Color(1.0, 0.85, 0.3, 1.0)

const TEX_NORMAL   := "res://assets/kenney_ui-pack-rpg-expansion/PNG/panelInset_blue.png"
const TEX_SELECTED := "res://assets/kenney_ui-pack-rpg-expansion/PNG/panelInset_beigeLight.png"

var weapon: WeaponData = null
var _selected: bool = false
var _style_normal: StyleBoxTexture
var _style_selected: StyleBoxTexture


func _init(p_weapon: WeaponData) -> void:
	weapon = p_weapon
	custom_minimum_size = Vector2(0, 48)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_styles()
	_build_ui()


func _build_styles() -> void:
	_style_normal = StyleBoxTexture.new()
	if ResourceLoader.exists(TEX_NORMAL):
		_style_normal.texture = load(TEX_NORMAL)
	_style_normal.texture_margin_left   = 6
	_style_normal.texture_margin_right  = 6
	_style_normal.texture_margin_top    = 6
	_style_normal.texture_margin_bottom = 6

	_style_selected = StyleBoxTexture.new()
	if ResourceLoader.exists(TEX_SELECTED):
		_style_selected.texture = load(TEX_SELECTED)
	_style_selected.texture_margin_left   = 6
	_style_selected.texture_margin_right  = 6
	_style_selected.texture_margin_top    = 6
	_style_selected.texture_margin_bottom = 6

	add_theme_stylebox_override("panel", _style_normal)


func _build_ui() -> void:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)
	hbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	add_child(hbox)

	# Emoji tipo
	var emoji_label := Label.new()
	emoji_label.text = _get_type_emoji()
	emoji_label.add_theme_font_size_override("font_size", 16)
	emoji_label.custom_minimum_size = Vector2(28, 0)
	emoji_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	emoji_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(emoji_label)

	# Nombre + subtítulo
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	vbox.add_theme_constant_override("separation", 1)
	hbox.add_child(vbox)

	var nombre_label := Label.new()
	nombre_label.text = weapon.display_name
	nombre_label.add_theme_font_size_override("font_size", 13)
	nombre_label.add_theme_color_override("font_color", C_TEXT)
	nombre_label.clip_text = true
	vbox.add_child(nombre_label)

	var sub_label := Label.new()
	sub_label.text = "%s · %s" % [_get_type_name(), _get_slot_name()]
	sub_label.add_theme_font_size_override("font_size", 11)
	sub_label.add_theme_color_override("font_color", C_SUBTEXT)
	sub_label.clip_text = true
	vbox.add_child(sub_label)

	# Precio
	var precio_label := Label.new()
	precio_label.text = "🪙 %d" % weapon.buy_price
	precio_label.add_theme_font_size_override("font_size", 13)
	precio_label.add_theme_color_override("font_color", C_PRECIO)
	precio_label.custom_minimum_size = Vector2(56, 0)
	precio_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	precio_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(precio_label)


func _get_type_emoji() -> String:
	match weapon.weapon_type:
		WeaponData.WeaponType.SWORD:   return "⚔"
		WeaponData.WeaponType.AXE:     return "🪓"
		WeaponData.WeaponType.DAGGER:  return "🗡"
		WeaponData.WeaponType.SHIELD:  return "🛡"
		WeaponData.WeaponType.BOW:     return "🏹"
		WeaponData.WeaponType.STAFF:   return "🔱"
		WeaponData.WeaponType.WAND:    return "✨"
		_: return "⚔"


func _get_type_name() -> String:
	match weapon.weapon_type:
		WeaponData.WeaponType.SWORD:   return "Espada"
		WeaponData.WeaponType.AXE:     return "Hacha"
		WeaponData.WeaponType.DAGGER:  return "Daga"
		WeaponData.WeaponType.SHIELD:  return "Escudo"
		WeaponData.WeaponType.BOW:     return "Arco"
		WeaponData.WeaponType.STAFF:   return "Bastón"
		WeaponData.WeaponType.WAND:    return "Varita"
		_: return "Arma"


func _get_slot_name() -> String:
	match weapon.slot:
		WeaponData.SlotMode.RIGHT_HAND:  return "Una mano"
		WeaponData.SlotMode.LEFT_HAND:   return "Mano izquierda"
		WeaponData.SlotMode.TWO_HANDED:  return "Dos manos"
		_: return ""


## Marca o desmarca esta fila como seleccionada.
func set_selected(on: bool) -> void:
	_selected = on
	add_theme_stylebox_override("panel", _style_selected if on else _style_normal)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			seleccionado.emit(weapon)
