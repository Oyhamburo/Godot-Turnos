extends Control
##
## Panel modal de información de efectos de estado.
## Construido 100% por código en _init() — sin .tscn propio.
## Lee datos directamente de StatusEffect.DATOS_EFECTO, así que
## al agregar un efecto nuevo al enum Tipo aparece automáticamente.
##

## Descripciones detalladas por tipo (lo que el jugador necesita saber).
const DESCRIPCIONES: Dictionary = {
	StatusEffect.Tipo.VENENO: "Causa daño mágico al inicio de cada turno.",
	StatusEffect.Tipo.STUN: "Pierde el turno completo. No puede actuar.",
	StatusEffect.Tipo.CONFUSION: "Ataca un objetivo aleatorio (incluye aliados).",
	StatusEffect.Tipo.SANGRADO: "Causa daño físico al inicio de cada turno.",
	StatusEffect.Tipo.FUERZA: "Aumenta el daño físico temporalmente.",
	StatusEffect.Tipo.POTENCIACION_MAGICA: "Aumenta el daño mágico temporalmente.",
	StatusEffect.Tipo.ESPINAS: "Refleja daño fijo al atacante al ser golpeado.",
	StatusEffect.Tipo.ESPEJO: "Refleja el 100% del daño recibido al atacante.",
	StatusEffect.Tipo.QUEMADURA: "Causa daño mágico de fuego al inicio de cada turno.",
	StatusEffect.Tipo.ELECTROCUTADO: "Reduce drásticamente la precisión del afectado.",
	StatusEffect.Tipo.ENREDADO: "No puede moverse. Puede atacar normalmente.",
	StatusEffect.Tipo.SIGILO: "No puede ser objetivo de ataques individuales.",
	StatusEffect.Tipo.ENFERMEDAD: "Impide cualquier curación (pociones y hechizos).",
	StatusEffect.Tipo.EVASION_MEJORADA: "Aumenta la probabilidad de esquivar ataques.",
}

var _effects_container: VBoxContainer
var _back_button: Button


func _init() -> void:
	# ── Raíz: pantalla completa ──
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	# Fondo oscuro semitransparente
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.55)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	# Centrador
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	# Panel contenedor
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(780, 0)
	center.add_child(panel)

	# Margen interior
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 26)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_right", 26)
	margin.add_theme_constant_override("margin_bottom", 24)
	panel.add_child(margin)

	# Columna principal
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 18)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(vbox)

	# Título
	var titulo := Label.new()
	titulo.text = "Efectos de Estado"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.add_theme_font_size_override("font_size", 26)
	vbox.add_child(titulo)

	# Scroll con lista de efectos
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 500)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	_effects_container = VBoxContainer.new()
	_effects_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_effects_container.add_theme_constant_override("separation", 4)
	scroll.add_child(_effects_container)

	# Botón Volver
	_back_button = Button.new()
	_back_button.text = "Volver"
	_back_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(_back_button)


func _ready() -> void:
	_back_button.pressed.connect(func(): visible = false)
	_poblar_lista()


## Muestra el panel (llamado desde MainMenu).
func open() -> void:
	visible = true


## Genera la lista de efectos automáticamente desde StatusEffect.DATOS_EFECTO.
func _poblar_lista() -> void:
	# Limpiar contenido previo
	for child in _effects_container.get_children():
		child.queue_free()

	# Iterar todos los tipos del enum en orden
	for tipo_key in StatusEffect.DATOS_EFECTO.keys():
		var datos: Dictionary = StatusEffect.DATOS_EFECTO[tipo_key]
		var emoji: String = datos.get("emoji", "?")
		var nombre: String = datos.get("nombre", "?")
		var color_efecto: Color = datos.get("color", Color.WHITE)
		var descripcion: String = DESCRIPCIONES.get(tipo_key, "Sin descripción.")

		# Determinar categoría
		var es_buff: bool = tipo_key in StatusEffect.EFECTOS_BUFF
		var categoria: String = "Buff" if es_buff else "Debuff"
		var color_categoria: Color = Color(0.3, 0.85, 0.4) if es_buff else Color(1.0, 0.4, 0.35)

		# ── Fila principal: HBox con emoji + info ──
		var fila := HBoxContainer.new()
		fila.add_theme_constant_override("separation", 14)

		# Emoji (grande)
		var lbl_emoji := Label.new()
		lbl_emoji.text = emoji
		lbl_emoji.add_theme_font_size_override("font_size", 28)
		lbl_emoji.custom_minimum_size = Vector2(40, 0)
		lbl_emoji.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl_emoji.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		fila.add_child(lbl_emoji)

		# Info (nombre + descripción)
		var vbox_info := VBoxContainer.new()
		vbox_info.add_theme_constant_override("separation", 2)
		vbox_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		# Línea 1: nombre + categoría
		var hbox_titulo := HBoxContainer.new()
		hbox_titulo.add_theme_constant_override("separation", 10)

		var lbl_nombre := Label.new()
		lbl_nombre.text = nombre
		lbl_nombre.add_theme_font_size_override("font_size", 20)
		lbl_nombre.add_theme_color_override("font_color", color_efecto)
		hbox_titulo.add_child(lbl_nombre)

		var lbl_cat := Label.new()
		lbl_cat.text = "(%s)" % categoria
		lbl_cat.add_theme_font_size_override("font_size", 16)
		lbl_cat.add_theme_color_override("font_color", color_categoria)
		hbox_titulo.add_child(lbl_cat)

		vbox_info.add_child(hbox_titulo)

		# Línea 2: descripción
		var lbl_desc := Label.new()
		lbl_desc.text = descripcion
		lbl_desc.add_theme_font_size_override("font_size", 15)
		lbl_desc.add_theme_color_override("font_color", Color(0.75, 0.75, 0.8))
		lbl_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox_info.add_child(lbl_desc)

		fila.add_child(vbox_info)
		_effects_container.add_child(fila)

		# Separador sutil
		var sep := HSeparator.new()
		sep.add_theme_constant_override("separation", 6)
		sep.modulate = Color(1, 1, 1, 0.15)
		_effects_container.add_child(sep)
