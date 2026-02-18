@tool
extends ScrollContainer
##
## Dock del Battle Encounter Builder: UI para editar BattleEncounterConfig y Bake/Preview/Clear.
##

const _BattleEncounterConfig = preload("res://scripts/battle/data/battle_encounter_config.gd")
const _UnitSpawn = preload("res://scripts/battle/data/unit_spawn.gd")
const _EncounterGenerator = preload("res://scripts/battle/tools/encounter_generator.gd")
const _GridBoardPreviewScript = preload("res://addons/battle_encounter_builder/ui/GridBoardPreview.gd")

const UNITS_DIR := "res://scenes/units/"
const FLOORS_DIR := "res://scenes/floors/"
const KAYKIT_FLOOR_DIR := "res://assets/KayKit_DungeonRemastered_1.1_FREE/Assets/gltf/"
const BATTLE_ENCOUNTER_CONFIG_SCRIPT := preload("res://scripts/battle/data/battle_encounter_config.gd")
const UNIT_SPAWN_SCRIPT := preload("res://scripts/battle/data/unit_spawn.gd")

var _plugin: EditorPlugin
var _config: Resource
var _main: VBoxContainer
var _width_spin: SpinBox
var _height_spin: SpinBox
var _tile_size_spin: SpinBox
var _seed_spin: SpinBox
var _obstacle_density_spin: SpinBox
var _obstacle_mode_option: OptionButton
var _floor_mode_option: OptionButton
var _floor_single_path: LineEdit
var _players_count_label: Label
var _enemies_count_label: Label
var _last_bake_old_tiles: Array[Node] = []
var _last_bake_old_units: Array[Node] = []
var _config_file_path: String = ""
var _grid_preview: Control
var _selected_spawn_label: Label
var _players_item_list: ItemList
var _enemies_item_list: ItemList
var _selected_player_idx: int = -1
var _selected_enemy_idx: int = -1
var _facing_mode_option: OptionButton


func set_plugin(plugin: EditorPlugin) -> void:
	_plugin = plugin


func _ready() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	call_deferred("_build_ui")


