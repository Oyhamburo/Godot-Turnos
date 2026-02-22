extends Node3D
##
## Escena del mapa base en 3ra persona.
## Los hexes y edificios están colocados directamente en ThirdPersonMap.tscn.
## ESC vuelve al menú principal (solo si el inventario NO está abierto).
## I → abre PersonalInventoryPanel en pestaña "Items".
## P → abre PersonalInventoryPanel en pestaña "Personaje".
## Maneja la UI de interacción con edificios (hint + cartel con nombre).
##

const MAIN_MENU        := "res://scenes/MainMenu.tscn"
const EXPLORE_SCENE    := "res://scenes/ExploreMap.tscn"
const CARTEL_DURACION  := 3.0

@onready var back_button:   Button           = $UI/BackButton
@onready var interact_hint: Label            = $UI/InteractHint
@onready var nombre_label:  Label            = $UI/NombreEdificio
@onready var player:        CharacterBody3D  = $ThirdPersonPlayer
@onready var ui_layer:      CanvasLayer      = $UI

var _cartel_timer: float = 0.0

## Inventario persistente del jugador (compartido entre 3ra persona y batalla).
## Por ahora se crea local; en el futuro puede venir de un Autoload/GameManager.
var _player_inventory: Inventory = null
var _inv_panel: PersonalInventoryPanel = null
var _shop_panel: ShopPanel = null
var _herreria_panel: WeaponShopPanel = null
var _archery_panel: ArcheryShopPanel = null
var _confirm_dialog: ConfirmDialogPanel = null


func _ready() -> void:
	if back_button:
		back_button.pressed.connect(_on_back)

	if interact_hint:
		interact_hint.visible = false
	if nombre_label:
		nombre_label.visible = false

	# Usar el inventario global del GameManager
	_player_inventory = GameManager.player_inventory

	# Conectar signals del player
	if player:
		player.interact_hint_changed.connect(_on_interact_hint)
		player.edificio_interactuado.connect(_on_edificio_interactuado)

	# Conectar signals de edificios
	for edificio in get_tree().get_nodes_in_group("interactable"):
		if edificio is BuildingInteractable:
			edificio.mostrar_nombre.connect(_on_edificio_interactuado)


func _process(delta: float) -> void:
	if _cartel_timer > 0.0:
		_cartel_timer -= delta
		if _cartel_timer <= 0.0 and nombre_label:
			nombre_label.visible = false


func _unhandled_input(event: InputEvent) -> void:
	# Tecla I → pestaña Items
	if event.is_action_pressed("abrir_inventario"):
		_toggle_inventario(PersonalInventoryPanel.TAB_ITEMS)
		get_viewport().set_input_as_handled()
		return

	# Tecla P → pestaña Personaje
	if event.is_action_pressed("abrir_personaje"):
		_toggle_inventario(PersonalInventoryPanel.TAB_PERSONAJE)
		get_viewport().set_input_as_handled()
		return

	# Tecla O → abrir tienda (si hay Mercado cerca — por ahora directo al panel)
	if event.is_action_pressed("abrir_tienda"):
		_abrir_tienda()
		get_viewport().set_input_as_handled()
		return

	# ESC → volver al menú (solo si el inventario y diálogos están cerrados)
	if event.is_action_pressed("ui_cancel"):
		if _inv_panel and _inv_panel.visible:
			return  # el panel maneja su propio ESC
		if _confirm_dialog and is_instance_valid(_confirm_dialog):
			return  # el diálogo maneja su propio ESC
		_volver_al_menu()


# ──────────────────────────────────────────────────────────────
# PANEL DE INVENTARIO
# ──────────────────────────────────────────────────────────────

func _toggle_inventario(tab: int) -> void:
	if _inv_panel == null:
		_crear_inv_panel()

	if _inv_panel.visible and _inv_panel._tab_container.current_tab == tab:
		# Ya está abierto en esa pestaña → cerrar
		_cerrar_inventario()
	else:
		_abrir_inventario(tab)


func _abrir_inventario(tab: int) -> void:
	if _inv_panel == null:
		_crear_inv_panel()
	# Pausar el movimiento del player capturando el ratón
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_inv_panel.open_at_tab(tab)


func _cerrar_inventario() -> void:
	if _inv_panel:
		_inv_panel.visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _crear_inv_panel() -> void:
	_inv_panel = PersonalInventoryPanel.new()

	# Centrar en la pantalla
	_inv_panel.anchor_left   = 0.5
	_inv_panel.anchor_top    = 0.5
	_inv_panel.anchor_right  = 0.5
	_inv_panel.anchor_bottom = 0.5
	_inv_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_inv_panel.grow_vertical   = Control.GROW_DIRECTION_BOTH
	var panel_w: float = PersonalInventoryPanel.PANEL_SIZE.x
	var panel_h: float = PersonalInventoryPanel.PANEL_SIZE.y
	_inv_panel.offset_left   = -panel_w * 0.5
	_inv_panel.offset_right  =  panel_w * 0.5
	_inv_panel.offset_top    = -panel_h * 0.5
	_inv_panel.offset_bottom =  panel_h * 0.5

	_inv_panel.panel_closed.connect(_cerrar_inventario)
	ui_layer.add_child(_inv_panel)

	_inv_panel.setup(_player_inventory)
	_inv_panel.visible = false


# ──────────────────────────────────────────────────────────────
# TIENDA (ShopPanel)
# ──────────────────────────────────────────────────────────────

