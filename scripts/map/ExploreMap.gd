extends Node3D
##
## Escena de exploración por turnos con dado.
## - Cada turno: se tira un dado (D6) que determina cuántas casillas puede moverse el jugador.
## - Los hexes alcanzables se iluminan en verde; hover naranja fuera del rango.
## - Click en hex verde → el jugador camina paso a paso hasta el destino.
## - Al llegar, comienza el siguiente turno (nuevo dado).
##
## La cámara orbital es independiente del jugador (ExploreCameraRig),
## permite rotar con botón derecho del mouse y hacer zoom con la rueda.
##

const MAIN_MENU_SCENE := "res://scenes/MainMenu.tscn"
const THIRD_PERSON_SCENE := "res://scenes/third_person/ThirdPersonMap.tscn"
const BATTLE_SCENE := "res://scenes/battle/BattleScene.tscn"
const BATTLE_CONFIG_PATH := "res://data/battles/battle_explore_skeleton.tres"

## Hexes que actúan como puerta de entrada a la ciudad.
## Incluye (0,3) y (0,4) donde el usuario colocó los buildings de puerta.
const GATE_HEX  := Vector2i(0, 3)
const GATE_HEX2 := Vector2i(0, 4)
const GATE_EMISSION_COLOR := Color(0.9, 0.7, 0.1)
const GATE_ALBEDO_COLOR := Color(0.95, 0.8, 0.3, 1.0)

## Hex del edificio abandonado que dispara una batalla.
const BATTLE_HEX := Vector2i(-2, -2)
const BATTLE_EMISSION_COLOR := Color(0.9, 0.1, 0.1)
const BATTLE_ALBEDO_COLOR := Color(1.0, 0.25, 0.2, 1.0)

enum EstadoExploracion {
	ESPERANDO_DADO,   # Inicio de turno: mostrar botón de dado
	MOSTRANDO_RANGO,  # Dado tirado: hexes en rango iluminados, esperando clic
	MOVIENDO,         # Jugador en movimiento
}

@onready var default_map: Node3D = $DefaultMap
@onready var explore_player: Node = $ExplorePlayer
@onready var back_button: Button = $UI/BackButton
@onready var _camera_rig: ExploreCameraRig = $ExploreCameraRig

# Estado de exploración
var _estado: EstadoExploracion = EstadoExploracion.ESPERANDO_DADO
var _caras_dado: int = 6

# Hexes del mapa
var _valid_hexes: Array[Vector2i] = []
var _blocked_hexes: Array[Vector2i] = []
var _hexes_en_rango: Array[Vector2i] = []

# Nodos y materiales para highlight de hexes
var _hex_nodes: Dictionary = {}           # Vector2i → Node3D
var _hex_materiales: Dictionary = {}      # Vector2i → StandardMaterial3D
var _hex_albedo_originales: Dictionary = {} # Vector2i → Color

# Hover
var _hex_hover_actual: Vector2i = Vector2i(-999, -999)

# HUD
var _hud: ExploreHUD

# Diálogo de confirmación para transición de mapa
var _confirm_dialog: ConfirmDialogPanel = null


func _ready() -> void:
	_build_valid_hexes_from_tiles()
	_build_blocked_hexes_from_buildings()
	_build_hex_nodes()

	if _valid_hexes.is_empty():
		push_warning("ExploreMap: no hay hexes en DefaultMap/Tiles.")
	else:
		if explore_player.has_method("set_initial_hex"):
			var start_hex: Vector2i
			if Engine.has_meta("explore_return_hex"):
				# Volvemos de una batalla: restaurar posición
				start_hex = Engine.get_meta("explore_return_hex") as Vector2i
				Engine.remove_meta("explore_return_hex")
			elif Engine.has_meta("explore_spawn_at_gate") and Engine.get_meta("explore_spawn_at_gate"):
				# Venimos de la ciudad (ThirdPersonMap): spawnear en la puerta
				Engine.remove_meta("explore_spawn_at_gate")
				start_hex = GATE_HEX
			else:
				start_hex = _first_walkable_hex()
			explore_player.set_initial_hex(start_hex)
			if _camera_rig:
				_camera_rig.set_target(explore_player.global_position)

	if explore_player.has_signal("move_finished"):
		explore_player.move_finished.connect(_on_player_move_finished)
	if explore_player.has_signal("move_step_finished"):
		explore_player.move_step_finished.connect(_on_player_step_finished)

	if back_button:
		back_button.pressed.connect(_on_back_pressed)

	# Crear HUD del dado por código (CanvasLayer propio)
	_hud = ExploreHUD.new()
	add_child(_hud)
	_hud.dado_presionado.connect(_on_boton_dado_presionado)

	# Highlight dorado de los hexes puerta
	_highlight_gate_hex()
	_highlight_gate_hex2()

	# Highlight rojo del hex de batalla
	_highlight_battle_hex()

	_iniciar_turno()