func _build_ui() -> void:
	_main = VBoxContainer.new()
	_main.add_theme_constant_override("separation", 12)
	add_child(_main)

	# Título
	var header := PanelContainer.new()
	var header_bg := StyleBoxFlat.new()
	header_bg.bg_color = Color(0.2, 0.24, 0.32, 1)
	header_bg.set_corner_radius_all(4)
	header_bg.set_content_margin_all(12)
	header.add_theme_stylebox_override("panel", header_bg)
	var header_hbox := HBoxContainer.new()
	var title_lbl := Label.new()
	title_lbl.text = "Battle Encounter Builder"
	title_lbl.add_theme_font_size_override("font_size", 18)
	title_lbl.add_theme_color_override("font_color", Color(0.9, 0.92, 0.95))
	header_hbox.add_child(title_lbl)
	header.add_child(header_hbox)
	_main.add_child(header)
	_main.add_child(HSeparator.new())

	# Margen general
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	margin.add_child(content)
	_main.add_child(margin)

	# Config
	var config_section := _make_section("Configuración")
	var config_row := HBoxContainer.new()
	var load_btn := Button.new()
	load_btn.text = "Load"
	load_btn.pressed.connect(_on_load_pressed)
	var new_btn := Button.new()
	new_btn.text = "New"
	new_btn.pressed.connect(_on_new_pressed)
	var save_btn := Button.new()
	save_btn.text = "Save"
	save_btn.pressed.connect(_on_save_pressed)
	config_row.add_child(load_btn)
	config_row.add_child(new_btn)
	config_row.add_child(save_btn)
	config_section.add_child(config_row)
	content.add_child(config_section)

	# Board
	var board_section := _make_section("Tablero")
	_width_spin = SpinBox.new()
	_width_spin.min_value = 2
	_width_spin.max_value = 20
	_width_spin.value = 4
	_width_spin.value_changed.connect(_on_board_changed)
	_height_spin = SpinBox.new()
	_height_spin.min_value = 2
	_height_spin.max_value = 20
	_height_spin.value = 4
	_height_spin.value_changed.connect(_on_board_changed)
	_tile_size_spin = SpinBox.new()
	_tile_size_spin.min_value = 1.0
	_tile_size_spin.max_value = 5.0
	_tile_size_spin.step = 0.5
	_tile_size_spin.value = 2.0
	_tile_size_spin.value_changed.connect(_on_board_changed)
	_seed_spin = SpinBox.new()
	_seed_spin.min_value = 0
	_seed_spin.max_value = 2147483647
	_seed_spin.value = 12345
	_seed_spin.value_changed.connect(_on_board_changed)
	var board_grid := GridContainer.new()
	board_grid.columns = 2
	board_grid.add_child(_label("Ancho"))
	board_grid.add_child(_width_spin)
	board_grid.add_child(_label("Alto"))
	board_grid.add_child(_height_spin)
	board_grid.add_child(_label("Tamaño tile"))
	board_grid.add_child(_tile_size_spin)
	board_grid.add_child(_label("Semilla"))
	board_grid.add_child(_seed_spin)
	board_section.add_child(board_grid)
	content.add_child(board_section)

	# Grid Preview
	var grid_section := _make_section("Grid Preview")
	_selected_spawn_label = Label.new()
	_selected_spawn_label.text = "Selected Spawn: ninguno"
	grid_section.add_child(_selected_spawn_label)
	_grid_preview = _GridBoardPreviewScript.new()
	_grid_preview.set_grid_size(4, 4)
	_grid_preview.cell_clicked.connect(_on_grid_cell_clicked)
	grid_section.add_child(_grid_preview)
	var legend_lbl := Label.new()
	legend_lbl.text = "Verde=Player | Rojo=Enemy | Marrón=Obstáculo | Clic izq=asignar | Der=quitar | SHIFT+clic=toggle obstáculo"
	legend_lbl.add_theme_font_size_override("font_size", 10)
	legend_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	grid_section.add_child(legend_lbl)
	var grid_btns := HBoxContainer.new()
	var clear_spawns_btn := Button.new()
	clear_spawns_btn.text = "Limpiar Spawns"
	clear_spawns_btn.pressed.connect(_on_clear_spawns_pressed)
	var clear_obstacles_btn := Button.new()
	clear_obstacles_btn.text = "Limpiar Obstáculos"
	clear_obstacles_btn.pressed.connect(_on_clear_obstacles_pressed)
	grid_btns.add_child(clear_spawns_btn)
	grid_btns.add_child(clear_obstacles_btn)
	grid_section.add_child(grid_btns)
	content.add_child(grid_section)

	# Players
	var players_section := _make_section("Jugadores")
	_players_item_list = ItemList.new()
	_players_item_list.custom_minimum_size = Vector2(0, 60)
	_players_item_list.item_selected.connect(_on_player_item_selected)
	players_section.add_child(_players_item_list)
	var players_row := HBoxContainer.new()
	var add_player_btn := Button.new()
	add_player_btn.text = "Añadir Jugador"
	add_player_btn.pressed.connect(_on_add_player_pressed)
	var auto_player_btn := Button.new()
	auto_player_btn.text = "Auto 1"
	auto_player_btn.pressed.connect(_on_auto_fill_players.bind(1))
	_players_count_label = Label.new()
	_players_count_label.text = "0 spawns"
	players_row.add_child(add_player_btn)
	players_row.add_child(auto_player_btn)
	players_row.add_child(_players_count_label)
	players_section.add_child(players_row)
	content.add_child(players_section)

	# Enemies
	var enemies_section := _make_section("Enemigos")
	_enemies_item_list = ItemList.new()
	_enemies_item_list.custom_minimum_size = Vector2(0, 60)
	_enemies_item_list.item_selected.connect(_on_enemy_item_selected)
	enemies_section.add_child(_enemies_item_list)
	var enemies_row := HBoxContainer.new()
	var add_enemy_btn := Button.new()
	add_enemy_btn.text = "Añadir Enemigo"
	add_enemy_btn.pressed.connect(_on_add_enemy_pressed)
	var auto_enemy_btn := Button.new()
	auto_enemy_btn.text = "Auto 1"
	auto_enemy_btn.pressed.connect(_on_auto_fill_enemies.bind(1))
	_enemies_count_label = Label.new()
	_enemies_count_label.text = "0 spawns"
	enemies_row.add_child(add_enemy_btn)
	enemies_row.add_child(auto_enemy_btn)
	enemies_row.add_child(_enemies_count_label)
	enemies_section.add_child(enemies_row)
	content.add_child(enemies_section)

	# Obstacles
	var obstacles_section := _make_section("Obstáculos")
	_obstacle_mode_option = OptionButton.new()
	_obstacle_mode_option.add_item("manual", 0)
	_obstacle_mode_option.add_item("random", 1)
	_obstacle_mode_option.add_item("pattern", 2)
	_obstacle_mode_option.item_selected.connect(_on_obstacle_changed)
	_obstacle_density_spin = SpinBox.new()
	_obstacle_density_spin.min_value = 0.0
	_obstacle_density_spin.max_value = 1.0
	_obstacle_density_spin.step = 0.05
	_obstacle_density_spin.value = 0.15
	_obstacle_density_spin.value_changed.connect(_on_obstacle_changed)
	var obs_grid := GridContainer.new()
	obs_grid.columns = 2
	obs_grid.add_child(_label("Modo"))
	obs_grid.add_child(_obstacle_mode_option)
	obs_grid.add_child(_label("Densidad"))
	obs_grid.add_child(_obstacle_density_spin)
	_facing_mode_option = OptionButton.new()
	_facing_mode_option.add_item("look_at_opponent_centroid", 0)
	_facing_mode_option.add_item("look_at_nearest_opponent", 1)
	_facing_mode_option.add_item("fixed", 2)
	_facing_mode_option.item_selected.connect(_on_obstacle_changed)
	obs_grid.add_child(_label("Orientación unidades"))
	obs_grid.add_child(_facing_mode_option)
	obstacles_section.add_child(obs_grid)
	content.add_child(obstacles_section)

	# Floors
	var floors_section := _make_section("Suelos")
	_floor_mode_option = OptionButton.new()
	_floor_mode_option.add_item("single", 0)
	_floor_mode_option.add_item("weighted", 1)
	_floor_mode_option.add_item("manual", 2)
	_floor_mode_option.item_selected.connect(_on_floor_changed)
	_floor_single_path = LineEdit.new()
	_floor_single_path.placeholder_text = "Ruta a escena de piso (opcional)"
	floors_section.add_child(_floor_mode_option)
	floors_section.add_child(_floor_single_path)
	content.add_child(floors_section)

	# Actions
	var actions_section := _make_section("Acciones")
	var gen_btn := Button.new()
	gen_btn.text = "Generar Vista Previa"
	gen_btn.pressed.connect(_on_generate_preview_pressed)
	var bake_btn := Button.new()
	bake_btn.text = "Aplicar a Escena"
	bake_btn.pressed.connect(_on_bake_pressed)
	var clear_btn := Button.new()
	clear_btn.text = "Limpiar Generado"
	clear_btn.pressed.connect(_on_clear_pressed)
	var use_test_btn := Button.new()
	use_test_btn.text = "Usar para probar"
	use_test_btn.pressed.connect(_on_use_for_test_pressed)
	actions_section.add_child(gen_btn)
	actions_section.add_child(bake_btn)
	actions_section.add_child(clear_btn)
	actions_section.add_child(use_test_btn)
	content.add_child(actions_section)

	# Botones de config en español
	load_btn.text = "Cargar"
	new_btn.text = "Nuevo"
	save_btn.text = "Guardar"

	_on_new_pressed()


