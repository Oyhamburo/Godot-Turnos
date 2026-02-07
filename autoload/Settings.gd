extends Node
##
## Settings autoload (singleton).
## Persists and applies window resolution + mode.
## Uses Godot 4 DisplayServer APIs (no legacy OS.window_*).
##
## Autoload name in Project Settings: "Settings"
##

const CONFIG_PATH := "user://settings.cfg"
const SECTION := "display"

const MODE_WINDOWED := "windowed"
const MODE_FULLSCREEN := "fullscreen"
const MODE_BORDERLESS := "borderless"

var resolution: Vector2i = Vector2i(1920, 1080)
var window_mode: String = MODE_WINDOWED

func _ready() -> void:
	# Load & apply on boot (works for desktop; on mobile, resolution/modes are limited).
	load_settings()
	apply_settings(resolution, window_mode)
	
func get_monitor_resolution() -> Vector2i:
	# Godot 4.x compatible: no depende de window_get_active_id().
	var screen := 0

	# Si existe, intentamos detectar en qué pantalla está la ventana principal (id 0).
	if DisplayServer.has_method("window_get_current_screen"):
		screen = DisplayServer.window_get_current_screen(0)

	var size := Vector2i(1920, 1080)
	if DisplayServer.has_method("screen_get_size"):
		size = DisplayServer.screen_get_size(screen)

	if size.x <= 0 or size.y <= 0:
		size = Vector2i(1920, 1080)

	return size


func apply_settings(new_resolution: Vector2i, new_window_mode: String) -> void:
	resolution = _sanitize_resolution(new_resolution)
	window_mode = _sanitize_mode(new_window_mode)

	# On mobile platforms, windowed/borderless don't really apply.
	# We still store the preference; applying will be a no-op where unsupported.
	var win_id := 0 # ventana principal


	# Always clear borderless first to avoid getting "stuck" in borderless.
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false, win_id)

	match window_mode:
		MODE_FULLSCREEN:
			# Fullscreen (non-exclusive) is the most portable.
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN, win_id)
		MODE_BORDERLESS:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED, win_id)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true, win_id)
			DisplayServer.window_set_size(resolution, win_id)
			_center_window_on_screen(win_id)
		_:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED, win_id)
			DisplayServer.window_set_size(resolution, win_id)
			_center_window_on_screen(win_id)

func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value(SECTION, "resolution_x", resolution.x)
	cfg.set_value(SECTION, "resolution_y", resolution.y)
	cfg.set_value(SECTION, "window_mode", window_mode)
	var err := cfg.save(CONFIG_PATH)
	if err != OK:
		push_warning("No se pudo guardar settings (%s). Error: %s" % [CONFIG_PATH, str(err)])

func load_settings() -> void:
	var cfg := ConfigFile.new()
	var err := cfg.load(CONFIG_PATH)

	if err != OK:
		# First run: default resolution = monitor size (or fallback).
		resolution = get_monitor_resolution()
		window_mode = MODE_WINDOWED
		return

	var rx := int(cfg.get_value(SECTION, "resolution_x", 0))
	var ry := int(cfg.get_value(SECTION, "resolution_y", 0))
	var mode := String(cfg.get_value(SECTION, "window_mode", MODE_WINDOWED))

	var loaded_res := Vector2i(rx, ry)
	if loaded_res.x <= 0 or loaded_res.y <= 0:
		loaded_res = get_monitor_resolution()

	resolution = _sanitize_resolution(loaded_res)
	window_mode = _sanitize_mode(mode)

func _sanitize_resolution(res: Vector2i) -> Vector2i:
	var r := res
	if r.x < 640: r.x = 640
	if r.y < 360: r.y = 360
	# Don't exceed current screen size in windowed/borderless (avoid off-screen windows).
	var screen := get_monitor_resolution()
	r.x = min(r.x, screen.x)
	r.y = min(r.y, screen.y)
	return r

func _sanitize_mode(mode: String) -> String:
	match mode:
		MODE_WINDOWED, MODE_FULLSCREEN, MODE_BORDERLESS:
			return mode
		_:
			return MODE_WINDOWED

func _center_window_on_screen(win_id: int) -> void:
	# Center the window on its current screen.
	if OS.has_feature("mobile"):
		return
	var screen := 0
	if DisplayServer.has_method("window_get_current_screen"):
		screen = DisplayServer.window_get_current_screen(win_id)
	var screen_pos := Vector2i.ZERO
	var screen_size := get_monitor_resolution()
	if DisplayServer.has_method("screen_get_position"):
		screen_pos = DisplayServer.screen_get_position(screen)
	var pos := screen_pos + (screen_size - resolution) / 2
	# Clamp to avoid negative
	pos.x = max(pos.x, screen_pos.x)
	pos.y = max(pos.y, screen_pos.y)
	DisplayServer.window_set_position(pos, win_id)