# ── Construcción del mapa ──────────────────────────────────────────────────

func _build_valid_hexes_from_tiles() -> void:
	_valid_hexes.clear()
	var tiles: Node = default_map.get_node_or_null("Tiles")
	if tiles == null:
		return
	for child in tiles.get_children():
		var pos: Vector3 = child.global_position
		var hex: Vector2i = HexGrid.world_to_hex(pos.x, pos.z)
		child.global_position = HexGrid.hex_to_world(hex.x, hex.y, 0.0)
		var already: bool = false
		for h in _valid_hexes:
			if h.x == hex.x and h.y == hex.y:
				already = true
				break
		if not already:
			_valid_hexes.append(hex)


func _build_blocked_hexes_from_buildings() -> void:
	_blocked_hexes.clear()
	var buildings: Node = default_map.get_node_or_null("Buildings")
	if buildings == null:
		return
	for child in buildings.get_children():
		if child is Node3D:
			if child.has_method("trigger_event"):
				continue
			var hex: Vector2i = HexGrid.world_to_hex(child.global_position.x, child.global_position.z)
			var already: bool = false
			for h in _blocked_hexes:
				if h.x == hex.x and h.y == hex.y:
					already = true
					break
			if not already:
				_blocked_hexes.append(hex)


func _build_hex_nodes() -> void:
	_hex_nodes.clear()
	var tiles: Node = default_map.get_node_or_null("Tiles")
	if tiles == null:
		return
	for child in tiles.get_children():
		var hex: Vector2i = HexGrid.world_to_hex(child.global_position.x, child.global_position.z)
		_hex_nodes[hex] = child


func _first_walkable_hex() -> Vector2i:
	for h in _valid_hexes:
		if _is_valid_hex(h):
			return h
	return _valid_hexes[0]


# ── Sistema de turnos y dado ───────────────────────────────────────────────

func _iniciar_turno() -> void:
	_estado = EstadoExploracion.ESPERANDO_DADO
	if _hud:
		_hud.mostrar_boton_dado()


func _on_boton_dado_presionado() -> void:
	var resultado: int = randi_range(1, _caras_dado)
	if _hud:
		_hud.mostrar_resultado_dado(resultado)

	var current: Vector2i = explore_player.get_current_hex() if explore_player.has_method("get_current_hex") else Vector2i(0, 0)
	_hexes_en_rango = HexGrid.get_hexes_en_rango(current, resultado, _valid_hexes)

	# Filtrar hexes bloqueados
	var filtrados: Array[Vector2i] = []
	for h in _hexes_en_rango:
		if _is_valid_hex(h):
			filtrados.append(h)
	_hexes_en_rango = filtrados

	_mostrar_rango_alcanzable()
	_estado = EstadoExploracion.MOSTRANDO_RANGO


# ── Eventos del jugador ────────────────────────────────────────────────────

func _on_player_step_finished(hex: Vector2i) -> void:
	# La cámara sigue al jugador suavemente en cada paso
	if _camera_rig:
		var pos_mundo: Vector3 = HexGrid.hex_to_world(hex.x, hex.y, 0.0)
		_camera_rig.seguir_jugador_suave(pos_mundo, 0.3)


func _on_player_move_finished() -> void:
	var current_hex: Vector2i = explore_player.get_current_hex() if explore_player.has_method("get_current_hex") else Vector2i(0, 0)

	# Verificar si llegó a algún hex de la puerta de la ciudad
	var es_puerta := (current_hex.x == GATE_HEX.x and current_hex.y == GATE_HEX.y) \
				  or (current_hex.x == GATE_HEX2.x and current_hex.y == GATE_HEX2.y)
	if es_puerta:
		_mostrar_dialogo_ciudad()
		return

	# Verificar si llegó al hex de batalla
	if current_hex.x == BATTLE_HEX.x and current_hex.y == BATTLE_HEX.y:
		_mostrar_dialogo_batalla()
		return

	var building: Node = _get_building_at_hex(current_hex)
	if building and building.has_method("trigger_event"):
		building.trigger_event()
	_iniciar_turno()


# ── Input ──────────────────────────────────────────────────────────────────