func _abrir_tienda() -> void:
	if _shop_panel == null:
		_shop_panel = ShopPanel.new()
		# Centrar en pantalla
		_shop_panel.anchor_left   = 0.5
		_shop_panel.anchor_top    = 0.5
		_shop_panel.anchor_right  = 0.5
		_shop_panel.anchor_bottom = 0.5
		_shop_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
		_shop_panel.grow_vertical   = Control.GROW_DIRECTION_BOTH
		var pw: float = ShopPanel.PANEL_SIZE.x
		var ph: float = ShopPanel.PANEL_SIZE.y
		_shop_panel.offset_left   = -pw * 0.5
		_shop_panel.offset_right  =  pw * 0.5
		_shop_panel.offset_top    = -ph * 0.5
		_shop_panel.offset_bottom =  ph * 0.5
		_shop_panel.panel_closed.connect(func() -> void:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		)
		ui_layer.add_child(_shop_panel)
		_shop_panel.setup(_player_inventory)

	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_shop_panel.visible = true


# ──────────────────────────────────────────────────────────────
# HERRERÍA
# ──────────────────────────────────────────────────────────────

func _abrir_herreria() -> void:
	if _herreria_panel == null:
		_herreria_panel = WeaponShopPanel.new()
		var pw: float = WeaponShopPanel.PANEL_SIZE.x
		var ph: float = WeaponShopPanel.PANEL_SIZE.y
		_herreria_panel.anchor_left   = 0.5
		_herreria_panel.anchor_top    = 0.5
		_herreria_panel.anchor_right  = 0.5
		_herreria_panel.anchor_bottom = 0.5
		_herreria_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
		_herreria_panel.grow_vertical   = Control.GROW_DIRECTION_BOTH
		_herreria_panel.offset_left   = -pw * 0.5
		_herreria_panel.offset_right  =  pw * 0.5
		_herreria_panel.offset_top    = -ph * 0.5
		_herreria_panel.offset_bottom =  ph * 0.5
		_herreria_panel.panel_closed.connect(func() -> void:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		)
		ui_layer.add_child(_herreria_panel)
		_herreria_panel.setup(_player_inventory)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_herreria_panel.visible = true


# ──────────────────────────────────────────────────────────────
# ARQUERÍA (Campo de Tiro)
# ──────────────────────────────────────────────────────────────

func _abrir_arqueria() -> void:
	if _archery_panel == null:
		_archery_panel = ArcheryShopPanel.new()
		var pw: float = ArcheryShopPanel.PANEL_SIZE.x
		var ph: float = ArcheryShopPanel.PANEL_SIZE.y
		_archery_panel.anchor_left   = 0.5
		_archery_panel.anchor_top    = 0.5
		_archery_panel.anchor_right  = 0.5
		_archery_panel.anchor_bottom = 0.5
		_archery_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
		_archery_panel.grow_vertical   = Control.GROW_DIRECTION_BOTH
		_archery_panel.offset_left   = -pw * 0.5
		_archery_panel.offset_right  =  pw * 0.5
		_archery_panel.offset_top    = -ph * 0.5
		_archery_panel.offset_bottom =  ph * 0.5
		_archery_panel.panel_closed.connect(func() -> void:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		)
		ui_layer.add_child(_archery_panel)
		_archery_panel.setup(_player_inventory)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_archery_panel.visible = true


# ──────────────────────────────────────────────────────────────
# SEÑALES DE EDIFICIOS
# ──────────────────────────────────────────────────────────────

func _on_interact_hint(mostrar: bool, nombre: String) -> void:
	if interact_hint:
		interact_hint.visible = mostrar
		if mostrar:
			interact_hint.text = "Presiona E — %s" % nombre


func _on_edificio_interactuado(nombre: String) -> void:
	if nombre_label:
		nombre_label.text = nombre
		nombre_label.visible = true
		_cartel_timer = CARTEL_DURACION
	if interact_hint:
		interact_hint.visible = false

	# Routing por nombre del edificio
	var nombre_lower: String = nombre.to_lower()
	if nombre_lower.contains("herrer"):
		_abrir_herreria()
		return
	if nombre_lower.contains("tiro") or nombre_lower.contains("arquer"):
		_abrir_arqueria()
		return
	if nombre_lower.contains("puerta"):
		_confirmar_transicion("Puerta de la Ciudad", "¿Querés salir a explorar?", EXPLORE_SCENE)
		return
	if nombre_lower.contains("mercado"):
		_abrir_tienda()


# ──────────────────────────────────────────────────────────────
# DIÁLOGO DE CONFIRMACIÓN (transición entre mapas)
# ──────────────────────────────────────────────────────────────

func _confirmar_transicion(titulo: String, mensaje: String, escena_destino: String) -> void:
	if _confirm_dialog and is_instance_valid(_confirm_dialog):
		_confirm_dialog.queue_free()
		_confirm_dialog = null

	_confirm_dialog = ConfirmDialogPanel.new(titulo, mensaje)

	# Centrar en pantalla
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

	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	_confirm_dialog.confirmado.connect(func() -> void:
		# Si vamos al mapa de exploración, indicar que el spawn debe ser en la puerta
		if escena_destino == EXPLORE_SCENE:
			Engine.set_meta("explore_spawn_at_gate", true)
		get_tree().change_scene_to_file(escena_destino)
	)
	_confirm_dialog.cancelado.connect(func() -> void:
		if _confirm_dialog and is_instance_valid(_confirm_dialog):
			_confirm_dialog.queue_free()
			_confirm_dialog = null
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	)

	ui_layer.add_child(_confirm_dialog)


# ──────────────────────────────────────────────────────────────
# NAVEGACIÓN
# ──────────────────────────────────────────────────────────────

func _on_back() -> void:
	_volver_al_menu()


func _volver_al_menu() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().change_scene_to_file(MAIN_MENU)
