extends Node3D
##
## Jugador de la escena de exploración: solo se mueve entre hexágonos por clic.
## Siempre empieza y se desplaza al centro de un hex.
##

signal move_finished

const MOVE_DURATION := 0.4

var _current_hex: Vector2i = Vector2i(0, 0)
var _move_tween: Tween

func set_initial_hex(hex: Vector2i) -> void:
	_current_hex = hex
	global_position = HexGrid.hex_to_world(hex.x, hex.y, 0.0)

func get_current_hex() -> Vector2i:
	return _current_hex

func move_to_hex(hex: Vector2i) -> void:
	if _move_tween and _move_tween.is_valid() and _move_tween.is_running():
		return
	var target_pos: Vector3 = HexGrid.hex_to_world(hex.x, hex.y, 0.0)
	_current_hex = hex
	var dir: Vector3 = (target_pos - global_position).normalized()
	dir.y = 0.0
	if dir.length_squared() > 0.01:
		look_at(global_position + dir, Vector3.UP)
	_move_tween = create_tween()
	_move_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_move_tween.tween_property(self, "global_position", target_pos, MOVE_DURATION)
	_move_tween.tween_callback(_on_move_done)

func _on_move_done() -> void:
	emit_signal("move_finished")
