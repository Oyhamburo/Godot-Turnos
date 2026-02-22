extends ScrollContainer
class_name ItemGridPanel
##
## Grid 4×N de ItemSlots para el inventario genérico del jugador.
## Soporta drag & drop con EquipmentPanel.
## Construido 100% por código.
##

## Emitido cuando el jugador selecciona un slot (para mostrar detalles).
signal slot_selected(slot: ItemSlot)
## Emitido cuando un ítem se mueve dentro del grid (reordenar).
signal item_moved(from_slot: ItemSlot, to_slot: ItemSlot)
## Emitido cuando se solicita mover un ítem al equipamiento.
signal item_equip_requested(from_slot: ItemSlot)

const COLS: int = 4
const C_BG := Color(0.07, 0.08, 0.13, 0.92)

var _inventory: Inventory = null
var _slots: Array[ItemSlot] = []
var _slot_seleccionado: ItemSlot = null
var _grid: GridContainer


func _init() -> void:
	_build_ui()


func _build_ui() -> void:
	custom_minimum_size = Vector2(450, 240)
	size_flags_vertical = Control.SIZE_EXPAND_FILL

	var bg := StyleBoxFlat.new()
	bg.bg_color = C_BG
	bg.corner_radius_top_left     = 6
	bg.corner_radius_top_right    = 6
	bg.corner_radius_bottom_left  = 6
	bg.corner_radius_bottom_right = 6

	_grid = GridContainer.new()
	_grid.columns = COLS
	_grid.add_theme_constant_override("h_separation", 5)
	_grid.add_theme_constant_override("v_separation", 5)
	add_child(_grid)


## Vincula el inventario y reconstruye los slots.
func setup(inv: Inventory) -> void:
	_inventory = inv
	if inv and not inv.inventory_changed.is_connected(_on_inventory_changed):
		inv.inventory_changed.connect(_on_inventory_changed)
	_rebuild_slots()


## Devuelve la lista combinada: armas + ítems genéricos del inventario.
func _get_all_items() -> Array:
	var all: Array = []
	if _inventory:
		for w in _inventory.weapons:
			all.append(w)
		for it in _inventory.items_genericos:
			all.append(it)
	return all


## Reconstruye todos los ItemSlots según el inventario.
func _rebuild_slots() -> void:
	# Limpiar slots existentes
	for s in _slots:
		s.slot_clicked.disconnect(_on_slot_clicked)
		s.item_dropped.disconnect(_on_item_dropped)
		s.queue_free()
	_slots.clear()
	_slot_seleccionado = null

	var items: Array = _get_all_items()
	var total_slots: int = maxi(Inventory.MAX_SLOTS if _inventory else 20, items.size())

	for i in range(total_slots):
		var slot := ItemSlot.new("", Vector2(104, 104))
		slot.slot_clicked.connect(_on_slot_clicked)
		slot.item_dropped.connect(_on_item_dropped)
		_grid.add_child(slot)
		_slots.append(slot)
		if i < items.size():
			slot.set_item(items[i])


## Refresca el contenido de los slots sin reconstruirlos.
func refresh() -> void:
	if _inventory == null:
		return
	var items: Array = _get_all_items()
	# Si hay más ítems que slots, agregar nuevos slots
	while _slots.size() < items.size():
		var slot := ItemSlot.new("", Vector2(104, 104))
		slot.slot_clicked.connect(_on_slot_clicked)
		slot.item_dropped.connect(_on_item_dropped)
		_grid.add_child(slot)
		_slots.append(slot)
	for i in range(_slots.size()):
		if i < items.size():
			_slots[i].set_item(items[i])
		else:
			_slots[i].clear()


## Selecciona un slot programáticamente.
func select_slot(slot: ItemSlot) -> void:
	if _slot_seleccionado:
		_slot_seleccionado.set_selected(false)
	_slot_seleccionado = slot
	if slot:
		slot.set_selected(true)


## Quita el highlight de todos los slots.
func clear_highlights() -> void:
	for s in _slots:
		s.set_highlight(0)


## Aplica highlight a todos los slots (ej. al arrastrar desde equipo hacia inventario).
func highlight_all_empty(mode: int) -> void:
	for s in _slots:
		if s.item == null:
			s.set_highlight(mode)


func _on_slot_clicked(slot: ItemSlot) -> void:
	select_slot(slot)
	slot_selected.emit(slot)
	# Doble clic = pedir equipar
	# (se detecta con ActionDoubleClick en la próxima iteración si se necesita)


func _on_item_dropped(from_slot: ItemSlot, to_slot: ItemSlot) -> void:
	# Si ambos están en este grid → intercambiar en inventario (solo ítems genéricos)
	if _slots.has(from_slot) and _slots.has(to_slot):
		if _inventory:
			# Las armas ocupan los primeros N slots; no se reordenan desde el grid
			var weapon_count: int = _inventory.weapons.size()
			var fi := _slots.find(from_slot)
			var ti := _slots.find(to_slot)
			# Solo reordenar en items_genericos (después del offset de armas)
			var gi: int = fi - weapon_count
			var gti: int = ti - weapon_count
			var items: Array = _inventory.items_genericos
			if gi >= 0 and gti >= 0:
				if gi < items.size() and gti < items.size():
					var tmp = items[gi]
					items[gi] = items[gti]
					items[gti] = tmp
					_inventory.inventory_changed.emit()
				elif gi < items.size():
					items.insert(gti, items[gi])
					if gi >= gti:
						gi += 1
					items.remove_at(gi)
					_inventory.inventory_changed.emit()
		item_moved.emit(from_slot, to_slot)
	else:
		# Viene del EquipmentPanel o ShopPanel — delegar hacia arriba
		item_equip_requested.emit(from_slot)


func _on_inventory_changed() -> void:
	refresh()
