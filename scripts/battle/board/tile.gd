extends Node3D
class_name Tile
##
## Representa una celda del tablero: coordenadas, estado caminable, ocupación y visual.
##

signal tile_clicked(tile: Tile)

var coords: Vector2i = Vector2i.ZERO
var walkable: bool = true
var occupied_by: Node = null
var world_position: Vector3 = Vector3.ZERO
var _is_range_highlighted: bool = false          # true cuando el tile está en rango de movimiento
var _is_blocked_range_highlighted: bool = false  # true cuando es walkable pero fuera de rango
var _is_attack_range_highlighted: bool = false   # true cuando el tile está en rango de ataque (naranja)
var _is_aoe_preview_highlighted: bool = false    # true cuando el tile está en la zona AoE (púrpura)

# Referencia al MeshInstance3D del piso (guardada en setup_floor para highlight directo)
var _floor_mesh: MeshInstance3D = null
# Albedo original del piso (para restaurar tras quitar highlight)
var _floor_albedo_original: Color = Color(1.0, 1.0, 1.0, 1.0)

# Cursor de hover (cubito animado que sube y baja sobre el tile)
var _cursor_indicator: MeshInstance3D = null
var _cursor_tween: Tween = null

@onready var floor_container: Node3D = $FloorContainer
@onready var area: Area3D = $Area3D
@onready var highlight_mesh: MeshInstance3D = $HighlightMesh


func _ready() -> void:
	# La selección se hace por raycast desde BattleFlow; el Area queda para hit detection.
	area.input_event.connect(_on_area_input_event)
	# Duplicar material del highlight overlay (queda inactivo; se mantiene por compatibilidad con la escena .tscn)
	if highlight_mesh and highlight_mesh.material_override:
		highlight_mesh.material_override = highlight_mesh.material_override.duplicate()
	# Asegurarse de que el HighlightMesh esté oculto: el highlight ahora va directo sobre el piso
	if highlight_mesh:
		highlight_mesh.visible = false


## Configura el visual del piso. floor_scene: escena a instanciar; si null, usa fallback PlaneMesh.
## is_blocked: si true, aplica material oscuro/rojo al mesh.
## tile_size: tamaño del tile en unidades (para escalar el mesh).
func setup_floor(floor_scene: PackedScene, is_blocked: bool, tile_size: float = 2.0) -> void:
	walkable = not is_blocked
	if floor_container.get_child_count() > 0:
		for c in floor_container.get_children():
			c.queue_free()

	var mesh_instance: MeshInstance3D = null
	if floor_scene:
		var inst: Node = floor_scene.instantiate()
		floor_container.add_child(inst)
		# Buscar MeshInstance3D en la instancia (puede ser nodo raíz o hijo)
		mesh_instance = _find_mesh_instance(inst)
	else:
		# Fallback: PlaneMesh
		mesh_instance = MeshInstance3D.new()
		var plane: PlaneMesh = PlaneMesh.new()
		plane.size = Vector2(tile_size * 0.95, tile_size * 0.95)
		mesh_instance.mesh = plane
		floor_container.add_child(mesh_instance)

	# Escalar floor para que coincida con tile_size (asumimos assets base ~4 unidades)
	if floor_scene:
		var base_size: float = 4.0
		floor_container.scale = Vector3(tile_size / base_size, 1.0, tile_size / base_size)

	# Guardar referencia al mesh del piso para aplicar highlight directamente sobre él
	_floor_mesh = mesh_instance

	if mesh_instance and is_blocked:
		_apply_blocked_material(mesh_instance)

	# Duplicar material por instancia e inicializar color base
	_init_floor_material()


## Duplica el material del piso por instancia para que los cambios de color/emisión
## no afecten a otros tiles (Godot comparte sub-resources entre instancias de la misma escena).
func _init_floor_material() -> void:
	if not _floor_mesh:
		return
	# Intentar obtener el material activo (surface 0)
	var mat: Material = _floor_mesh.get_active_material(0)
	if mat and mat is StandardMaterial3D:
		var dup: StandardMaterial3D = mat.duplicate() as StandardMaterial3D
		_floor_mesh.material_override = dup
		_floor_albedo_original = dup.albedo_color
	elif _floor_mesh.material_override and _floor_mesh.material_override is StandardMaterial3D:
		var dup: StandardMaterial3D = _floor_mesh.material_override.duplicate() as StandardMaterial3D
		_floor_mesh.material_override = dup
		_floor_albedo_original = dup.albedo_color
	else:
		# Sin material: crear uno neutro
		var dup := StandardMaterial3D.new()
		dup.albedo_color = Color(0.72, 0.72, 0.72, 1.0)
		_floor_mesh.material_override = dup
		_floor_albedo_original = dup.albedo_color


