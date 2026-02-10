extends Node3D
class_name FloatingHUD
##
## HUD flotante 3D: barra HP + nombre. 100% 3D (QuadMesh + Label3D).
## Conectado a UnitStats.hp_changed.
##

@onready var billboard_root: Node3D = $BillboardRoot
@onready var hp_back: MeshInstance3D = $BillboardRoot/HP_Back
@onready var hp_fill: MeshInstance3D = $BillboardRoot/HP_Fill
@onready var name_label: Label3D = $BillboardRoot/Name

var _stats: UnitStats

const _BAR_WIDTH := 1.0
const _BAR_HALF := 0.5


func setup(stats: UnitStats) -> void:
	_stats = stats
	if not _stats:
		print("[FloatingHUD] setup: stats es null!")
		return
	_stats.hp_changed.connect(_on_hp_changed)
	_refresh_hp()
	_set_name_from_parent()
	print("[FloatingHUD] setup OK - %s HP: %d/%d - global_pos: %s - visible: %s" % [name_label.text, _stats.hp, _stats.max_hp, global_position, visible])


func _set_name_from_parent() -> void:
	if not name_label:
		return
	var p: Node = get_parent()
	if p == null:
		name_label.text = "Unit"
		return
	if "display_name" in p:
		name_label.text = str(p.get("display_name"))
	else:
		name_label.text = p.name


func _refresh_hp() -> void:
	if _stats:
		_on_hp_changed(_stats.hp, _stats.max_hp)


func _on_hp_changed(current: int, max_val: int) -> void:
	if not hp_fill:
		return
	var ratio: float = 1.0
	if max_val > 0:
		ratio = clampf(float(current) / float(max_val), 0.0, 1.0)
	hp_fill.scale.x = ratio
	hp_fill.position.x = -_BAR_HALF * (1.0 - ratio)
	print("[FloatingHUD] _on_hp_changed: %d/%d (%.0f%%)" % [current, max_val, ratio * 100.0])


## Billboard manual desactivado: los materiales ahora usan billboard_mode = 1
#func _process(_delta: float) -> void:
#	if not billboard_root or not is_inside_tree():
#		return
#	var cam: Camera3D = get_viewport().get_camera_3d()
#	if not cam:
#		return
#	var pos := global_position
#	var cam_pos := cam.global_position
#	var dir := Vector3(cam_pos.x - pos.x, 0.0, cam_pos.z - pos.z)
#	if dir.length_squared() < 0.0001:
#		return
#	billboard_root.look_at(pos + dir.normalized(), Vector3.UP)
