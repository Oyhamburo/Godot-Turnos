extends Resource
class_name BattleConfig

## Define quiénes participan en una batalla. Asignar desde menú y usar en CombatManager.

@export var battle_name: String = ""
@export var player_scene: PackedScene
@export var players_count: int = 3

@export_group("Esqueleto Guerrero")
@export var enemy_skeleton_warrior_count: int = 0
@export var enemy_skeleton_warrior_scene: PackedScene
@export var enemy_skeleton_warrior_data: UnitData

@export_group("Esqueleto Mago")
@export var enemy_skeleton_mage_count: int = 0
@export var enemy_skeleton_mage_scene: PackedScene
@export var enemy_skeleton_mage_data: UnitData

@export_group("Esqueleto Minion")
@export var enemy_skeleton_minion_count: int = 0
@export var enemy_skeleton_minion_scene: PackedScene
@export var enemy_skeleton_minion_data: UnitData

@export_group("Esqueleto Pícaro")
@export var enemy_skeleton_rogue_count: int = 0
@export var enemy_skeleton_rogue_scene: PackedScene
@export var enemy_skeleton_rogue_data: UnitData
