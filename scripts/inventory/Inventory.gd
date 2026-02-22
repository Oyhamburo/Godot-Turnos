extends RefCounted
class_name Inventory

signal inventory_changed()

## Capacidad máxima de ítems genéricos (items_genericos).
const MAX_SLOTS: int = 20

## Arma equipada en mano derecha (o arma 2H, null = vacío)
var equipped_right: WeaponData = null

## Arma equipada en mano izquierda (null = vacío; igual a equipped_right si es 2H)
var equipped_left: WeaponData = null

## Lista de todas las armas que posee la unidad (incluye las equipadas)
var weapons: Array[WeaponData] = []

## Consumibles (sistema de batalla; conservado para compatibilidad)
var items: Array[ItemData] = []

## Ítems genéricos del sistema RPG (ItemData + ArmorData).
## Capacidad máxima: MAX_SLOTS = 20.
var items_genericos: Array = []

## Oro del jugador.
var gold: int = 0

## Equipamiento del jugador (7 slots: head/chest/legs/boots/weapon/offhand/accessory).
var equipment: EquipmentData = null

# ── Armas ─────────────────────────────────────────────────────

func add_weapon(weapon: WeaponData) -> void:
	if weapon and not weapons.has(weapon):
		weapons.append(weapon)
		inventory_changed.emit()

func remove_weapon(weapon: WeaponData) -> void:
	if weapons.has(weapon):
		weapons.erase(weapon)
		if equipped_right == weapon:
			equipped_right = null
		if equipped_left == weapon:
			equipped_left = null
		inventory_changed.emit()

func has_weapon_equipped() -> bool:
	return equipped_right != null or equipped_left != null

## Devuelve las armas disponibles para equipar (excluye las actualmente equipadas en ambos slots)
func get_available_weapons() -> Array[WeaponData]:
	var result: Array[WeaponData] = []
	for w in weapons:
		if w != equipped_right and w != equipped_left:
			result.append(w)
	return result

## Devuelve el arma equipada en el slot indicado (0 = derecha, 1 = izquierda).
func get_equipped_in_slot(slot: int) -> WeaponData:
	return equipped_right if slot == 0 else equipped_left

## Asigna el arma en el slot indicado y emite inventory_changed.
## slot: 0 = derecha, 1 = izquierda
func set_equipped_in_slot(slot: int, weapon: WeaponData) -> void:
	if slot == 0:
		equipped_right = weapon
	else:
		equipped_left = weapon
	inventory_changed.emit()

# ── Ítems (sistema batalla — compatibilidad) ───────────────────

func add_item(item: ItemData) -> void:
	if item:
		items.append(item)
		inventory_changed.emit()

func remove_item(item: ItemData) -> void:
	if items.has(item):
		items.erase(item)
		inventory_changed.emit()

# ── Ítems genéricos (sistema RPG) ─────────────────────────────

## Añade un ítem genérico (ItemData o ArmorData) al inventario RPG.
## Retorna true si se añadió, false si el inventario está lleno.
func add_item_generic(item) -> bool:
	if item == null:
		return false
	if items_genericos.size() >= MAX_SLOTS:
		return false
	items_genericos.append(item)
	inventory_changed.emit()
	return true

## Elimina un ítem genérico del inventario RPG.
func remove_item_generic(item) -> void:
	if items_genericos.has(item):
		items_genericos.erase(item)
		inventory_changed.emit()

## Retorna true si el ítem está en items_genericos.
func has_item_generic(item) -> bool:
	return items_genericos.has(item)

## Retorna true si hay espacio disponible en el inventario RPG.
func has_space() -> bool:
	return items_genericos.size() < MAX_SLOTS

## Inicializa el EquipmentData si aún no existe.
func get_or_create_equipment() -> EquipmentData:
	if equipment == null:
		equipment = EquipmentData.new()
	return equipment

# ── Oro ───────────────────────────────────────────────────────

## Agrega oro. Siempre positivo.
func add_gold(amount: int) -> void:
	if amount > 0:
		gold += amount
		inventory_changed.emit()

## Gasta oro. Retorna false si no hay suficiente.
func spend_gold(amount: int) -> bool:
	if amount > gold:
		return false
	gold -= amount
	inventory_changed.emit()
	return true
