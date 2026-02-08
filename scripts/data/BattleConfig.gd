extends Resource
class_name BattleConfig

## Define quiénes participan en una batalla. Asignar desde menú y usar en CombatManager.

@export var battle_name: String = ""

@export_group("Caballero")
@export var player_knight_count: int = 0
@export var player_knight_scene: PackedScene
@export var player_knight_data: UnitData

@export_group("Mago")
@export var player_mage_count: int = 0
@export var player_mage_scene: PackedScene
@export var player_mage_data: UnitData

@export_group("Ranger")
@export var player_ranger_count: int = 0
@export var player_ranger_scene: PackedScene
@export var player_ranger_data: UnitData

@export_group("Pícaro")
@export var player_rogue_count: int = 0
@export var player_rogue_scene: PackedScene
@export var player_rogue_data: UnitData

@export_group("Bárbaro")
@export var player_barbarian_count: int = 0
@export var player_barbarian_scene: PackedScene
@export var player_barbarian_data: UnitData

@export_group("Pícaro con capucha")
@export var player_rogue_hooded_count: int = 0
@export var player_rogue_hooded_scene: PackedScene
@export var player_rogue_hooded_data: UnitData

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