func _input(event: InputEvent) -> void:
	if _estado == EstadoExploracion.MOVIENDO:
		return

	if event is InputEventMouseMotion and _estado == EstadoExploracion.MOSTRANDO_RANGO:
		_handle_hover(event.position)

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			if _estado == EstadoExploracion.MOSTRANDO_RANGO:
				_handle_click(mb.position)


func _handle_hover(screen_pos: Vector2) -> void:
	var hit: Variant = _raycast_plano_y0(screen_pos)
	if hit == null:
		if _hex_hover_actual != Vector2i(-999, -999):
			_restaurar_highlight_rango(_hex_hover_actual)
			_hex_hover_actual = Vector2i(-999, -999)
		return

	var hover_hex: Vector2i = HexGrid.world_to_hex((hit as Vector3).x, (hit as Vector3).z)
	if hover_hex == _hex_hover_actual:
		return

	# Restaurar anterior
	if _hex_hover_actual != Vector2i(-999, -999):
		_restaurar_highlight_rango(_hex_hover_actual)

	_hex_hover_actual = hover_hex

	if hover_hex in _hexes_en_rango:
		_preparar_material_hex(hover_hex)
		_aplicar_hover(hover_hex, true)
	elif _is_valid_hex(hover_hex):
		_preparar_material_hex(hover_hex)
		_aplicar_hover(hover_hex, false)


func _handle_click(screen_pos: Vector2) -> void:
	var hit: Variant = _raycast_plano_y0(screen_pos)
	if hit == null:
		return

	var click_hex: Vector2i = HexGrid.world_to_hex((hit as Vector3).x, (hit as Vector3).z)
	if not (click_hex in _hexes_en_rango):
		return

	_limpiar_rango()
	_hex_hover_actual = Vector2i(-999, -999)
	_estado = EstadoExploracion.MOVIENDO

	var current: Vector2i = explore_player.get_current_hex() if explore_player.has_method("get_current_hex") else Vector2i(0, 0)
	var camino: Array[Vector2i] = HexGrid.encontrar_camino(current, click_hex, _valid_hexes)
	if explore_player.has_method("move_along_path"):
		explore_player.move_along_path(camino)


func _raycast_plano_y0(screen_pos: Vector2) -> Variant:
	var cam: Camera3D = _camera_rig.get_camera() if _camera_rig else null
	if cam == null:
		return null
	var from: Vector3 = cam.project_ray_origin(screen_pos)
	var dir: Vector3 = cam.project_ray_normal(screen_pos)
	var plano := Plane(Vector3.UP, 0.0)
	return plano.intersects_ray(from, dir)


# ── Highlight de hexes ─────────────────────────────────────────────────────

func _preparar_material_hex(hex: Vector2i) -> void:
	if _hex_materiales.has(hex):
		return
	var nodo: Node3D = _hex_nodes.get(hex, null)
	if not nodo:
		return
	var mi: MeshInstance3D = _encontrar_mesh_instance(nodo)
	if not mi:
		return
	var mat: Material = mi.get_active_material(0)
	var dup: StandardMaterial3D
	if mat and mat is StandardMaterial3D:
		dup = mat.duplicate() as StandardMaterial3D
	else:
		dup = StandardMaterial3D.new()
		dup.albedo_color = Color(0.6, 0.8, 0.4, 1.0)
	mi.material_override = dup
	_hex_materiales[hex] = dup
	_hex_albedo_originales[hex] = dup.albedo_color


func _encontrar_mesh_instance(nodo: Node) -> MeshInstance3D:
	if nodo is MeshInstance3D:
		return nodo as MeshInstance3D
	for hijo in nodo.get_children():
		var encontrado: MeshInstance3D = _encontrar_mesh_instance(hijo)
		if encontrado:
			return encontrado
	return null


func _mostrar_rango_alcanzable() -> void:
	for hex in _hexes_en_rango:
		_preparar_material_hex(hex)
		var mat: StandardMaterial3D = _hex_materiales.get(hex, null)
		if mat:
			mat.emission_enabled = true
			mat.emission = Color(0.0, 0.9, 0.2)
			mat.emission_energy_multiplier = 1.8
			mat.albedo_color = Color(0.3, 1.0, 0.35, 1.0)


func _limpiar_rango() -> void:
	for hex in _hexes_en_rango:
		var mat: StandardMaterial3D = _hex_materiales.get(hex, null)
		if mat:
			if _es_hex_puerta(hex):
				mat.emission_enabled = true
				mat.emission = GATE_EMISSION_COLOR
				mat.emission_energy_multiplier = 1.5
				mat.albedo_color = GATE_ALBEDO_COLOR
			elif hex.x == BATTLE_HEX.x and hex.y == BATTLE_HEX.y:
				mat.emission_enabled = true
				mat.emission = BATTLE_EMISSION_COLOR
				mat.emission_energy_multiplier = 1.5
				mat.albedo_color = BATTLE_ALBEDO_COLOR
			else:
				mat.emission_enabled = false
				mat.emission_energy_multiplier = 0.0
				mat.albedo_color = _hex_albedo_originales.get(hex, Color.WHITE)
	_hexes_en_rango.clear()


