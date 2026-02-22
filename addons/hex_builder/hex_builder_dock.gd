@tool
extends VBoxContainer
##
## Dock del plugin Hex Builder.
## Muestra galería de hex/buildings y controles de modo/rotación.
## El plugin principal (hex_builder_plugin.gd) consulta este dock
## para saber qué colocar y en qué modo está.
##

signal activo_changed(activo: bool)

const HEX_SCENES_PATH := "res://scenes/hex/"
const BUILDING_SCENES_PATH := "res://scenes/buildings/"

enum Modo { PLACE, ERASE }
enum Categoria { TODOS, HEXAGONOS, EDIFICIOS }

var _modo: Modo = Modo.PLACE
var _activo: bool = false
var _rotacion_step: int = 0  # 0-5 → ×60° = 0, 60, 120, 180, 240, 300

var _assets: Array[Dictionary] = []  # {nombre, path, categoria}
var _categoria_filtro: Categoria = Categoria.TODOS

# Controles UI
var _btn_place: Button
var _btn_erase: Button
var _btn_activo: CheckButton
var _spin_rotacion: SpinBox
var _option_categoria: OptionButton
var _item_list: ItemList


func _ready() -> void:
	custom_minimum_size = Vector2(260, 400)
	_construir_ui()
	_escanear_assets()


func _construir_ui() -> void:
	# Título
	var titulo := Label.new()
	titulo.text = "Hex Builder"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(titulo)

	# Toggle activo
	_btn_activo = CheckButton.new()
	_btn_activo.text = "Activar pintado"
	_btn_activo.toggled.connect(func(on: bool) -> void:
		_activo = on
		activo_changed.emit(on)
	)
	add_child(_btn_activo)

	# Modo: Place / Erase
	var modo_row := HBoxContainer.new()
	modo_row.add_theme_constant_override("separation", 4)
	_btn_place = Button.new()
	_btn_place.text = "Colocar"
	_btn_place.toggle_mode = true
	_btn_place.button_pressed = true
	_btn_place.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_place.pressed.connect(_on_modo_place)
	modo_row.add_child(_btn_place)
	_btn_erase = Button.new()
	_btn_erase.text = "Borrar"
	_btn_erase.toggle_mode = true
	_btn_erase.button_pressed = false
	_btn_erase.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_erase.pressed.connect(_on_modo_erase)
	modo_row.add_child(_btn_erase)
	add_child(modo_row)

	# Rotación
	var rot_row := HBoxContainer.new()
	rot_row.add_theme_constant_override("separation", 4)
	var rot_label := Label.new()
	rot_label.text = "Rotación (×60°):"
	rot_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rot_row.add_child(rot_label)
	_spin_rotacion = SpinBox.new()
	_spin_rotacion.min_value = 0
	_spin_rotacion.max_value = 5
	_spin_rotacion.step = 1
	_spin_rotacion.value = 0
	_spin_rotacion.value_changed.connect(func(v: float) -> void: _rotacion_step = int(v))
	rot_row.add_child(_spin_rotacion)
	add_child(rot_row)

	# Categoría
	var cat_row := HBoxContainer.new()
	cat_row.add_theme_constant_override("separation", 4)
	var cat_label := Label.new()
	cat_label.text = "Categoría:"
	cat_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cat_row.add_child(cat_label)
	_option_categoria = OptionButton.new()
	_option_categoria.add_item("Todos", 0)
	_option_categoria.add_item("Hexágonos", 1)
	_option_categoria.add_item("Edificios", 2)
	_option_categoria.item_selected.connect(_on_categoria_changed)
	cat_row.add_child(_option_categoria)
	add_child(cat_row)

	# Lista de assets
	_item_list = ItemList.new()
	_item_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_item_list.custom_minimum_size.y = 200
	_item_list.auto_height = true
	add_child(_item_list)


func _on_modo_place() -> void:
	_modo = Modo.PLACE
	_btn_place.button_pressed = true
	_btn_erase.button_pressed = false


func _on_modo_erase() -> void:
	_modo = Modo.ERASE
	_btn_place.button_pressed = false
	_btn_erase.button_pressed = true


func _on_categoria_changed(idx: int) -> void:
	_categoria_filtro = idx as Categoria
	_actualizar_lista()


func _escanear_assets() -> void:
	_assets.clear()
	_escanear_carpeta(HEX_SCENES_PATH, "Hexágono")
	_escanear_carpeta(BUILDING_SCENES_PATH, "Edificio")
	_actualizar_lista()


func _escanear_carpeta(dir_path: String, categoria: String) -> void:
	var dir := DirAccess.open(dir_path)
	if not dir:
		return
	for f in dir.get_files():
		if not f.ends_with(".tscn"):
			continue
		_assets.append({
			"nombre": f.get_basename(),
			"path": dir_path + f,
			"categoria": categoria
		})


func _actualizar_lista() -> void:
	if not _item_list:
		return
	_item_list.clear()
	for asset in _assets:
		if _categoria_filtro == Categoria.HEXAGONOS and asset.categoria != "Hexágono":
			continue
		if _categoria_filtro == Categoria.EDIFICIOS and asset.categoria != "Edificio":
			continue
		var display: String = "%s (%s)" % [asset.nombre, asset.categoria]
		_item_list.add_item(display)


# ── API pública para el plugin principal ──────────────────────────────────

func is_active() -> bool:
	return _activo


func get_mode() -> String:
	return "place" if _modo == Modo.PLACE else "erase"


func get_rotation_degrees() -> float:
	return float(_rotacion_step) * 60.0


func get_selected_scene_path() -> String:
	var selected: PackedInt32Array = _item_list.get_selected_items()
	if selected.is_empty():
		return ""
	var display_text: String = _item_list.get_item_text(selected[0])
	# Encontrar el asset que corresponde
	var visible_idx := 0
	for asset in _assets:
		if _categoria_filtro == Categoria.HEXAGONOS and asset.categoria != "Hexágono":
			continue
		if _categoria_filtro == Categoria.EDIFICIOS and asset.categoria != "Edificio":
			continue
		if visible_idx == selected[0]:
			return asset.path
		visible_idx += 1
	return ""


func get_selected_category() -> String:
	var selected: PackedInt32Array = _item_list.get_selected_items()
	if selected.is_empty():
		return ""
	var visible_idx := 0
	for asset in _assets:
		if _categoria_filtro == Categoria.HEXAGONOS and asset.categoria != "Hexágono":
			continue
		if _categoria_filtro == Categoria.EDIFICIOS and asset.categoria != "Edificio":
			continue
		if visible_idx == selected[0]:
			return asset.categoria
		visible_idx += 1
	return ""