func _find_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node as MeshInstance3D
	for c in node.get_children():
		var found := _find_mesh_instance(c)
		if found:
			return found
	return null


func _apply_blocked_material(mi: MeshInstance3D) -> void:
	var mat: StandardMaterial3D
	if mi.material_override and mi.material_override is StandardMaterial3D:
		mat = mi.material_override.duplicate() as StandardMaterial3D
	else:
		mat = StandardMaterial3D.new()
		mat.albedo_color = Color(0.4, 0.2, 0.2, 1)
	mat.albedo_color = Color(0.5, 0.2, 0.2, 1)
	mi.material_override = mat


## Resalta el tile en verde (tiles alcanzables en modo mover).
## Aplica emisión directamente sobre el material del mesh del piso.
func set_highlighted(on: bool) -> void:
	_is_range_highlighted = on
	if not _floor_mesh:
		return
	var mat: StandardMaterial3D = _floor_mesh.material_override as StandardMaterial3D
	if not mat:
		return
	if on:
		mat.emission_enabled = true
		mat.emission = Color(0.0, 0.9, 0.2)
		mat.emission_energy_multiplier = 2.2
		mat.albedo_color = Color(0.3, 1.0, 0.35, 1.0)
	else:
		mat.emission_enabled = false
		mat.emission_energy_multiplier = 0.0
		mat.albedo_color = _floor_albedo_original


## Resalta el tile en rojo tenue (tiles walkables fuera del rango de movimiento).
func set_blocked_range_highlight(on: bool) -> void:
	_is_blocked_range_highlighted = on
	if not _floor_mesh:
		return
	var mat: StandardMaterial3D = _floor_mesh.material_override as StandardMaterial3D
	if not mat:
		return
	if on:
		mat.emission_enabled = true
		mat.emission = Color(0.8, 0.05, 0.05)
		mat.emission_energy_multiplier = 1.0
		mat.albedo_color = Color(1.0, 0.3, 0.3, 1.0)
	else:
		if not _is_range_highlighted:
			mat.emission_enabled = false
			mat.emission_energy_multiplier = 0.0
			mat.albedo_color = _floor_albedo_original


## Resalta el tile en naranja (tiles dentro del rango de un ataque seleccionado).
func set_attack_range_highlight(on: bool) -> void:
	_is_attack_range_highlighted = on
	if not _floor_mesh:
		return
	var mat: StandardMaterial3D = _floor_mesh.material_override as StandardMaterial3D
	if not mat:
		return
	if on:
		mat.emission_enabled = true
		mat.emission = Color(0.9, 0.45, 0.0)
		mat.emission_energy_multiplier = 1.8
		mat.albedo_color = Color(1.0, 0.55, 0.1, 1.0)
	else:
		if not _is_range_highlighted and not _is_blocked_range_highlighted:
			mat.emission_enabled = false
			mat.emission_energy_multiplier = 0.0
			mat.albedo_color = _floor_albedo_original


## Resalta el tile en púrpura (preview de zona AoE del ataque).
func set_aoe_preview_highlight(on: bool) -> void:
	_is_aoe_preview_highlighted = on
	if not _floor_mesh:
		return
	var mat: StandardMaterial3D = _floor_mesh.material_override as StandardMaterial3D
	if not mat:
		return
	if on:
		mat.emission_enabled = true
		mat.emission = Color(0.8, 0.2, 0.9)
		mat.emission_energy_multiplier = 2.5
		mat.albedo_color = Color(0.85, 0.35, 1.0, 1.0)
	else:
		# Restaurar al highlight que había debajo (naranja de rango, etc.)
		if _is_attack_range_highlighted:
			mat.emission_enabled = true
			mat.emission = Color(0.9, 0.45, 0.0)
			mat.emission_energy_multiplier = 1.8
			mat.albedo_color = Color(1.0, 0.55, 0.1, 1.0)
		elif _is_range_highlighted:
			mat.emission_enabled = true
			mat.emission = Color(0.0, 0.9, 0.2)
			mat.emission_energy_multiplier = 2.2
			mat.albedo_color = Color(0.3, 1.0, 0.35, 1.0)
		elif _is_blocked_range_highlighted:
			mat.emission_enabled = true
			mat.emission = Color(0.8, 0.05, 0.05)
			mat.emission_energy_multiplier = 1.0
			mat.albedo_color = Color(1.0, 0.3, 0.3, 1.0)
		else:
			mat.emission_enabled = false
			mat.emission_energy_multiplier = 0.0
			mat.albedo_color = _floor_albedo_original


