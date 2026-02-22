extends CanvasLayer
class_name RogueHUD
##
## HUD superior para el modo RogueLike.
## Muestra ronda, paso actual, oro y HP del jugador.
## Construido 100% por código en _init().
##

const C_BG     := Color(0.05, 0.06, 0.10, 0.85)
const C_GOLD   := Color(1.0, 0.85, 0.3, 1.0)
const C_HP     := Color(0.3, 0.85, 0.4, 1.0)
const C_LABEL  := Color(0.7, 0.72, 0.8, 1.0)
const C_RONDA  := Color(0.5, 0.7, 1.0, 1.0)

var _ronda_label: Label
var _paso_label: Label
var _oro_label: Label
var _hp_label: Label
var _bg: ColorRect


func _init() -> void:
	layer = 5

	# Fondo barra superior
	_bg = ColorRect.new()
	_bg.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_bg.custom_minimum_size = Vector2(0, 44)
	_bg.color = C_BG
	add_child(_bg)

	var hbox := HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_TOP_WIDE)
	hbox.custom_minimum_size = Vector2(0, 44)
	hbox.add_theme_constant_override("separation", 30)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(hbox)

	_ronda_label = Label.new()
	_ronda_label.add_theme_font_size_override("font_size", 18)
	_ronda_label.add_theme_color_override("font_color", C_RONDA)
	hbox.add_child(_ronda_label)

	_paso_label = Label.new()
	_paso_label.add_theme_font_size_override("font_size", 18)
	_paso_label.add_theme_color_override("font_color", C_LABEL)
	hbox.add_child(_paso_label)

	_oro_label = Label.new()
	_oro_label.add_theme_font_size_override("font_size", 18)
	_oro_label.add_theme_color_override("font_color", C_GOLD)
	hbox.add_child(_oro_label)

	_hp_label = Label.new()
	_hp_label.add_theme_font_size_override("font_size", 18)
	_hp_label.add_theme_color_override("font_color", C_HP)
	hbox.add_child(_hp_label)


## Actualiza la información del HUD.
func actualizar() -> void:
	var rm: Node = Engine.get_main_loop().root.get_node_or_null("RogueManager")
	if not rm or not rm.run_activa:
		visible = false
		return
	visible = true
	_ronda_label.text = "Ronda: %d" % (rm.ronda + 1)
	var paso_nombre: String = rm.NOMBRES_PASO.get(rm.paso_actual, "???")
	_paso_label.text = "Paso: %s" % paso_nombre
	if rm.rogue_inventory:
		_oro_label.text = "Oro: %d" % rm.rogue_inventory.gold
	else:
		_oro_label.text = "Oro: 0"
	if rm.player_max_hp > 0:
		_hp_label.text = "HP: %d/%d" % [rm.player_hp, rm.player_max_hp]
	else:
		_hp_label.text = "HP: --/--"
