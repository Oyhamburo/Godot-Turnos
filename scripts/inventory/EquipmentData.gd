extends RefCounted
class_name EquipmentData
##
## Gestiona los 7 slots de equipamiento de un personaje.
## Cada slot puede contener un WeaponData, ArmorData o null.
## Emite `changed` cada vez que se equipa/desequipa algo.
##

## Emitido cuando un slot cambia. item puede ser WeaponData, ArmorData o null.
signal changed(slot_name: String, item)

## Mapa de slot → ítem equipado (null = vacío).
## Claves fijas: "weapon", "offhand", "head", "chest", "legs", "boots", "accessory"
var slots: Dictionary = {
	"weapon":    null,
	"offhand":   null,
	"head":      null,
	"chest":     null,
	"legs":      null,
	"boots":     null,
	"accessory": null,
}


## Equipa un ítem en el slot indicado.
## Retorna true si se equipó con éxito, false si el ítem no es compatible.
## Si el slot ya estaba ocupado, retorna el ítem anterior (para devolverlo al inventario).
func equip(slot_name: String, item) -> bool:
	if not slots.has(slot_name):
		push_warning("[EquipmentData] Slot desconocido: %s" % slot_name)
		return false
	if not is_slot_compatible(slot_name, item):
		return false
	slots[slot_name] = item
	changed.emit(slot_name, item)
	return true


## Desequipa el slot indicado y retorna el ítem que había (null si estaba vacío).
func unequip(slot_name: String):
	if not slots.has(slot_name):
		return null
	var anterior = slots[slot_name]
	slots[slot_name] = null
	changed.emit(slot_name, null)
	return anterior


## Devuelve el ítem en el slot indicado, o null si está vacío.
func get_item(slot_name: String):
	return slots.get(slot_name, null)


## Comprueba si un ítem es compatible con el slot indicado.
func is_slot_compatible(slot_name: String, item) -> bool:
	if item == null:
		return true  # siempre se puede "equipar" nada (vaciar)

	match slot_name:
		"weapon":
			return item is WeaponData or \
				(item is ItemData and item.item_type in [ItemData.ItemType.ARMOR_CHEST])
			# WeaponData va en weapon; para ItemData se acepta solo si es tipo arma
			# (mantenemos sencillo: WeaponData siempre es válido en weapon)
		"offhand":
			return (item is ArmorData and item.armor_slot == ArmorData.ArmorSlot.OFFHAND) or \
				(item is WeaponData)  # arma secundaria
		"head":
			return item is ArmorData and item.armor_slot == ArmorData.ArmorSlot.HEAD
		"chest":
			return item is ArmorData and item.armor_slot == ArmorData.ArmorSlot.CHEST
		"legs":
			return item is ArmorData and item.armor_slot == ArmorData.ArmorSlot.LEGS
		"boots":
			return item is ArmorData and item.armor_slot == ArmorData.ArmorSlot.BOOTS
		"accessory":
			return item is ArmorData and item.armor_slot == ArmorData.ArmorSlot.ACCESSORY
	return false


## Suma los stats_mod de todos los ítems equipados.
## Retorna un Dictionary con claves hp, atk, def, speed, weight.
func get_total_stats_mod() -> Dictionary:
	var total: Dictionary = {"hp": 0, "atk": 0, "def": 0, "speed": 0, "weight": 0}
	for slot_name in slots:
		var item = slots[slot_name]
		if item == null:
			continue
		var mods: Dictionary = {}
		if item is ArmorData:
			mods = item.stats_mod
		elif item is WeaponData:
			# WeaponData tiene atk_bonus, def_bonus, hp_bonus, speed_bonus
			mods = {
				"atk":    item.atk_bonus    if "atk_bonus"    in item else 0,
				"def":    item.def_bonus    if "def_bonus"    in item else 0,
				"hp":     item.hp_bonus     if "hp_bonus"     in item else 0,
				"speed":  item.speed_bonus  if "speed_bonus"  in item else 0,
				"weight": item.weight       if "weight"       in item else 0,
			}
		elif item is ItemData:
			mods = item.stats_mod
		for key in mods:
			if total.has(key):
				total[key] += mods[key]
	return total


## Devuelve un Array con todos los nombres de slot (orden para la UI).
func get_slot_names() -> Array:
	return ["head", "chest", "legs", "boots", "weapon", "offhand", "accessory"]
