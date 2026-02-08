@tool
extends Control
##
## Control que dibuja una grilla hexagonal y emite (q, r) al hacer clic.
## Usa la misma relación axial que HexGrid, en píxeles.
##

signal hex_selected(q: int, r: int)

const CELL_SIZE := 44
const HEX_RANGE := 4

var _selected_hex: Vector2i = Vector2i(0, 0)
var _hover_hex: Vector2i = Vector2i(-999, -999)
var _occupied_hexes: Dictionary = {}

func _ready() -> void:
	clip_contents = true
	custom_minimum_size = Vector2(440, 620)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

func _draw() -> void:
	var cx: float = size.x / 2.0
	var cy: float = size.y / 2.0
	var sqrt3: float = sqrt(3.0)
	for q in range(-HEX_RANGE, HEX_RANGE + 1):
		for r in range(-HEX_RANGE, HEX_RANGE + 1):
			var center := _hex_to_pixel(q, r, cx, cy)
			var key := _key(q, r)
			var occupied: bool = _occupied_hexes.get(key, false)
			var col: Color
			if occupied:
				col = Color(0.75, 0.22, 0.22) if (q != _selected_hex.x or r != _selected_hex.y) else Color(0.6, 0.15, 0.15)
			elif q == _selected_hex.x and r == _selected_hex.y:
				col = Color(0.35, 0.55, 0.85)
			elif q == _hover_hex.x and r == _hover_hex.y:
				col = Color(0.28, 0.32, 0.38)
			else:
				col = Color(0.22, 0.24, 0.28)
			_draw_hex(center, col)
	for q in range(-HEX_RANGE, HEX_RANGE + 1):
		for r in range(-HEX_RANGE, HEX_RANGE + 1):
			var center := _hex_to_pixel(q, r, cx, cy)
			var label: String = "(%d,%d)" % [q, r] if (q == _selected_hex.x and r == _selected_hex.y) else "%d,%d" % [q, r]
			var fs: int = 14 if (q == _selected_hex.x and r == _selected_hex.y) else 13
			var tw: float = label.length() * 7.0
			draw_string(ThemeDB.fallback_font, center - Vector2(tw * 0.5, -5), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)

func _draw_hex(center: Vector2, color: Color) -> void:
	var points: PackedVector2Array = PackedVector2Array()
	for i in range(6):
		var angle: float = TAU / 6.0 * float(i)
		points.append(center + Vector2(cos(angle), sin(angle)) * float(CELL_SIZE - 2))
	draw_colored_polygon(points, color)
	draw_polyline(points, Color(0.15, 0.16, 0.18), 1.2)

func _hex_to_pixel(q: int, r: int, cx: float, cy: float) -> Vector2:
	var sqrt3: float = sqrt(3.0)
	var x: float = cx + CELL_SIZE * (sqrt3 * float(q) + sqrt3 / 2.0 * float(r))
	var y: float = cy + CELL_SIZE * (1.5 * float(r))
	return Vector2(x, y)

func _pixel_to_hex(px: float, py: float, cx: float, cy: float) -> Vector2i:
	var dx: float = px - cx
	var dy: float = py - cy
	var sqrt3: float = sqrt(3.0)
	var r_f: float = dy / (CELL_SIZE * 1.5)
	var q_f: float = (dx / (CELL_SIZE * sqrt3)) - (dy / (CELL_SIZE * 3.0))
	return _axial_round(q_f, r_f)

func _axial_round(q_f: float, r_f: float) -> Vector2i:
	var s_f: float = -q_f - r_f
	var qi: int = int(roundi(q_f))
	var ri: int = int(roundi(r_f))
	var si: int = int(roundi(s_f))
	var qd: float = absf(qi - q_f)
	var rd: float = absf(ri - r_f)
	var sd: float = absf(si - s_f)
	if qd > rd and qd > sd:
		qi = -ri - si
	elif rd > sd:
		ri = -qi - si
	return Vector2i(qi, ri)

func _key(q: int, r: int) -> String:
	return "%d,%d" % [q, r]

func _gui_input(event: InputEvent) -> void:
	var cx: float = size.x / 2.0
	var cy: float = size.y / 2.0
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			var h: Vector2i = _pixel_to_hex(mb.position.x, mb.position.y, cx, cy)
			if abs(h.x) <= HEX_RANGE and abs(h.y) <= HEX_RANGE:
				_selected_hex = h
				hex_selected.emit(h.x, h.y)
				queue_redraw()
	elif event is InputEventMouseMotion:
		var h: Vector2i = _pixel_to_hex(event.position.x, event.position.y, cx, cy)
		if abs(h.x) <= HEX_RANGE and abs(h.y) <= HEX_RANGE:
			_hover_hex = h
		else:
			_hover_hex = Vector2i(-999, -999)
		queue_redraw()

func set_selected(q: int, r: int) -> void:
	_selected_hex = Vector2i(q, r)
	queue_redraw()

func set_occupied_hexes(hexes: Array) -> void:
	_occupied_hexes.clear()
	for h in hexes:
		if h is Vector2i:
			_occupied_hexes[_key(h.x, h.y)] = true
		elif h is Vector2:
			_occupied_hexes[_key(int(h.x), int(h.y))] = true
	queue_redraw()
