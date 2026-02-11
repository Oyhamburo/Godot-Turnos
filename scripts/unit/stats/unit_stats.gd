extends RefCounted
class_name UnitStats
##
## Estadísticas runtime de una unidad. Creado desde UnitStatsTemplate.
## Señales para actualizar HUD; métodos para daño/curar/mana.
##

signal hp_changed(current: int, max_val: int)
signal mana_changed(current: int, max_val: int)
signal stats_changed()
signal ap_sp_changed(current_ap: int, current_sp: int)

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

# Acciones por turno (se resetean cada turno)
var max_primary_actions: int = 1
var max_secondary_actions: int = 2
var current_ap: int = 1
var current_sp: int = 2


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
	s.max_primary_actions = maxi(1, t.max_primary_actions)
	s.max_secondary_actions = maxi(0, t.max_secondary_actions)
	s.current_ap = s.max_primary_actions
	s.current_sp = s.max_secondary_actions
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


# ── ACCIONES POR TURNO (AP/SP) ────────────────────────────

## Resetea AP y SP al máximo (llamar al inicio de cada turno).
func reset_turn_actions() -> void:
	current_ap = max_primary_actions
	current_sp = max_secondary_actions
	ap_sp_changed.emit(current_ap, current_sp)


## Gasta AP. Devuelve true si se pudo gastar.
func spend_ap(amount: int = 1) -> bool:
	if current_ap < amount:
		return false
	current_ap -= amount
	ap_sp_changed.emit(current_ap, current_sp)
	return true


## Gasta SP. Devuelve true si se pudo gastar.
func spend_sp(amount: int = 1) -> bool:
	if current_sp < amount:
		return false
	current_sp -= amount
	ap_sp_changed.emit(current_ap, current_sp)
	return true


## Devuelve true si quedan acciones (AP o SP > 0).
func has_actions_remaining() -> bool:
	return current_ap > 0 or current_sp > 0
