extends RefCounted
class_name PlayerStats
##
## Stats calculados del jugador = base + modificadores del equipamiento.
## Emite `changed` cada vez que se recalculan (al equipar/desequipar).
##

## Emitido tras recalculate(). Conectar en la UI para refrescar labels.
signal changed

## Stats base sin ningún equipamiento.
var base: Dictionary = {
	"hp":     30,
	"atk":    8,
	"def":    0,
	"speed":  10,
	"weight": 0,
}

## Referencia al EquipmentData del jugador (asignar desde el panel).
var equipment: EquipmentData = null

## Stats finales (base + mods). Se recalculan con recalculate().
var final_stats: Dictionary = {}


func _init() -> void:
	recalculate()


## Recalcula final_stats y emite la señal `changed`.
func recalculate() -> void:
	final_stats = base.duplicate()
	if equipment:
		var mods := equipment.get_total_stats_mod()
		for key in mods:
			if final_stats.has(key):
				final_stats[key] += mods[key]
	changed.emit()


## Conecta al EquipmentData para auto-recalcular al equipar/desequipar.
func bind_equipment(equip_data: EquipmentData) -> void:
	if equipment and equipment.changed.is_connected(_on_equipment_changed):
		equipment.changed.disconnect(_on_equipment_changed)
	equipment = equip_data
	if equipment:
		equipment.changed.connect(_on_equipment_changed)
	recalculate()


## Preview del cambio de stats si se equipa/desequipa `item` en `slot_name`.
## Retorna un Dictionary con los deltas: {"atk": +2, "def": -1, ...}
## Solo incluye claves que cambian.
func get_display_diff(slot_name: String, item) -> Dictionary:
	if not equipment:
		return {}

	# Calcular mods actuales
	var mods_actual := equipment.get_total_stats_mod()

	# Crear copia temporal de slots
	var temp_slots := equipment.slots.duplicate()
	temp_slots[slot_name] = item

	# Calcular mods si equipáramos el ítem nuevo
	var total_nuevo: Dictionary = {"hp": 0, "atk": 0, "def": 0, "speed": 0, "weight": 0}
	for sn in temp_slots:
		var it = temp_slots[sn]
		if it == null:
			continue
		var m: Dictionary = {}
		if it is ArmorData:
			m = it.stats_mod
		elif it is WeaponData:
			m = {
				"atk":    it.atk_bonus   if "atk_bonus"   in it else 0,
				"def":    it.def_bonus   if "def_bonus"   in it else 0,
				"hp":     it.hp_bonus    if "hp_bonus"    in it else 0,
				"speed":  it.speed_bonus if "speed_bonus" in it else 0,
				"weight": it.weight      if "weight"      in it else 0,
			}
		elif it is ItemData:
			m = it.stats_mod
		for key in m:
			if total_nuevo.has(key):
				total_nuevo[key] += m[key]

	var diff: Dictionary = {}
	for key in total_nuevo:
		var delta: int = total_nuevo[key] - mods_actual.get(key, 0)
		if delta != 0:
			diff[key] = delta
	return diff


func _on_equipment_changed(_slot_name: String, _item) -> void:
	recalculate()
