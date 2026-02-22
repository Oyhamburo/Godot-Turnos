extends PanelContainer
class_name ConfirmDialogPanel
##
## Diálogo de confirmación Sí/No reutilizable.
## Construido 100% por código con assets Kenney RPG UI.
##

signal confirmado
signal cancelado

const PANEL_SIZE := Vector2(420, 200)
const BTN_TEX_PATH := "res://assets/kenney_ui-pack-rpg-expansion/PNG/buttonLong_blue.png"
const BTN_PRESS_PATH := "res://assets/kenney_ui-pack-rpg-expansion/PNG/buttonLong_blue_pressed.png"
const PANEL_TEX_PATH := "res://assets/kenney_ui-pack-rpg-expansion/PNG/panel_blue.png"

const C_BG := Color(0.06, 0.08, 0.15, 0.96)
const C_TITULO := Color(1, 0.95, 0.7, 1)
const C_MENSAJE := Color(0.92, 0.93, 0.98, 1)
const C_BTN_TEXT := Color(1, 1, 1, 1)

var _titulo: String
var _mensaje: String


func _init(titulo: String = "", mensaje: String = "") -> void:
	_titulo = titulo
	_mensaje = mensaje
	_build_ui()


func _build_ui() -> void:
	custom_minimum_size = PANEL_SIZE

	# Fondo del panel
	var bg := StyleBoxFlat.new()
	bg.bg_color = C_BG
	bg.border_color = Color(0.3, 0.45, 0.8, 0.8)
	bg.border_width_left = 2
	bg.border_width_right = 2
	bg.border_width_top = 2
	bg.border_width_bottom = 2
	bg.corner_radius_top_left = 10
	bg.corner_radius_top_right = 10
	bg.corner_radius_bottom_left = 10
	bg.corner_radius_bottom_right = 10
	bg.content_margin_left = 20
	bg.content_margin_right = 20
	bg.content_margin_top = 16
	bg.content_margin_bottom = 16
	add_theme_stylebox_override("panel", bg)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 12)
	add_child(vbox)

	# Título
	var lbl_titulo := Label.new()
	lbl_titulo.text = _titulo
	lbl_titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_titulo.add_theme_color_override("font_color", C_TITULO)
	lbl_titulo.add_theme_font_size_override("font_size", 20)
	vbox.add_child(lbl_titulo)

	# Mensaje
	var lbl_mensaje := Label.new()
	lbl_mensaje.text = _mensaje
	lbl_mensaje.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_mensaje.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_mensaje.add_theme_color_override("font_color", C_MENSAJE)
	lbl_mensaje.add_theme_font_size_override("font_size", 16)
	vbox.add_child(lbl_mensaje)

	# Separador
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	vbox.add_child(spacer)

	# Botones
	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 24)
	vbox.add_child(hbox)

	var btn_si := _crear_boton("Sí")
	btn_si.pressed.connect(func() -> void: confirmado.emit())
	hbox.add_child(btn_si)

	var btn_no := _crear_boton("No")
	btn_no.pressed.connect(func() -> void: cancelado.emit())
	hbox.add_child(btn_no)


func _crear_boton(texto: String) -> Button:
	var btn := Button.new()
	btn.text = texto
	btn.custom_minimum_size = Vector2(120, 44)
	btn.add_theme_font_size_override("font_size", 16)
	btn.add_theme_color_override("font_color", C_BTN_TEXT)
	btn.add_theme_color_override("font_hover_color", Color(1, 1, 0.8, 1))

	# Estilo normal
	var style_normal := StyleBoxFlat.new()
	style_normal.bg_color = Color(0.15, 0.25, 0.55, 1)
	style_normal.border_color = Color(0.4, 0.55, 0.9, 0.9)
	style_normal.border_width_left = 1
	style_normal.border_width_right = 1
	style_normal.border_width_top = 1
	style_normal.border_width_bottom = 1
	style_normal.corner_radius_top_left = 6
	style_normal.corner_radius_top_right = 6
	style_normal.corner_radius_bottom_left = 6
	style_normal.corner_radius_bottom_right = 6
	btn.add_theme_stylebox_override("normal", style_normal)

	# Estilo hover
	var style_hover := style_normal.duplicate()
	style_hover.bg_color = Color(0.2, 0.35, 0.65, 1)
	btn.add_theme_stylebox_override("hover", style_hover)

	# Estilo pressed
	var style_pressed := style_normal.duplicate()
	style_pressed.bg_color = Color(0.1, 0.18, 0.4, 1)
	btn.add_theme_stylebox_override("pressed", style_pressed)

	return btn


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		cancelado.emit()
		get_viewport().set_input_as_handled()