func _make_section(title: String) -> VBoxContainer:
	var v := VBoxContainer.new()
	var lbl := Label.new()
	lbl.text = title
	lbl.add_theme_font_size_override("font_size", 14)
	v.add_child(lbl)
	v.add_theme_constant_override("separation", 4)
	return v


func _label(t: String) -> Label:
	var l := Label.new()
	l.text = t
	return l


func _ensure_config() -> void:
	if not _config:
		_config = _BattleEncounterConfig.new()
		_config.width = 4
		_config.height = 4
		_config.tile_size = 2.0
		_config.seed_value = 12345
		_config.obstacle_mode = "manual"
		_config.obstacle_density = 0.15
		_config.floor_mode = "single"
		_config.facing_mode = "look_at_opponent_centroid"
		_refresh_ui_from_config()


func _refresh_ui_from_config() -> void:
	if not _config:
		return
	if not is_instance_valid(_width_spin):
		return
	_width_spin.value = _config.width
	_height_spin.value = _config.height
	_tile_size_spin.value = _config.tile_size
	_seed_spin.value = _config.seed_value
	_obstacle_density_spin.value = _config.obstacle_density
	_obstacle_mode_option.selected = ["manual", "random", "pattern"].find(_config.obstacle_mode)
	if _obstacle_mode_option.selected < 0:
		_obstacle_mode_option.selected = 0
	if is_instance_valid(_facing_mode_option):
		_facing_mode_option.selected = ["look_at_opponent_centroid", "look_at_nearest_opponent", "fixed"].find(_config.facing_mode)
		if _facing_mode_option.selected < 0:
			_facing_mode_option.selected = 0
	_floor_mode_option.selected = ["single", "weighted", "manual"].find(_config.floor_mode)
	if _floor_mode_option.selected < 0:
		_floor_mode_option.selected = 0
	if _config.floor_single_scene:
		_floor_single_path.text = _config.floor_single_scene.resource_path
	else:
		_floor_single_path.text = ""
	_players_count_label.text = "%d spawn(s)" % _config.players.size()
	_enemies_count_label.text = "%d spawn(s)" % _config.enemies.size()
	_refresh_item_lists()
	_refresh_grid_data()
	_update_selected_spawn_label()