## Muestra hover sobre el tile. is_valid=true → verde (puede moverse), false → naranja (fuera de rango).
## Funciona sobre CUALQUIER tile, no solo los que están en rango.
func set_hover_highlighted(on: bool, is_valid: bool = true) -> void:
	if not _floor_mesh:
		return
	var mat: StandardMaterial3D = _floor_mesh.material_override as StandardMaterial3D
	if not mat:
		return
	if on:
		if is_valid:
			# Verde muy brillante: puede moverse aquí
			mat.emission_enabled = true
			mat.emission = Color(0.1, 1.0, 0.35)
			mat.emission_energy_multiplier = 3.0
			mat.albedo_color = Color(0.3, 1.0, 0.5, 1.0)
		else:
			# Naranja: no puede moverse aquí (fuera de rango)
			mat.emission_enabled = true
			mat.emission = Color(0.9, 0.4, 0.0)
			mat.emission_energy_multiplier = 2.0
			mat.albedo_color = Color(1.0, 0.5, 0.15, 1.0)
		_start_cursor_bob(is_valid)
	else:
		_stop_cursor_bob()
		# Restaurar estado previo del piso
		if _is_aoe_preview_highlighted:
			mat.emission_enabled = true
			mat.emission = Color(0.8, 0.2, 0.9)
			mat.emission_energy_multiplier = 2.5
			mat.albedo_color = Color(0.85, 0.35, 1.0, 1.0)
		elif _is_range_highlighted:
			mat.emission_enabled = true
			mat.emission = Color(0.0, 0.9, 0.2)
			mat.emission_energy_multiplier = 2.2
			mat.albedo_color = Color(0.3, 1.0, 0.35, 1.0)
		elif _is_blocked_range_highlighted:
			mat.emission_enabled = true
			mat.emission = Color(0.8, 0.05, 0.05)
			mat.emission_energy_multiplier = 1.0
			mat.albedo_color = Color(1.0, 0.3, 0.3, 1.0)
		elif _is_attack_range_highlighted:
			mat.emission_enabled = true
			mat.emission = Color(0.9, 0.45, 0.0)
			mat.emission_energy_multiplier = 1.8
			mat.albedo_color = Color(1.0, 0.55, 0.1, 1.0)
		else:
			mat.emission_enabled = false
			mat.emission_energy_multiplier = 0.0
			mat.albedo_color = _floor_albedo_original


## Inicia la animación de cursor bobbing (cubito que sube y baja) sobre el tile.
func _start_cursor_bob(is_valid: bool) -> void:
	if not _cursor_indicator:
		_cursor_indicator = MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.25, 0.18, 0.25)
		_cursor_indicator.mesh = box
		var cmat := StandardMaterial3D.new()
		cmat.albedo_color = Color(1.0, 1.0, 1.0, 0.9)
		cmat.emission_enabled = true
		cmat.emission_energy_multiplier = 2.0
		_cursor_indicator.material_override = cmat
		add_child(_cursor_indicator)

	var cmat: StandardMaterial3D = _cursor_indicator.material_override as StandardMaterial3D
	if cmat:
		if is_valid:
			cmat.emission = Color(1.0, 1.0, 0.8)
			cmat.albedo_color = Color(1.0, 1.0, 1.0, 0.9)
		else:
			cmat.emission = Color(1.0, 0.5, 0.1)
			cmat.albedo_color = Color(1.0, 0.65, 0.2, 0.9)

	_cursor_indicator.visible = true
	_cursor_indicator.position = Vector3(0, 0.35, 0)
	if _cursor_tween:
		_cursor_tween.kill()
	_cursor_tween = create_tween().set_loops()
	_cursor_tween.tween_property(_cursor_indicator, "position:y", 0.55, 0.4).set_trans(Tween.TRANS_SINE)
	_cursor_tween.tween_property(_cursor_indicator, "position:y", 0.35, 0.4).set_trans(Tween.TRANS_SINE)


## Detiene la animación de cursor bobbing y oculta el indicador.
func _stop_cursor_bob() -> void:
	if _cursor_tween:
		_cursor_tween.kill()
		_cursor_tween = null
	if _cursor_indicator:
		_cursor_indicator.visible = false


func _on_area_input_event(_camera: Node, event: InputEvent, _pos: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		tile_clicked.emit(self)