func _aplicar_hover(hex: Vector2i, es_valido: bool) -> void:
	var mat: StandardMaterial3D = _hex_materiales.get(hex, null)
	if not mat:
		return
	if es_valido:
		mat.emission_enabled = true
		mat.emission = Color(0.1, 1.0, 0.35)
		mat.emission_energy_multiplier = 3.0
		mat.albedo_color = Color(0.3, 1.0, 0.5, 1.0)
	else:
		mat.emission_enabled = true
		mat.emission = Color(0.9, 0.4, 0.0)
		mat.emission_energy_multiplier = 2.0
		mat.albedo_color = Color(1.0, 0.5, 0.15, 1.0)


func _restaurar_highlight_rango(hex: Vector2i) -> void:
	var mat: StandardMaterial3D = _hex_materiales.get(hex, null)
	if not mat:
		return
	if hex in _hexes_en_rango:
		mat.emission_enabled = true
		mat.emission = Color(0.0, 0.9, 0.2)
		mat.emission_energy_multiplier = 1.8
		mat.albedo_color = Color(0.3, 1.0, 0.35, 1.0)
	elif _es_hex_puerta(hex):
		mat.emission_enabled = true
		mat.emission = GATE_EMISSION_COLOR
		mat.emission_energy_multiplier = 1.5
		mat.albedo_color = GATE_ALBEDO_COLOR
	elif hex.x == BATTLE_HEX.x and hex.y == BATTLE_HEX.y:
		mat.emission_enabled = true
		mat.emission = BATTLE_EMISSION_COLOR
		mat.emission_energy_multiplier = 1.5
		mat.albedo_color = BATTLE_ALBEDO_COLOR
	else:
		mat.emission_enabled = false
		mat.emission_energy_multiplier = 0.0
		mat.albedo_color = _hex_albedo_originales.get(hex, Color.WHITE)


# ── Utilidades ─────────────────────────────────────────────────────────────

func _is_valid_hex(hex: Vector2i) -> bool:
	for b in _blocked_hexes:
		if b.x == hex.x and b.y == hex.y:
			return false
	for v in _valid_hexes:
		if v.x == hex.x and v.y == hex.y:
			return true
	return false


func _get_building_at_hex(hex: Vector2i) -> Node:
	var buildings: Node = default_map.get_node_or_null("Buildings")
	if buildings == null:
		return null
	for child in buildings.get_children():
		if child is Node3D:
			var h: Vector2i = HexGrid.world_to_hex(child.global_position.x, child.global_position.z)
			if h.x == hex.x and h.y == hex.y:
				return child
	return null


## Devuelve true si el hex es uno de los hexes de puerta a la ciudad.
func _es_hex_puerta(hex: Vector2i) -> bool:
	return (hex.x == GATE_HEX.x  and hex.y == GATE_HEX.y) \
		or (hex.x == GATE_HEX2.x and hex.y == GATE_HEX2.y)


## Aplica emisión dorada permanente al hex puerta para distinguirlo visualmente.
func _highlight_gate_hex() -> void:
	_preparar_material_hex(GATE_HEX)
	var mat: StandardMaterial3D = _hex_materiales.get(GATE_HEX, null)
	if mat:
		mat.emission_enabled = true
		mat.emission = GATE_EMISSION_COLOR
		mat.emission_energy_multiplier = 1.5
		mat.albedo_color = GATE_ALBEDO_COLOR
		_hex_albedo_originales[GATE_HEX] = GATE_ALBEDO_COLOR


## Igual que _highlight_gate_hex() pero para el segundo hex de puerta (0,4).
func _highlight_gate_hex2() -> void:
	_preparar_material_hex(GATE_HEX2)
	var mat: StandardMaterial3D = _hex_materiales.get(GATE_HEX2, null)
	if mat:
		mat.emission_enabled = true
		mat.emission = GATE_EMISSION_COLOR
		mat.emission_energy_multiplier = 1.5
		mat.albedo_color = GATE_ALBEDO_COLOR
		_hex_albedo_originales[GATE_HEX2] = GATE_ALBEDO_COLOR


