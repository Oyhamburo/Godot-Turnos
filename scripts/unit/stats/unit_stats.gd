extends RefCounted
class_name UnitStats
##
## Estadísticas runtime de una unidad. Creado desde UnitStatsTemplate.
## Señales para actualizar HUD; métodos para daño/curar/mana.
##

signal hp_changed(current: int, max_val: int)
signal mana_changed(current: int, max_val: int)
signal stats_changed()

var template: UnitStatsTemplate

var hp: int = 30
var mana: int = 0

# Copias de stats base (para futuros modificadores/buffs)
var max_hp: int = 30
var max_mana: int = 0
var speed: int = 10
var armor: int = 0
var magic_resist: int = 0
var physical_damage: int = 8
var magic_damage: int = 0
var evasion: float = 0.05
var crit_chance: float = 0.05


static func from_template(t: UnitStatsTemplate) -> UnitStats:
	var s := UnitStats.new()
	if not t:
		return s
	s.template = t
	s.max_hp = maxi(0, t.max_hp)
	s.max_mana = maxi(0, t.max_mana)
	s.hp = s.max_hp
	s.mana = mini(s.max_mana, s.max_mana)
	s.speed = maxi(0, t.speed)
	s.armor = maxi(0, t.armor)
	s.magic_resist = maxi(0, t.magic_resist)
	s.physical_damage = maxi(0, t.physical_damage)
	s.magic_damage = maxi(0, t.magic_damage)
	s.evasion = clampf(t.evasion, 0.0, 1.0)
	s.crit_chance = clampf(t.crit_chance, 0.0, 1.0)
	return s


func apply_damage_physical(amount: int) -> void:
	if amount <= 0:
		return
	var taken: int = maxi(0, amount - armor)
	_set_hp(hp - taken)


func apply_damage_magical(amount: int) -> void:
	if amount <= 0:
		return
	var taken: int = maxi(0, amount - magic_resist)
	_set_hp(hp - taken)


## Aplica daño ya reducido (phys_taken + magic_taken). No aplica armadura/MR.
func apply_damage_direct(physical: int, magical: int) -> void:
	var total := maxi(0, physical) + maxi(0, magical)
	if total <= 0:
		return
	_set_hp(hp - total)


func spend_mana(amount: int) -> bool:
	if amount <= 0 or mana < amount:
		return false
	_set_mana(mana - amount)
	return true


func heal(amount: int) -> void:
	if amount <= 0:
		return
	_set_hp(hp + amount)


func restore_mana(amount: int) -> void:
	if amount <= 0:
		return
	_set_mana(mana + amount)


func _set_hp(v: int) -> void:
	hp = clampi(v, 0, max_hp)
	hp_changed.emit(hp, max_hp)


func _set_mana(v: int) -> void:
	mana = clampi(v, 0, max_mana)
	mana_changed.emit(mana, max_mana)
