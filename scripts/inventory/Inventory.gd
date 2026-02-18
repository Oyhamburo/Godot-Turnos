extends RefCounted
class_name Inventory

signal inventory_changed()

## Arma equipada en mano derecha (o arma 2H, null = vacío)
var equipped_right: WeaponData = null

## Arma equipada en mano izquierda (null = vacío; igual a equipped_right si es 2H)
var equipped_left: WeaponData = null

## Lista de todas las armas que posee la unidad (incluye las equipadas)
var weapons: Array[WeaponData] = []

## Consumibles
var items: Array[ItemData] = []

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

# ── Ítems ─────────────────────────────────────────────────────

func add_item(item: ItemData) -> void:
	if item:
		items.append(item)
		inventory_changed.emit()

func remove_item(item: ItemData) -> void:
	if items.has(item):
		items.erase(item)
		inventory_changed.emit()