func _refresh_config_from_ui() -> void:
	if not _config:
		return
	_config.width = int(_width_spin.value)
	_config.height = int(_height_spin.value)
	_config.tile_size = _tile_size_spin.value
	_config.seed_value = int(_seed_spin.value)
	_config.obstacle_density = _obstacle_density_spin.value
	_config.obstacle_mode = ["manual", "random", "pattern"][_obstacle_mode_option.selected]
	if is_instance_valid(_facing_mode_option):
		_config.facing_mode = ["look_at_opponent_centroid", "look_at_nearest_opponent", "fixed"][_facing_mode_option.selected]
	_config.floor_mode = ["single", "weighted", "manual"][_floor_mode_option.selected]
	if _floor_single_path.text.strip_edges().is_empty():
		_config.floor_single_scene = null
	elif ResourceLoader.exists(_floor_single_path.text):
		_config.floor_single_scene = load(_floor_single_path.text) as PackedScene


func _on_load_pressed() -> void:
	if not _plugin:
		return
	var ed := _plugin.get_editor_interface()
	var fd := EditorFileDialog.new()
	fd.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	fd.access = EditorFileDialog.ACCESS_RESOURCES
	fd.add_filter("*.tres", "Resource")
	fd.title = "Load Battle Encounter Config"
	fd.file_selected.connect(_on_config_file_selected)
	ed.get_base_control().add_child(fd)
	fd.popup_centered_ratio(0.5)


func _on_config_file_selected(path: String) -> void:
	var res: Resource = load(path) as Resource
	if res is _BattleEncounterConfig:
		_config = res
		_config_file_path = path
		_refresh_ui_from_config()
		_alert("Config cargado: %s" % path)
	else:
		_alert("No es un BattleEncounterConfig.")


func _on_new_pressed() -> void:
	_config = _BattleEncounterConfig.new()
	_config_file_path = ""
	_config.width = 4
	_config.height = 4
	_config.tile_size = 2.0
	_config.seed_value = 12345
	_config.obstacle_mode = "manual"
	_config.obstacle_density = 0.15
	_config.floor_mode = "single"
	_config.facing_mode = "look_at_opponent_centroid"
	_selected_player_idx = -1
	_selected_enemy_idx = -1
	_refresh_ui_from_config()
	_alert("New config created.")


func _on_save_pressed() -> void:
	if not _config or not _plugin:
		return
	_refresh_config_from_ui()
	var fd := EditorFileDialog.new()
	fd.file_mode = EditorFileDialog.FILE_MODE_SAVE_FILE
	fd.access = EditorFileDialog.ACCESS_RESOURCES
	fd.add_filter("*.tres", "Resource")
	fd.title = "Save Battle Encounter Config"
	fd.file_selected.connect(_on_save_file_selected)
	_plugin.get_editor_interface().get_base_control().add_child(fd)
	fd.popup_centered_ratio(0.5)


