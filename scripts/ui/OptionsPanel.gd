extends Control

@onready var resolution_opt: OptionButton = %ResolutionOption
@onready var mode_opt: OptionButton = %ModeOption
@onready var apply_btn: Button = %ApplyButton
@onready var back_btn: Button = %BackButton
@onready var mobile_note: Label = %MobileNote

var _resolutions: Array[Vector2i] = []

func _ready() -> void:
	apply_btn.pressed.connect(_on_apply)
	back_btn.pressed.connect(_on_back)

	_build_resolution_list()
	_build_mode_list()

	open()

func open() -> void:
	# Refresh UI from current Settings
	mobile_note.visible = OS.has_feature("mobile")

	_select_resolution(Settings.resolution)
	_select_mode(Settings.window_mode)

	# On mobile, modes/resolutions are limited and often ignored.
	mode_opt.disabled = OS.has_feature("mobile")
	resolution_opt.disabled = OS.has_feature("mobile")

func _build_resolution_list() -> void:
	_resolutions.clear()
	resolution_opt.clear()

	var monitor := Settings.get_monitor_resolution()
	var defaults := [
		Vector2i(1280, 720),
		Vector2i(1600, 900),
		Vector2i(1920, 1080),
		Vector2i(2560, 1440),
	]

	# Ensure monitor res is first, then add common ones unique.
	_add_resolution_unique(monitor)
	for r in defaults:
		_add_resolution_unique(r)

	# Also ensure current setting exists
	_add_resolution_unique(Settings.resolution)

	for r in _resolutions:
		var label := "%d x %d" % [r.x, r.y]
		resolution_opt.add_item(label)
		resolution_opt.set_item_metadata(resolution_opt.item_count - 1, r)

func _add_resolution_unique(r: Vector2i) -> void:
	if r.x <= 0 or r.y <= 0:
		return
	for existing in _resolutions:
		if existing == r:
			return
	_resolutions.append(r)

func _build_mode_list() -> void:
	mode_opt.clear()
	mode_opt.add_item("Ventana")
	mode_opt.set_item_metadata(0, Settings.MODE_WINDOWED)
	mode_opt.add_item("Pantalla completa")
	mode_opt.set_item_metadata(1, Settings.MODE_FULLSCREEN)
	mode_opt.add_item("Ventana sin bordes")
	mode_opt.set_item_metadata(2, Settings.MODE_BORDERLESS)

func _select_resolution(target: Vector2i) -> void:
	for i in range(resolution_opt.item_count):
		var r: Vector2i = resolution_opt.get_item_metadata(i)
		if r == target:
			resolution_opt.select(i)
			return
	# Fallback: select first
	if resolution_opt.item_count > 0:
		resolution_opt.select(0)

func _select_mode(mode: String) -> void:
	for i in range(mode_opt.item_count):
		var m: String = mode_opt.get_item_metadata(i)
		if m == mode:
			mode_opt.select(i)
			return
	mode_opt.select(0)

func _get_selected_resolution() -> Vector2i:
	var idx: int = resolution_opt.selected
	if idx < 0:
		return Settings.get_monitor_resolution()

	var meta: Variant = resolution_opt.get_item_metadata(idx)
	if meta is Vector2i:
		return meta as Vector2i

	return Settings.get_monitor_resolution()

func _get_selected_mode() -> String:
	var idx: int = mode_opt.selected
	if idx < 0:
		return Settings.MODE_WINDOWED

	var meta: Variant = mode_opt.get_item_metadata(idx)
	return String(meta)


func _on_apply() -> void:
	var res := _get_selected_resolution()
	var mode := _get_selected_mode()

	Settings.apply_settings(res, mode)
	Settings.save_settings()

	visible = false

func _on_back() -> void:
	visible = false
