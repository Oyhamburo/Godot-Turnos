extends VBoxContainer
class_name StatsPanel
##
## Panel de stats del personaje: HP / ATK / DEF / VEL / PESO.
## Se actualiza automáticamente cuando PlayerStats emite `changed`.
## También soporta preview de diffs al hacer hover sobre un ítem.
## Construido 100% por código.
##

const C_LABEL       := Color(0.82, 0.86, 0.95, 1.0)
const C_VALUE       := Color(1.00, 1.00, 1.00, 1.0)
const C_DIFF_POS    := Color(0.40, 0.90, 0.45, 1.0)  # verde
const C_DIFF_NEG    := Color(0.95, 0.35, 0.35, 1.0)  # rojo
const C_HEADER      := Color(0.65, 0.72, 0.92, 1.0)
const C_BG          := Color(0.08, 0.09, 0.15, 0.90)

const STAT_KEYS     := ["hp", "atk", "def", "speed", "weight"]
const STAT_LABELS   := ["❤ HP", "⚔ ATK", "🛡 DEF", "💨 VEL", "⚖ PESO"]

var _player_stats: PlayerStats = null
var _rows: Dictionary = {}   # key → {value_label, diff_label}


func _init() -> void:
	add_theme_constant_override("separation", 4)
	_build_ui()


func _build_ui() -> void:
	# Cabecera
	var header := Label.new()
	header.text = "ESTADÍSTICAS"
	header.add_theme_font_size_override("font_size", 11)
	header.add_theme_color_override("font_color", C_HEADER)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(header)

	# Separador
	var sep := HSeparator.new()
	add_child(sep)

	# Filas de stats
	for i in range(STAT_KEYS.size()):
		var key: String = STAT_KEYS[i]
		var label_txt: String = STAT_LABELS[i]

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		add_child(row)

		var name_lbl := Label.new()
		name_lbl.text = label_txt
		name_lbl.add_theme_font_size_override("font_size", 12)
		name_lbl.add_theme_color_override("font_color", C_LABEL)
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_lbl)

		var val_lbl := Label.new()
		val_lbl.text = "—"
		val_lbl.add_theme_font_size_override("font_size", 13)
		val_lbl.add_theme_color_override("font_color", C_VALUE)
		val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(val_lbl)

		var diff_lbl := Label.new()
		diff_lbl.text = ""
		diff_lbl.add_theme_font_size_override("font_size", 11)
		diff_lbl.add_theme_color_override("font_color", C_DIFF_POS)
		diff_lbl.custom_minimum_size.x = 36
		diff_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		diff_lbl.visible = false
		row.add_child(diff_lbl)

		_rows[key] = {"value": val_lbl, "diff": diff_lbl}


## Vincula los PlayerStats y comienza a escuchar cambios.
func setup(stats: PlayerStats) -> void:
	if _player_stats and _player_stats.changed.is_connected(_on_stats_changed):
		_player_stats.changed.disconnect(_on_stats_changed)
	_player_stats = stats
	if stats:
		stats.changed.connect(_on_stats_changed)
		_on_stats_changed()


## Actualiza las labels de valor.
func _on_stats_changed() -> void:
	if _player_stats == null:
		return
	for key in STAT_KEYS:
		var row: Dictionary = _rows.get(key, {})
		if row.is_empty():
			continue
		var val: int = _player_stats.final_stats.get(key, 0)
		(row["value"] as Label).text = str(val)
	clear_diff()


## Muestra diffs de preview al hovear un ítem (positivo=verde, negativo=rojo).
func show_diff(diff: Dictionary) -> void:
	for key in STAT_KEYS:
		var row: Dictionary = _rows.get(key, {})
		if row.is_empty():
			continue
		var diff_lbl: Label = row["diff"]
		if diff.has(key) and diff[key] != 0:
			var d: int = diff[key]
			diff_lbl.text = ("+" if d > 0 else "") + str(d)
			diff_lbl.add_theme_color_override(
				"font_color",
				C_DIFF_POS if d > 0 else C_DIFF_NEG
			)
			diff_lbl.visible = true
		else:
			diff_lbl.text = ""
			diff_lbl.visible = false


## Oculta todos los diffs.
func clear_diff() -> void:
	for key in STAT_KEYS:
		var row: Dictionary = _rows.get(key, {})
		if row.is_empty():
			continue
		var diff_lbl: Label = row["diff"]
		diff_lbl.text = ""
		diff_lbl.visible = false