func _on_save_file_selected(path: String) -> void:
	if not path.ends_with(".tres"):
		path += ".tres"
	var err := ResourceSaver.save(_config, path)
	if err == OK:
		_config_file_path = path
		_alert("Guardado: %s" % path)
	else:
		_alert("Error al guardar: %s" % error_string(err))


func _on_board_changed(_v = null) -> void:
	_refresh_config_from_ui()
	if _config:
		_clamp_and_clean_coords()
		_refresh_grid_data()


func _on_obstacle_changed(_idx = null) -> void:
	_refresh_config_from_ui()


func _on_floor_changed(_idx = null) -> void:
	_refresh_config_from_ui()


func _refresh_item_lists() -> void:
	if not _config or not is_instance_valid(_players_item_list):
		return
	_players_item_list.clear()
	for i in range(_config.players.size()):
		_players_item_list.add_item("Player #%d" % i)
	if _selected_player_idx >= 0 and _selected_player_idx < _config.players.size():
		_players_item_list.select(_selected_player_idx)
	_enemies_item_list.clear()
	for i in range(_config.enemies.size()):
		_enemies_item_list.add_item("Enemy #%d" % i)
	if _selected_enemy_idx >= 0 and _selected_enemy_idx < _config.enemies.size():
		_enemies_item_list.select(_selected_enemy_idx)


func _refresh_grid_data() -> void:
	if not _config or not is_instance_valid(_grid_preview):
		return
	_grid_preview.set_grid_size(_config.width, _config.height)
	_grid_preview.obstacles = _config.obstacle_manual_coords.duplicate()
	_grid_preview.player_spawns.clear()
	_grid_preview.enemy_spawns.clear()
	for sp in _config.players:
		if sp and sp.position_mode == "manual":
			_grid_preview.player_spawns.append(sp.coord)
	for sp in _config.enemies:
		if sp and sp.position_mode == "manual":
			_grid_preview.enemy_spawns.append(sp.coord)
	_grid_preview.selected_spawn_key = _get_selected_spawn_key()
	_grid_preview.notify_data_changed()


func _get_selected_spawn_key() -> String:
	if _selected_player_idx >= 0 and _selected_player_idx < _config.players.size():
		return "player:%d" % _selected_player_idx
	if _selected_enemy_idx >= 0 and _selected_enemy_idx < _config.enemies.size():
		return "enemy:%d" % _selected_enemy_idx
	return ""


func _update_selected_spawn_label() -> void:
	var key := _get_selected_spawn_key()
	if key.is_empty():
		_selected_spawn_label.text = "Selected Spawn: ninguno"
	elif key.begins_with("player:"):
		_selected_spawn_label.text = "Selected Spawn: Player #%s" % key.substr(7)
	else:
		_selected_spawn_label.text = "Selected Spawn: Enemy #%s" % key.substr(6)


func _on_player_item_selected(idx: int) -> void:
	_selected_player_idx = idx
	_selected_enemy_idx = -1
	if is_instance_valid(_enemies_item_list):
		_enemies_item_list.deselect_all()
	_update_selected_spawn_label()
	_refresh_grid_data()


func _on_enemy_item_selected(idx: int) -> void:
	_selected_enemy_idx = idx
	_selected_player_idx = -1
	if is_instance_valid(_players_item_list):
		_players_item_list.deselect_all()
	_update_selected_spawn_label()
	_refresh_grid_data()


func _clamp_and_clean_coords() -> void:
	if not _config:
		return
	var w: int = _config.width
	var h: int = _config.height
	var new_manual: Array[Vector2i] = []
	for c in _config.obstacle_manual_coords:
		if c.x >= 0 and c.x < w and c.y >= 0 and c.y < h:
			new_manual.append(c)
	_config.obstacle_manual_coords = new_manual
	for sp in _config.players:
		if sp and sp.position_mode == "manual":
			if sp.coord.x < 0 or sp.coord.x >= w or sp.coord.y < 0 or sp.coord.y >= h:
				sp.position_mode = "zone"
				sp.allowed_zone = Rect2i(0, 0, 2, h)
	for sp in _config.enemies:
		if sp and sp.position_mode == "manual":
			if sp.coord.x < 0 or sp.coord.x >= w or sp.coord.y < 0 or sp.coord.y >= h:
				sp.position_mode = "zone"
				sp.allowed_zone = Rect2i(max(0, w - 2), 0, 2, h)


