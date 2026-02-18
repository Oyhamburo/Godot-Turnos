extends Resource
class_name UnitStatsTemplate
##
## Plantilla de estadísticas base para unidades. Valores editables en el Inspector.
##

@export var display_name: String = "Unit"
@export_enum("PLAYER", "ENEMY") var team: int = 0

@export var max_hp: int = 30
@export var max_mana: int = 0

@export var speed: int = 10
@export var armor: int = 0
@export var magic_resist: int = 0

@export var physical_damage: int = 8
@export var magic_damage: int = 0

@export_range(0.0, 1.0) var evasion: float = 0.05
@export_range(0.0, 1.0) var crit_chance: float = 0.05

@export_group("Acciones por turno")
@export var max_primary_actions: int = 1    ## AP por turno (atacar cuesta 1)
@export var max_secondary_actions: int = 2  ## SP por turno (moverse 1 casilla cuesta 1)
