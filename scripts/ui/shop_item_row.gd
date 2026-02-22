extends HBoxContainer
class_name ShopItemRow
##
## Fila de un ítem en la tienda: icono + nombre + descripción + precio + botón Comprar.
## Construido 100% por código.
##

## Emitido cuando el jugador presiona "Comprar".
signal comprar_solicitado(item)
## Emitido cuando el jugador presiona "Vender".
signal vender_solicitado(item)

const C_BG        := Color(0.10, 0.11, 0.18, 0.90)
const C_BG_HOVER  := Color(0.15, 0.17, 0.26, 0.95)
const C_TEXT      := Color(0.88, 0.90, 0.98, 1.0)
const C_PRECIO    := Color(1.0, 0.85, 0.3, 1.0)
const C_BTN_BG    := Color(0.18, 0.22, 0.30, 1.0)
const C_BTN_HOVER := Color(0.28, 0.35, 0.50, 1.0)
const C_BTN_SELL  := Color(0.14, 0.22, 0.14, 1.0)
const C_BTN_SELL_H:= Color(0.22, 0.38, 0.22, 1.0)

## El ítem que representa esta fila.
var item = null
## Modo: true = tienda (mostrar Comprar), false = inventario (mostrar Vender).
var modo_tienda: bool = true

var _nombre_label: Label
var _precio_label: Label
var _btn: Button


func _init(p_item, p_modo_tienda: bool = true) -> void:
	item = p_item
	modo_tienda = p_modo_tienda
	custom_minimum_size = Vector2(0, 44)
	add_theme_constant_override("separation", 8)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()


func _build_ui() -> void:
	# Icono
	var icon_rect := TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(36, 36)
	icon_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var icon_path: String = _get_icon_path()
	var model_p: String = _get_model_path()
	if model_p != "" and ResourceLoader.exists(model_p):
		# Mostrar preview 3D del ítem usando un SubViewportContainer pequeño
		var svc := SubViewportContainer.new()
		svc.custom_minimum_size = Vector2(36, 36)
		svc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		svc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sv := SubViewport.new()
		sv.size = Vector2i(36, 36)
		sv.transparent_bg = true
		sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		sv.world_3d = World3D.new()
		svc.add_child(sv)
		var cam3 := Camera3D.new()
		cam3.fov = 50.0; cam3.position = Vector3(0, 0.5, 1.2)
		cam3.rotation_degrees = Vector3(-15, 0, 0)
		sv.add_child(cam3)
		var dlight := DirectionalLight3D.new()
		dlight.rotation_degrees = Vector3(-45, 30, 0); dlight.light_energy = 1.8
		sv.add_child(dlight)
		var packed3: PackedScene = load(model_p)
		if packed3:
			var inst3: Node3D = packed3.instantiate()
			inst3.scale = Vector3.ONE * 0.28
			sv.add_child(inst3)
		add_child(svc)
	elif icon_path != "" and ResourceLoader.exists(icon_path):
		icon_rect.texture = load(icon_path)
		add_child(icon_rect)
	else:
		add_child(icon_rect)

	# Nombre y descripción
	var text_col := VBoxContainer.new()
	text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_col.size_flags_vertical   = Control.SIZE_SHRINK_CENTER
	text_col.add_theme_constant_override("separation", 2)
	add_child(text_col)

	_nombre_label = Label.new()
	_nombre_label.text = item.display_name if "display_name" in item else "Ítem"
	_nombre_label.add_theme_font_size_override("font_size", 12)
	_nombre_label.add_theme_color_override("font_color", C_TEXT)
	text_col.add_child(_nombre_label)

	var desc_label := Label.new()
	desc_label.text = item.description if "description" in item else ""
	desc_label.add_theme_font_size_override("font_size", 10)
	desc_label.add_theme_color_override("font_color", Color(0.6, 0.62, 0.72, 1))
	desc_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	desc_label.clip_text = true
	text_col.add_child(desc_label)

	# Precio
	_precio_label = Label.new()
	var precio: int = item.buy_price if (modo_tienda and "buy_price" in item) \
		else (item.sell_price if "sell_price" in item else 0)
	_precio_label.text = "🪙 %d" % precio
	_precio_label.add_theme_font_size_override("font_size", 12)
	_precio_label.add_theme_color_override("font_color", C_PRECIO)
	_precio_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_precio_label.custom_minimum_size.x = 56
	_precio_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_precio_label)

	# Botón Comprar / Vender — textura Kenney
	const TEX_BUY_N  := "res://assets/kenney_ui-pack-rpg-expansion/PNG/buttonLong_blue.png"
	const TEX_BUY_P  := "res://assets/kenney_ui-pack-rpg-expansion/PNG/buttonLong_blue_pressed.png"
	const TEX_SELL_N := "res://assets/kenney_ui-pack-rpg-expansion/PNG/buttonLong_brown.png"
	const TEX_SELL_P := "res://assets/kenney_ui-pack-rpg-expansion/PNG/buttonLong_brown_pressed.png"
	_btn = Button.new()
	_btn.text = "Comprar" if modo_tienda else "Vender"
	_btn.add_theme_font_size_override("font_size", 11)
	_btn.add_theme_color_override("font_color", Color(0.10, 0.12, 0.20, 1.0))
	_btn.custom_minimum_size = Vector2(72, 30)
	_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var tex_n_path := TEX_BUY_N if modo_tienda else TEX_SELL_N
	var tex_p_path := TEX_BUY_P if modo_tienda else TEX_SELL_P
	if ResourceLoader.exists(tex_n_path):
		var sn := StyleBoxTexture.new()
		sn.texture = load(tex_n_path)
		sn.texture_margin_left = 5; sn.texture_margin_right = 5
		sn.texture_margin_top = 3; sn.texture_margin_bottom = 3
		_btn.add_theme_stylebox_override("normal", sn)
		_btn.add_theme_stylebox_override("hover",  sn)
		_btn.add_theme_stylebox_override("focus",  sn)
	if ResourceLoader.exists(tex_p_path):
		var sp := StyleBoxTexture.new()
		sp.texture = load(tex_p_path)
		sp.texture_margin_left = 5; sp.texture_margin_right = 5
		sp.texture_margin_top = 3; sp.texture_margin_bottom = 3
		_btn.add_theme_stylebox_override("pressed", sp)
	_btn.pressed.connect(_on_btn_pressed)
	add_child(_btn)


func _get_icon_path() -> String:
	if item is ArmorData:
		return item.icon_path
	elif item is ItemData:
		return item.icon_path
	elif item is WeaponData and "icon_path" in item:
		return item.icon_path
	return ""


func _get_model_path() -> String:
	if "model_path" in item and item.model_path != "":
		return item.model_path
	if item is WeaponData and "scene_3d_path" in item and item.scene_3d_path != "":
		return item.scene_3d_path
	return ""


## Habilita o deshabilita el botón (p.ej. si el inventario está lleno o sin oro).
func set_enabled(en: bool) -> void:
	if _btn:
		_btn.disabled = not en


func _on_btn_pressed() -> void:
	if modo_tienda:
		comprar_solicitado.emit(item)
	else:
		vender_solicitado.emit(item)