func _on_grid_cell_clicked(coord: Vector2i, button: int, modifiers: int) -> void:
	_ensure_config()
	_refresh_config_from_ui()
	var w: int = _config.width
	var h: int = _config.height
	if coord.x < 0 or coord.x >= w or coord.y < 0 or coord.y >= h:
		return
	var shift := (modifiers & KEY_MASK_SHIFT) != 0
	if shift:
		var key := _coord_key(coord)
		var idx := -1
		for i in range(_config.obstacle_manual_coords.size()):
			if _coord_key(_config.obstacle_manual_coords[i]) == key:
				idx = i
				break
		if idx >= 0:
			_config.obstacle_manual_coords.remove_at(idx)
		else:
			_config.obstacle_manual_coords.append(coord)
		_config.obstacle_mode = "manual"
		_refresh_grid_data()
		_refresh_ui_from_config()
		return
	if button == MOUSE_BUTTON_RIGHT:
		var spawn := _get_spawn_at_coord(coord)
		if spawn:
			spawn.position_mode = "zone"
			if spawn.team == "player":
				spawn.allowed_zone = Rect2i(0, 0, 2, h)
			else:
				spawn.allowed_zone = Rect2i(max(0, w - 2), 0, 2, h)
			_refresh_grid_data()
			_refresh_ui_from_config()
		return
	if button == MOUSE_BUTTON_LEFT:
		var key := _get_selected_spawn_key()
		if key.is_empty():
			return
		if coord in _config.obstacle_manual_coords:
			_alert("Celda bloqueada.")
			return
		if _get_spawn_at_coord(coord):
			_alert("Celda ocupada por otro spawn.")
			return
		var spawn := _get_selected_spawn()
		if spawn:
			spawn.position_mode = "manual"
			spawn.coord = coord
			_refresh_grid_data()
			_refresh_ui_from_config()


func _get_spawn_at_coord(coord: Vector2i) -> Variant:
	for sp in _config.players:
		if sp and sp.position_mode == "manual" and sp.coord == coord:
			return sp
	for sp in _config.enemies:
		if sp and sp.position_mode == "manual" and sp.coord == coord:
			return sp
	return null


func _get_selected_spawn() -> Variant:
	if _selected_player_idx >= 0 and _selected_player_idx < _config.players.size():
		return _config.players[_selected_player_idx]
	if _selected_enemy_idx >= 0 and _selected_enemy_idx < _config.enemies.size():
		return _config.enemies[_selected_enemy_idx]
	return null


static func _coord_key(c: Vector2i) -> String:
	return "%d,%d" % [c.x, c.y]


func _on_clear_spawns_pressed() -> void:
	_ensure_config()
	_refresh_config_from_ui()
	var h: int = _config.height
	var w: int = _config.width
	for sp in _config.players:
		if sp:
			sp.position_mode = "zone"
			sp.allowed_zone = Rect2i(0, 0, 2, h)
	for sp in _config.enemies:
		if sp:
			sp.position_mode = "zone"
			sp.allowed_zone = Rect2i(max(0, w - 2), 0, 2, h)
	_refresh_grid_data()
	_refresh_ui_from_config()
	_alert("Spawn positions cleared.")


func _on_clear_obstacles_pressed() -> void:
	_ensure_config()
	_refresh_config_from_ui()
	_config.obstacle_manual_coords.clear()
	_config.obstacle_mode = "manual"
	_refresh_grid_data()
	_refresh_ui_from_config()
	_alert("Obstacles cleared.")


func _on_add_player_pressed() -> void:
	_ensure_config()
	var spawn := _UnitSpawn.new()
	spawn.team = "player"
	spawn.position_mode = "zone"
	spawn.allowed_zone = Rect2i(0, 0, 2, _config.height)
	spawn.unit_scene = _get_first_unit_scene()
	spawn.unit_data = _get_first_unit_data("player")
	_config.players.append(spawn)
	_refresh_ui_from_config()