## Muestra diálogo de confirmación para entrar a la ciudad.
func _mostrar_dialogo_ciudad() -> void:
	if _confirm_dialog and is_instance_valid(_confirm_dialog):
		_confirm_dialog.queue_free()
		_confirm_dialog = null

	_confirm_dialog = ConfirmDialogPanel.new("Puerta de la Ciudad", "¿Querés entrar a la ciudad?")

	# Centrar en pantalla usando un CanvasLayer para que esté encima de todo
	var dialog_layer := CanvasLayer.new()
	dialog_layer.layer = 10
	add_child(dialog_layer)

	_confirm_dialog.anchor_left   = 0.5
	_confirm_dialog.anchor_top    = 0.5
	_confirm_dialog.anchor_right  = 0.5
	_confirm_dialog.anchor_bottom = 0.5
	_confirm_dialog.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_confirm_dialog.grow_vertical   = Control.GROW_DIRECTION_BOTH
	var pw: float = ConfirmDialogPanel.PANEL_SIZE.x
	var ph: float = ConfirmDialogPanel.PANEL_SIZE.y
	_confirm_dialog.offset_left   = -pw * 0.5
	_confirm_dialog.offset_right  =  pw * 0.5
	_confirm_dialog.offset_top    = -ph * 0.5
	_confirm_dialog.offset_bottom =  ph * 0.5

	_confirm_dialog.confirmado.connect(func() -> void:
		get_tree().change_scene_to_file(THIRD_PERSON_SCENE)
	)
	_confirm_dialog.cancelado.connect(func() -> void:
		if _confirm_dialog and is_instance_valid(_confirm_dialog):
			_confirm_dialog.queue_free()
			_confirm_dialog = null
		if dialog_layer and is_instance_valid(dialog_layer):
			dialog_layer.queue_free()
		_iniciar_turno()
	)

	dialog_layer.add_child(_confirm_dialog)


## Aplica emisión roja permanente al hex de batalla para distinguirlo visualmente.
func _highlight_battle_hex() -> void:
	_preparar_material_hex(BATTLE_HEX)
	var mat: StandardMaterial3D = _hex_materiales.get(BATTLE_HEX, null)
	if mat:
		mat.emission_enabled = true
		mat.emission = BATTLE_EMISSION_COLOR
		mat.emission_energy_multiplier = 1.5
		mat.albedo_color = BATTLE_ALBEDO_COLOR
		_hex_albedo_originales[BATTLE_HEX] = BATTLE_ALBEDO_COLOR


## Muestra diálogo de confirmación para iniciar la batalla.
func _mostrar_dialogo_batalla() -> void:
	if _confirm_dialog and is_instance_valid(_confirm_dialog):
		_confirm_dialog.queue_free()
		_confirm_dialog = null

	_confirm_dialog = ConfirmDialogPanel.new("Edificio Abandonado", "Hay presencia enemiga en las ruinas.\n¿Querés entrar a combatir?")

	var dialog_layer := CanvasLayer.new()
	dialog_layer.layer = 10
	add_child(dialog_layer)

	_confirm_dialog.anchor_left   = 0.5
	_confirm_dialog.anchor_top    = 0.5
	_confirm_dialog.anchor_right  = 0.5
	_confirm_dialog.anchor_bottom = 0.5
	_confirm_dialog.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_confirm_dialog.grow_vertical   = Control.GROW_DIRECTION_BOTH
	var pw: float = ConfirmDialogPanel.PANEL_SIZE.x
	var ph: float = ConfirmDialogPanel.PANEL_SIZE.y
	_confirm_dialog.offset_left   = -pw * 0.5
	_confirm_dialog.offset_right  =  pw * 0.5
	_confirm_dialog.offset_top    = -ph * 0.5
	_confirm_dialog.offset_bottom =  ph * 0.5

	_confirm_dialog.confirmado.connect(func() -> void:
		BattleLauncher.set_config_path(BATTLE_CONFIG_PATH)
		# Guardar esta escena como destino de retorno post-batalla
		GameManager.return_scene_after_battle = "res://scenes/ExploreMap.tscn"
		# Guardar la posición del jugador para restaurarla al volver
		if explore_player.has_method("get_current_hex"):
			Engine.set_meta("explore_return_hex", explore_player.get_current_hex())
		get_tree().change_scene_to_file(BATTLE_SCENE)
	)
	_confirm_dialog.cancelado.connect(func() -> void:
		if _confirm_dialog and is_instance_valid(_confirm_dialog):
			_confirm_dialog.queue_free()
			_confirm_dialog = null
		if dialog_layer and is_instance_valid(dialog_layer):
			dialog_layer.queue_free()
		_iniciar_turno()
	)

	dialog_layer.add_child(_confirm_dialog)


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)
