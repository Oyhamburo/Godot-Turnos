extends Resource
class_name AbilityData

## Daño físico base de la habilidad (se suma al physical_damage del personaje).
@export var physical_damage: int = 0
## Daño mágico base de la habilidad (se suma al magic_damage del personaje).
@export var magic_damage: int = 0
## Probabilidad de acertar (0.0 a 1.0). Habilidades con más daño suelen tener menos precisión.
@export_range(0.0, 1.0) var hit_chance: float = 0.9
## Nombre para la UI (opcional).
@export var display_name: String = ""
