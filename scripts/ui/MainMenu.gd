extends Control

const MAP_SCENE := "res://scenes/ExploreMap.tscn"
const BATTLE_SCENE := "res://scenes/battle/BattleScene.tscn"
const WEAPON_PREVIEW_SCENE := "res://scenes/WeaponPreview.tscn"
const BATTLES_DIR := "res://data/battles/"

const _BattleConfig = preload("res://scripts/battle/data/battle_config.gd")
const _BattleEncounterConfig = preload("res://scripts/battle/data/battle_encounter_config.gd")

@onready var map_button: Button = %MapButton
@onready var battle_button: Button = %BattleButton
@onready var battle_option: OptionButton = %BattleOption
@onready var options_button: Button = %OptionsButton
@onready var options_panel: Control = %OptionsPanel
@onready var weapon_preview_button: Button = %WeaponPreviewButton

func _ready() -> void:
	map_button.pressed.connect(_on_map_pressed)
	battle_button.pressed.connect(_on_battle_pressed)
	weapon_preview_button.pressed.connect(_on_weapon_preview_pressed)
	options_button.pressed.connect(_on_options_pressed)
	options_panel.visible = false
	_populate_battle_options()
	battle_button.text = "Probar batalla"

func _populate_battle_options() -> void:
	battle_option.clear()
	battle_option.add_item("(usar escena)", 0)
	var paths: Array[String] = _scan_battle_configs()
	var idx := 1
	for path in paths:
		battle_option.add_item(path.get_file(), idx)
		battle_option.set_item_metadata(idx, path)
		idx += 1
	# Restaurar selección guardada
	var saved := BattleLauncher.config_path
	for i in range(battle_option.item_count):
		if battle_option.get_item_metadata(i) == saved:
			battle_option.selected = i
			return
	battle_option.selected = 0

func _scan_battle_configs() -> Array[String]:
	var out: Array[String] = []
	var dirs: Array[String] = [BATTLES_DIR, BATTLES_DIR.path_join("configs")]
	for dir_path in dirs:
		var d := DirAccess.open(dir_path)
		if not d:
			continue
		var files := d.get_files()
		for f in files:
			if not f.ends_with(".tres"):
				continue
			var path := dir_path.path_join(f)
			var res: Resource = load(path) as Resource
			if res is _BattleConfig or res is _BattleEncounterConfig:
				out.append(path)
	out.sort()
	return out

func _on_map_pressed() -> void:
	get_tree().change_scene_to_file(MAP_SCENE)

func _on_battle_pressed() -> void:
	var idx := battle_option.selected
	var path_selected = battle_option.get_item_metadata(idx) if idx >= 0 else null
	if idx > 0 and path_selected:
		BattleLauncher.set_config_path(path_selected)
	else:
		BattleLauncher.set_config_path("")
	get_tree().change_scene_to_file(BATTLE_SCENE)

func _on_weapon_preview_pressed() -> void:
	get_tree().change_scene_to_file(WEAPON_PREVIEW_SCENE)

func _on_options_pressed() -> void:
	options_panel.visible = true
	# Let the panel refresh with current values
	if options_panel.has_method("open"):
		options_panel.call("open")
