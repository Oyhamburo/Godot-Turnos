extends Control

@onready var play_button: Button = %PlayButton
@onready var options_button: Button = %OptionsButton
@onready var options_panel: Control = %OptionsPanel

func _ready() -> void:
	play_button.pressed.connect(_on_play_pressed)
	options_button.pressed.connect(_on_options_pressed)
	options_panel.visible = false

func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/Battle.tscn")

func _on_options_pressed() -> void:
	options_panel.visible = true
	# Let the panel refresh with current values
	if options_panel.has_method("open"):
		options_panel.call("open")
