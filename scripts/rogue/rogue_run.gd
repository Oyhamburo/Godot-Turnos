extends Control
##
## Orquestador del modo RogueLike.
## Controla el flujo entre batallas, recompensas, tienda y curación.
## Usa RogueManager para el estado y BattleLauncher para lanzar batallas.
##

const BATTLE_SCENE := "res://scenes/battle/BattleScene.tscn"
const ROGUE_SCENE := "res://scenes/rogue/RogueRun.tscn"
const MAIN_MENU := "res://scenes/MainMenu.tscn"

var _hud: RogueHUD
var _reward_panel: RogueRewardPanel
var _shop_panel: RogueShopPanel
var _bg: ColorRect


func _ready() -> void:
	# Fondo
	_bg = ColorRect.new()
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.color = Color(0.05, 0.06, 0.10, 1.0)
	add_child(_bg)

	# HUD superior
	_hud = RogueHUD.new()
	add_child(_hud)

	# Panel de recompensa (oculto)
	_reward_panel = RogueRewardPanel.new()
	_reward_panel.visible = false
	_reward_panel.continuar_presionado.connect(_on_reward_continuar)
	add_child(_reward_panel)

	# Panel de tienda (oculto)
	_shop_panel = RogueShopPanel.new()
	_shop_panel.visible = false
	_shop_panel.continuar_presionado.connect(_on_shop_continuar)
	add_child(_shop_panel)

	# Iniciar o continuar la run
	var rm := _get_rm()
	if not rm.run_activa:
		rm.iniciar_run()

	# Procesar el paso actual
	_hud.actualizar()
	# Usar call_deferred para que la escena esté lista
	call_deferred("_procesar_paso")


func _procesar_paso() -> void:
	var rm := _get_rm()
	_hud.actualizar()

	match rm.paso_actual:
		RogueManager.Paso.COMBATE_1, RogueManager.Paso.COMBATE_2:
			_lanzar_batalla(false)
		RogueManager.Paso.BOSS:
			_lanzar_batalla(true)
		RogueManager.Paso.RECOMPENSA_1, RogueManager.Paso.RECOMPENSA_2, RogueManager.Paso.RECOMPENSA_BOSS:
			_mostrar_recompensa()
		RogueManager.Paso.TIENDA:
			_mostrar_tienda()
		RogueManager.Paso.CURACION:
			_curar_y_continuar()
		RogueManager.Paso.IDLE:
			# Run terminada (derrota) — volver al menú
			get_tree().change_scene_to_file(MAIN_MENU)


func _lanzar_batalla(es_boss: bool) -> void:
	var rm := _get_rm()
	var config: BattleConfig = rm.generar_batalla_config(es_boss)

	# Inyectar config al BattleLauncher
	var launcher: Node = Engine.get_main_loop().root.get_node_or_null("BattleLauncher")
	if launcher:
		launcher.rogue_config = config

	# Configurar retorno
	var gm: Node = Engine.get_main_loop().root.get_node_or_null("GameManager")
	if gm:
		gm.return_scene_after_battle = ROGUE_SCENE

	# Avanzar paso ANTES de lanzar (al volver, estaremos en RECOMPENSA)
	rm.avanzar_paso()

	print("[RogueRun] Lanzando batalla — Boss: %s, Mapa: %dx%d" % [str(es_boss), config.width, config.height])
	get_tree().change_scene_to_file(BATTLE_SCENE)


func _mostrar_recompensa() -> void:
	var rm := _get_rm()
	var paso_nombre: String = rm.NOMBRES_PASO.get(rm.paso_actual, "Recompensa")
	var oro: int = rm.ultimo_oro_batalla
	var interes: int = rm.otorgar_interes()
	var items: Array = rm.generar_recompensa_items()
	var pocion: ItemData = rm.generar_pocion_bonus()

	_reward_panel.mostrar(rm.ronda, paso_nombre, oro, interes, items, pocion)
	_hud.actualizar()


func _mostrar_tienda() -> void:
	var rm := _get_rm()
	_shop_panel.mostrar(rm.ronda)
	_hud.actualizar()


func _curar_y_continuar() -> void:
	var rm := _get_rm()
	rm.curar_completo()
	# Mostrar mensaje breve de curación y avanzar
	_mostrar_mensaje_curacion()


func _mostrar_mensaje_curacion() -> void:
	var rm := _get_rm()
	# Panel simple de curación
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(400, 200)
	panel.pivot_offset = Vector2(200, 100)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.11, 0.18, 0.99)
	style.corner_radius_top_left = 12; style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12; style.corner_radius_bottom_right = 12
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	margin.add_child(vbox)

	var titulo := Label.new()
	titulo.text = "Curación completa"
	titulo.add_theme_font_size_override("font_size", 24)
	titulo.add_theme_color_override("font_color", Color(0.3, 0.85, 0.4, 1.0))
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(titulo)

	var info := Label.new()
	info.text = "HP restaurado: %d/%d\nRonda %d completada" % [rm.player_hp, rm.player_max_hp, rm.ronda + 1]
	info.add_theme_font_size_override("font_size", 18)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(info)

	var btn := Button.new()
	btn.text = "Siguiente ronda"
	btn.custom_minimum_size = Vector2(200, 45)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.pressed.connect(func():
		panel.queue_free()
		rm.avanzar_paso()
		_procesar_paso()
	)
	vbox.add_child(btn)

	_hud.actualizar()


func _on_reward_continuar() -> void:
	var rm := _get_rm()
	rm.avanzar_paso()
	_procesar_paso()


func _on_shop_continuar() -> void:
	var rm := _get_rm()
	rm.avanzar_paso()
	_procesar_paso()


func _get_rm() -> Node:
	return Engine.get_main_loop().root.get_node("RogueManager")
