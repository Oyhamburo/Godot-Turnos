extends Control
class_name EquipmentPanel
##
## Panel con los 7 slots de equipamiento distribuidos en silueta de cuerpo.
## Soporta drag & drop con ItemGridPanel.
## Emite señales para que PersonalInventoryPanel coordine la lógica.
## Construido 100% por código.
##

## Emitido cuando el jugador solicita equipar un ítem desde el grid al slot.
signal equip_requested(item, slot_name: String)
## Emitido cuando el jugador arrastra un ítem del slot al grid (desequipar).
signal unequip_requested(slot_name: String)
## Emitido al seleccionar un slot (para preview de stats).
signal slot_selected(slot_name: String, item)

const C_BG     := Color(0.08, 0.09, 0.15, 0.88)
const C_TITLE  := Color(0.65, 0.72, 0.92, 1.0)
const SLOT_SZ  := Vector2(54, 54)
const PANEL_W  := 200.0
const PANEL_H  := 360.0

# Layout: posiciones relativas de cada slot dentro del panel (% de PANEL_W × PANEL_H)
# Orden visual: cabeza arriba, pecho al centro, piernas abajo, arma/escudo a los lados
const SLOT_POSITIONS: Dictionary = {
	"head":      Vector2(0.50, 0.06),
	"chest":     Vector2(0.50, 0.28),
	"legs":      Vector2(0.50, 0.52),
	"boots":     Vector2(0.50, 0.74),
	"weapon":    Vector2(0.15, 0.28),
	"offhand":   Vector2(0.85, 0.28),
	"accessory": Vector2(0.85, 0.06),
}

var _equipment: EquipmentData = null
var _player_stats: PlayerStats = null
var _slots: Dictionary = {}   # slot_name → ItemSlot
var _msg_label: Label         # mensaje temporal de error

# Para drag & drop desde el grid: referencia al ItemGridPanel
var _grid_panel: ItemGridPanel = null


func _init() -> void:
	custom_minimum_size = Vector2(PANEL_W, PANEL_H)
	_build_ui()


func _build_ui() -> void:
	# Fondo
	var bg := StyleBoxFlat.new()
	bg.bg_color = C_BG
	bg.corner_radius_top_left     = 8
	bg.corner_radius_top_right    = 8
	bg.corner_radius_bottom_left  = 8
	bg.corner_radius_bottom_right = 8

	# Título
	var title := Label.new()
	title.text = "EQUIPAMIENTO"
	title.add_theme_font_size_override("font_size", 11)
	title.add_theme_color_override("font_color", C_TITLE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	title.offset_top    = 4
	title.offset_bottom = 22
	add_child(title)

	# Crear los 7 slots posicionados
	for slot_name in SLOT_POSITIONS:
		var pos_pct: Vector2 = SLOT_POSITIONS[slot_name]
		var slot := ItemSlot.new(slot_name, SLOT_SZ)
		slot.slot_clicked.connect(_on_slot_clicked)
		slot.item_dropped.connect(_on_item_dropped)
		slot.position = Vector2(
			pos_pct.x * PANEL_W - SLOT_SZ.x * 0.5,
			pos_pct.y * PANEL_H
		)
		add_child(slot)
		_slots[slot_name] = slot

	# Label temporal de mensajes de error
	_msg_label = Label.new()
	_msg_label.add_theme_font_size_override("font_size", 10)
	_msg_label.add_theme_color_override("font_color", Color(1, 0.4, 0.4, 1))
	_msg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_msg_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_msg_label.offset_bottom = -4
	_msg_label.offset_top    = -22
	_msg_label.visible = false
	add_child(_msg_label)


## Vincula EquipmentData y PlayerStats, y refresca la UI.
func setup(equip: EquipmentData, stats: PlayerStats) -> void:
	if _equipment and _equipment.changed.is_connected(_on_equipment_changed):
		_equipment.changed.disconnect(_on_equipment_changed)
	_equipment = equip
	_player_stats = stats
	if _equipment:
		_equipment.changed.connect(_on_equipment_changed)
	refresh()


## Vincula el ItemGridPanel (para coordinar drops cruzados).
func set_grid_panel(grid: ItemGridPanel) -> void:
	_grid_panel = grid


## Refresca todos los slots según el estado actual de EquipmentData.
func refresh() -> void:
	if _equipment == null:
		return
	for slot_name in _slots:
		(_slots[slot_name] as ItemSlot).set_item(_equipment.get_item(slot_name))


## Intenta equipar un ítem en el slot compatible.
## Si hay swap (slot ocupado), el ítem viejo va al inventario.
## Retorna true si se equipó.
func try_equip(item, inv: Inventory) -> bool:
	if _equipment == null or inv == null:
		return false

	var target_slot := _get_slot_for_item(item)
	if target_slot == "":
		mostrar_mensaje("Ese ítem no se puede equipar")
		return false

	var item_viejo = _equipment.get_item(target_slot)
	var ok := _equipment.equip(target_slot, item)
	if not ok:
		mostrar_mensaje("Ese ítem no va en ese slot")
		return false

	# Quitar del inventario genérico
	inv.remove_item_generic(item)

	# Si había algo equipado, devolverlo al inventario
	if item_viejo != null:
		if not inv.add_item_generic(item_viejo):
			# Inventario lleno: re-equipar el ítem viejo y deshacer
			_equipment.equip(target_slot, item_viejo)
			inv.add_item_generic(item)
			mostrar_mensaje("Inventario lleno")
			return false

	equip_requested.emit(item, target_slot)
	return true


## Desequipa el slot indicado y devuelve el ítem al inventario.
func try_unequip(slot_name: String, inv: Inventory) -> bool:
	if _equipment == null or inv == null:
		return false
	var item_viejo = _equipment.get_item(slot_name)
	if item_viejo == null:
		return false
	if not inv.has_space():
		mostrar_mensaje("Inventario lleno")
		return false
	_equipment.unequip(slot_name)
	inv.add_item_generic(item_viejo)
	unequip_requested.emit(slot_name)
	return true


## Detecta el slot compatible para un ítem dado.
func _get_slot_for_item(item) -> String:
	for slot_name in _slots:
		if _equipment.is_slot_compatible(slot_name, item):
			return slot_name
	return ""


## Muestra un mensaje de error temporal (3 segundos).
func mostrar_mensaje(txt: String) -> void:
	_msg_label.text = txt
	_msg_label.visible = true
	var tween := create_tween()
	tween.tween_interval(3.0)
	tween.tween_callback(func(): _msg_label.visible = false)


func _on_slot_clicked(slot: ItemSlot) -> void:
	var sn: String = slot.slot_name
	var item = _equipment.get_item(sn) if _equipment else null
	slot_selected.emit(sn, item)


func _on_item_dropped(from_slot: ItemSlot, to_slot: ItemSlot) -> void:
	# from_slot puede ser del ItemGridPanel (slot de inventario)
	# to_slot es un slot de equipamiento
	var to_name: String = to_slot.slot_name
	if to_name == "":
		return   # no es un slot de equipo

	var item = from_slot.item
	if item == null:
		return

	# Si viene del grid → intento equipar (coordinado desde PersonalInventoryPanel)
	equip_requested.emit(item, to_name)


func _on_equipment_changed(_slot_name: String, _item) -> void:
	refresh()
