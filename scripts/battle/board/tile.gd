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
var _is_range_highlighted: bool = false  # true cuando el tile está en rango de movimiento

@onready var floor_container: Node3D = $FloorContainer
@onready var area: Area3D = $Area3D
@onready var highlight_mesh: MeshInstance3D = $HighlightMesh

func _ready() -> void:
	# La selección se hace por raycast desde BattleFlow; el Area queda para hit detection.
	area.input_event.connect(_on_area_input_event)
	# Duplicar material del highlight para que cada tile tenga su propia instancia
	# (el SubResource de Tile.tscn es compartido entre todas las instancias).
	if highlight_mesh and highlight_mesh.material_override:
		highlight_mesh.material_override = highlight_mesh.material_override.duplicate()


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

	if mesh_instance and is_blocked:
		_apply_blocked_material(mesh_instance)


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


func set_highlighted(on: bool) -> void:
	_is_range_highlighted = on
	if highlight_mesh:
		highlight_mesh.visible = on
		# Elevar ligeramente para evitar z-fighting con el piso
		highlight_mesh.position.y = 0.02 if on else 0.0
		if on:
			var mat: StandardMaterial3D = highlight_mesh.material_override as StandardMaterial3D
			if mat:
				mat.albedo_color = Color(0.1, 1.0, 0.3, 0.55)
				mat.emission_enabled = true
				mat.emission = Color(0.1, 0.8, 0.3)
				mat.emission_energy_multiplier = 0.5
		else:
			var mat: StandardMaterial3D = highlight_mesh.material_override as StandardMaterial3D
			if mat:
				mat.emission_enabled = false


## Muestra hover sobre el tile. is_valid=true → verde (puede moverse), false → rojo (no puede).
## Funciona sobre CUALQUIER tile, no solo los que están en rango.
func set_hover_highlighted(on: bool, is_valid: bool = true) -> void:
	if not highlight_mesh:
		return
	var mat: StandardMaterial3D = highlight_mesh.material_override as StandardMaterial3D
	if not mat:
		return
	if on:
		highlight_mesh.visible = true
		highlight_mesh.position.y = 0.02
		if is_valid:
			# Verde brillante: puede moverse aquí
			mat.albedo_color = Color(0.2, 1.0, 0.4, 0.65)
			mat.emission_enabled = true
			mat.emission = Color(0.1, 0.9, 0.3)
			mat.emission_energy_multiplier = 0.7
		else:
			# Rojo: no puede moverse aquí
			mat.albedo_color = Color(1.0, 0.2, 0.2, 0.55)
			mat.emission_enabled = true
			mat.emission = Color(0.9, 0.1, 0.1)
			mat.emission_energy_multiplier = 0.5
	else:
		# Restaurar estado previo
		if _is_range_highlighted:
			# Volver al verde de rango base
			mat.albedo_color = Color(0.1, 1.0, 0.3, 0.55)
			mat.emission_enabled = true
			mat.emission = Color(0.1, 0.8, 0.3)
			mat.emission_energy_multiplier = 0.5
		else:
			# No estaba en rango: ocultar
			highlight_mesh.visible = false
			mat.emission_enabled = false


func _on_area_input_event(_camera: Node, event: InputEvent, _pos: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		tile_clicked.emit(self)


