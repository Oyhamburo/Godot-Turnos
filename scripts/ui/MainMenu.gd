extends Control

const BATTLE_SCENE := "res://scenes/Battle.tscn"
const BATTLE_EASY := preload("res://data/battles/battle_easy.tres")
const BATTLE_HARD := preload("res://data/battles/battle_hard.tres")

@onready var battle_easy_button: Button = %BattleEasyButton
@onready var battle_hard_button: Button = %BattleHardButton
@onready var options_button: Button = %OptionsButton
@onready var options_panel: Control = %OptionsPanel

func _ready() -> void:
	battle_easy_button.pressed.connect(_on_battle_easy_pressed)
	battle_hard_button.pressed.connect(_on_battle_hard_pressed)
	options_button.pressed.connect(_on_options_pressed)
	options_panel.visible = false

func _on_battle_easy_pressed() -> void:
	_get_battle_manager().set_battle(BATTLE_EASY)
	get_tree().change_scene_to_file(BATTLE_SCENE)

func _on_battle_hard_pressed() -> void:
	_get_battle_manager().set_battle(BATTLE_HARD)
	get_tree().change_scene_to_file(BATTLE_SCENE)

func _get_battle_manager() -> Node:
	return get_node("/root/BattleManager")

func _on_options_pressed() -> void:
	options_panel.visible = true
	# Let the panel refresh with current values
	if options_panel.has_method("open"):
		options_panel.call("open")
