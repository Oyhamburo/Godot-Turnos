extends CanvasLayer
class_name ExploreHUD
##
## HUD de la escena de exploración.
## Muestra el botón para tirar el dado y el resultado del turno.
## Construido por código (sin .tscn) siguiendo el patrón del proyecto.
##

signal dado_presionado

var _panel: PanelContainer
var _label_instruccion: Label
var _label_resultado: Label
var _boton_dado: Button


func _init() -> void:
	layer = 10
	_construir_ui()


func _construir_ui() -> void:
	_panel = PanelContainer.new()
	_panel.anchor_left = 0.0
	_panel.anchor_right = 0.0
	_panel.anchor_top = 1.0
	_panel.anchor_bottom = 1.0
	_panel.offset_left = 20.0
	_panel.offset_right = 220.0
	_panel.offset_top = -140.0
	_panel.offset_bottom = -20.0
	_panel.custom_minimum_size = Vector2(200.0, 120.0)
	add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	_panel.add_child(vbox)

	_label_instruccion = Label.new()
	_label_instruccion.text = "Tu turno"
	_label_instruccion.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_label_instruccion)

	_label_resultado = Label.new()
	_label_resultado.text = ""
	_label_resultado.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_label_resultado)

	_boton_dado = Button.new()
	_boton_dado.text = "Tirar Dado (D6)"
	_boton_dado.custom_minimum_size = Vector2(160.0, 40.0)
	_boton_dado.pressed.connect(_on_dado_presionado)
	vbox.add_child(_boton_dado)


## Muestra el botón de dado habilitado al inicio del turno.
func mostrar_boton_dado() -> void:
	_boton_dado.disabled = false
	_label_instruccion.text = "Tu turno"
	_label_resultado.text = ""


## Muestra el resultado del dado y deshabilita el botón mientras el jugador elige.
func mostrar_resultado_dado(resultado: int) -> void:
	_boton_dado.disabled = true
	_label_instruccion.text = "Elige destino"
	_label_resultado.text = "Dado: %d — %d casillas" % [resultado, resultado]


func _on_dado_presionado() -> void:
	dado_presionado.emit()
