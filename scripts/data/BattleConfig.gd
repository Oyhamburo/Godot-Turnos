extends Resource
class_name BattleConfig

## Define quiénes participan en una batalla. Asignar desde menú y usar en CombatManager.

@export var battle_name: String = ""
@export var player_scene: PackedScene
@export var players_count: int = 3

@export_group("Enemigos Bruto")
@export var enemy_bruto_count: int = 0
@export var enemy_bruto_scene: PackedScene
@export var enemy_bruto_data: UnitData

@export_group("Enemigos comunes")
@export var enemy_common_count: int = 0
@export var enemy_common_scene: PackedScene


@export_group("Enemigos Esqueleto")
@export var enemy_skeleton_count: int = 0
@export var enemy_skeleton_scene: PackedScene
@export var enemy_skeleton_data: UnitData