func _on_add_enemy_pressed() -> void:
	_ensure_config()
	var spawn := _UnitSpawn.new()
	spawn.team = "enemy"
	spawn.position_mode = "zone"
	spawn.allowed_zone = Rect2i(_config.width - 2, 0, 2, _config.height)
	spawn.unit_scene = _get_first_unit_scene()
	spawn.unit_data = _get_first_unit_data("enemy")
	_config.enemies.append(spawn)
	_refresh_ui_from_config()


func _on_auto_fill_players(n: int) -> void:
	_ensure_config()
	_config.players.clear()
	for i in n:
		var spawn := _UnitSpawn.new()
		spawn.team = "player"
		spawn.position_mode = "zone"
		spawn.allowed_zone = Rect2i(0, 0, 2, _config.height)
		spawn.unit_scene = _get_first_unit_scene()
		spawn.unit_data = _get_first_unit_data("player")
		_config.players.append(spawn)
	_refresh_ui_from_config()


func _on_auto_fill_enemies(n: int) -> void:
	_ensure_config()
	_config.enemies.clear()
	for i in n:
		var spawn := _UnitSpawn.new()
		spawn.team = "enemy"
		spawn.position_mode = "zone"
		spawn.allowed_zone = Rect2i(_config.width - 2, 0, 2, _config.height)
		spawn.unit_scene = _get_first_unit_scene()
		spawn.unit_data = _get_first_unit_data("enemy")
		_config.enemies.append(spawn)
	_refresh_ui_from_config()


func _get_first_unit_scene() -> PackedScene:
	var list := _scan_tscn(UNITS_DIR)
	for f in list:
		if "Player" in f or "Enemy" in f:
			var path := UNITS_DIR.path_join(f)
			return load(path) as PackedScene
	if list.size() > 0:
		return load(UNITS_DIR.path_join(list[0])) as PackedScene
	return null


func _get_first_unit_data(team: String) -> UnitData:
	var dir_path := "res://data/units/"
	var dir := DirAccess.open(dir_path)
	if not dir:
		return null
	dir.list_dir_begin()
	var file := dir.get_next()
	while file != "":
		if file.ends_with(".tres"):
			var res: Resource = load(dir_path.path_join(file)) as Resource
			if res is UnitData:
				var ud := res as UnitData
				if team == "player" and ud.team == 0:
					dir.list_dir_end()
					return ud
				if team == "enemy" and ud.team == 1:
					dir.list_dir_end()
					return ud
		file = dir.get_next()
	dir.list_dir_end()
	return null


static func _scan_tscn(dir_path: String) -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(dir_path)
	if not dir:
		return out
	var files := dir.get_files()
	for f in files:
		if f.ends_with(".tscn"):
			out.append(f)
	return out


func _on_generate_preview_pressed() -> void:
	_ensure_config()
	_refresh_config_from_ui()
	var resolved := _EncounterGenerator.generate(_config)
	_alert("Generated: %d tiles, %d units. Use Bake to Scene to apply." % [resolved.tiles.size(), resolved.unit_spawns.size()])
	# Opcional: abrir BattleScene y asignar config temporal
	var root = _plugin.get_editor_interface().get_edited_scene_root() if _plugin else null
	if root and root.has_node("BattleBoard"):
		var board: Node = root.get_node("BattleBoard")
		var tiles_node: Node = board.get_node_or_null("Tiles")
		var units_node: Node = root.get_node_or_null("Units")
		if tiles_node and units_node:
			_on_clear_pressed()
			_EncounterGenerator.instantiate_in_scene(resolved, _config, tiles_node as Node3D, units_node as Node3D, root)
			_alert("Preview applied to scene. Save (Ctrl+S) or Clear Generated to revert.")


