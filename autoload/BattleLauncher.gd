extends Node
##
## Guarda qué batalla probar. MainMenu lee la ruta seleccionada; BattleFlow la usa si no hay config en la escena.
##

const _EncounterGenerator = preload("res://scripts/battle/tools/encounter_generator.gd")
const _BattleEncounterConfig = preload("res://scripts/battle/data/battle_encounter_config.gd")

const CONFIG_PATH_KEY := "user://battle_launcher_config_path.cfg"
const PROJECT_CONFIG_PATH := "res://.battle_test_config.cfg"
const CONFIG_KEY := "config_path"

var config_path: String = ""
var _explicit_path_this_session: bool = false

## Config inyectado directamente (modo RogueLike). Se consume al leerlo.
var rogue_config: BattleConfig = null

## Establece la ruta del .tres a probar (BattleConfig o BattleEncounterConfig).
func set_config_path(path: String) -> void:
	config_path = path
	_explicit_path_this_session = not path.is_empty()
	_save_path()


func _save_path() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("launcher", CONFIG_KEY, config_path)
	cfg.save(CONFIG_PATH_KEY)


func _load_path() -> void:
	# Primero: archivo en proyecto (lo escribe el plugin "Usar para probar")
	if FileAccess.file_exists(PROJECT_CONFIG_PATH):
		var project_cfg := ConfigFile.new()
		if project_cfg.load(PROJECT_CONFIG_PATH) == OK:
			config_path = project_cfg.get_value("launcher", CONFIG_KEY, "")
			return
	# Segundo: user:// (lo escribe MainMenu al seleccionar)
	var user_cfg := ConfigFile.new()
	if user_cfg.load(CONFIG_PATH_KEY) == OK:
		config_path = user_cfg.get_value("launcher", CONFIG_KEY, "")


## Devuelve BattleConfig para usar en BattleFlow. Carga desde config_path.
## Si es BattleEncounterConfig, genera y convierte a BattleConfig.
func get_battle_config() -> BattleConfig:
	# Prioridad: config rogue inyectado directamente (sin archivo)
	if rogue_config:
		var cfg := rogue_config
		rogue_config = null
		return cfg
	if not _explicit_path_this_session:
		_load_path()
	if config_path.is_empty():
		return null
	if not ResourceLoader.exists(config_path):
		return null
	var res: Resource = load(config_path) as Resource
	if res is BattleConfig:
		return res as BattleConfig
	if res is _BattleEncounterConfig:
		var resolved := _EncounterGenerator.generate(res)
		return _EncounterGenerator.to_battle_config(resolved, res)
	return null


func _ready() -> void:
	_load_path()