func _on_bake_pressed() -> void:
	_ensure_config()
	_refresh_config_from_ui()
	var root = _plugin.get_editor_interface().get_edited_scene_root() if _plugin else null
	if not root:
		_alert("Open BattleScene (or a scene with BattleBoard and Units) first.")
		return
	var board: Node = root.get_node_or_null("BattleBoard")
	if not board:
		_alert("Scene must have a BattleBoard node.")
		return
	var tiles_node: Node = board.get_node_or_null("Tiles")
	var units_node: Node = root.get_node_or_null("Units")
	if not tiles_node:
		_alert("BattleBoard must have a Tiles node.")
		return
	if not units_node:
		_alert("Scene must have a Units node (sibling of BattleBoard).")
		return

	var resolved := _EncounterGenerator.generate(_config)
	_last_bake_old_tiles.clear()
	_last_bake_old_units.clear()
	for child in tiles_node.get_children():
		if child.name.begins_with("Generated_"):
			_last_bake_old_tiles.append(child)
	for child in units_node.get_children():
		if child.name.begins_with("Generated_"):
			_last_bake_old_units.append(child)

	var undo: EditorUndoRedoManager = _plugin.get_undo_redo()
	undo.create_action("Bake Encounter")
	for node in _last_bake_old_tiles:
		undo.add_do_method(tiles_node, "remove_child", node)
		undo.add_do_reference(node)
		undo.add_undo_method(tiles_node, "add_child", node)
		undo.add_undo_property(node, "owner", root)
	for node in _last_bake_old_units:
		undo.add_do_method(units_node, "remove_child", node)
		undo.add_do_reference(node)
		undo.add_undo_method(units_node, "add_child", node)
		undo.add_undo_property(node, "owner", root)
	undo.add_do_method(_EncounterGenerator, "instantiate_in_scene", resolved, _config, tiles_node, units_node, root)
	undo.add_undo_method(self, "_undo_bake_clear", tiles_node, units_node)
	undo.commit_action()
	_alert("Baked %d tiles and %d units. Save scene (Ctrl+S)." % [resolved.tiles.size(), resolved.unit_spawns.size()])


func _undo_bake_clear(tiles_node: Node, units_node: Node) -> void:
	# Remover nodos creados por el bake (los Generated_ actuales)
	var to_remove: Array[Node] = []
	for child in tiles_node.get_children():
		if child.name.begins_with("Generated_"):
			to_remove.append(child)
	for child in units_node.get_children():
		if child.name.begins_with("Generated_"):
			to_remove.append(child)
	for node in to_remove:
		node.get_parent().remove_child(node)
		node.queue_free()
	# Los old_tiles/old_units se restauran via add_undo_method(add_child) del undo manager


func _on_use_for_test_pressed() -> void:
	_ensure_config()
	_refresh_config_from_ui()
	if _config_file_path.is_empty():
		_alert("Cargá o guardá el config primero. Luego usarás esta batalla al hacer Play.")
		return
	var cfg := ConfigFile.new()
	cfg.set_value("launcher", "config_path", _config_file_path)
	var err := cfg.save("res://.battle_test_config.cfg")
	if err == OK:
		_alert("Batalla de prueba establecida: %s. Al hacer Play, el menú usará esta config." % _config_file_path.get_file())
	else:
		_alert("Error al guardar: %s" % error_string(err))


func _on_clear_pressed() -> void:
	if not _plugin:
		return
	var root = _plugin.get_editor_interface().get_edited_scene_root()
	if not root:
		_alert("No scene open.")
		return
	var board: Node = root.get_node_or_null("BattleBoard")
	if not board:
		_alert("No BattleBoard in scene.")
		return
	var tiles_node: Node = board.get_node_or_null("Tiles")
	var units_node: Node = root.get_node_or_null("Units")
	if not tiles_node or not units_node:
		return

	var to_remove: Array[Node] = []
	for child in tiles_node.get_children():
		if child.name.begins_with("Generated_"):
			to_remove.append(child)
	for child in units_node.get_children():
		if child.name.begins_with("Generated_"):
			to_remove.append(child)

	if to_remove.is_empty():
		_alert("Nothing to clear.")
		return

	var undo: EditorUndoRedoManager = _plugin.get_undo_redo()
	undo.create_action("Clear Generated")
	for node in to_remove:
		var parent: Node = node.get_parent()
		undo.add_do_method(parent, "remove_child", node)
		undo.add_do_reference(node)
		undo.add_undo_method(parent, "add_child", node)
		undo.add_undo_property(node, "owner", root)
	undo.commit_action()
	_alert("Cleared %d generated nodes." % to_remove.size())


func _alert(msg: String) -> void:
	print("[Battle Encounter Builder] ", msg)
	OS.alert(msg, "Battle Encounter Builder")
