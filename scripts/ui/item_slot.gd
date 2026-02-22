extends PanelContainer
class_name ItemSlot
##
## Slot reutilizable de inventario.
## Fondo: panelInset_blue.png de Kenney UI Pack RPG Expansion.
## Muestra preview 3D del ítem si tiene scene_3d_path o model_path.
## Soporta drag & drop, highlight (iconCheck/iconCross Kenney), tooltip.
##

## Emitido al hacer clic izquierdo sobre el slot.
signal slot_clicked(slot: ItemSlot)
## Emitido al empezar a arrastrar desde este slot.
signal slot_drag_started(slot: ItemSlot)
## Emitido cuando se suelta un ítem arrastrado SOBRE este slot.
signal item_dropped(from_slot: ItemSlot, to_slot: ItemSlot)

## Nombre del slot de equipamiento ("" = slot de inventario genérico).
var slot_name: String = ""

## Ítem contenido actualmente (ItemData, ArmorData, WeaponData o null).
var item = null

# ── Paths de assets Kenney ──────────────────────────────────────
const TEX_SLOT_NORMAL  := "res://assets/kenney_ui-pack-rpg-expansion/PNG/panelInset_blue.png"
const TEX_SLOT_SELECTED:= "res://assets/kenney_ui-pack-rpg-expansion/PNG/panelInset_beigeLight.png"
const TEX_SLOT_BG      := "res://assets/kenney_ui-pack-rpg-expansion/PNG/panel_blue.png"
const TEX_CHECK        := "res://assets/kenney_ui-pack-rpg-expansion/PNG/iconCheck_blue.png"
const TEX_CROSS        := "res://assets/kenney_ui-pack-rpg-expansion/PNG/iconCross_brown.png"

# ── Colores de tinte para highlights ───────────────────────────
const C_TINT_NORMAL  := Color(1.0,  1.0,  1.0,  1.0)
const C_TINT_VALID   := Color(0.5,  1.0,  0.55, 1.0)
const C_TINT_INVALID := Color(1.0,  0.45, 0.45, 1.0)
const C_TINT_SEL     := Color(0.85, 0.92, 1.0,  1.0)
const C_LABEL_DIM    := Color(0.70, 0.75, 0.90, 1.0)
const SLOT_SIZE      := Vector2(104, 104)

# Escala de los modelos 3D en el preview del slot
const MODEL_SCALE_DUNGEON := 0.30
const MODEL_SCALE_WEAPON  := 0.012

var _bg_rect: TextureRect         # fondo Kenney
var _icon_rect: TextureRect       # ícono 2D o placeholder
var _overlay_rect: TextureRect    # check/cross de validez
var _nombre_label: Label
var _3d_viewport: SubViewport = null   # preview 3D (lazy)
var _3d_container: SubViewportContainer = null
var _3d_anchor: Node3D = null          # anchor para el modelo (se limpia al cambiar)

var _seleccionado: bool = false
var _highlight_mode: int = 0  # 0=normal, 1=valid, 2=invalid


func _init(p_slot_name: String = "", p_size: Vector2 = SLOT_SIZE) -> void:
	slot_name = p_slot_name
	custom_minimum_size = p_size
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()


func _build_ui() -> void:
	# StyleBox transparente (el fondo lo pone _bg_rect)
	var empty_style := StyleBoxEmpty.new()
	add_theme_stylebox_override("panel", empty_style)

	# ── Fondo Kenney (panelInset_blue) ──
	_bg_rect = TextureRect.new()
	_bg_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bg_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_bg_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists(TEX_SLOT_NORMAL):
		_bg_rect.texture = load(TEX_SLOT_NORMAL)
	add_child(_bg_rect)

	# ── Ícono / preview del ítem ──
	_icon_rect = TextureRect.new()
	_icon_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_icon_rect.offset_left   = 6
	_icon_rect.offset_right  = -6
	_icon_rect.offset_top    = 6
	_icon_rect.offset_bottom = -16   # dejar espacio al label inferior
	_icon_rect.expand_mode   = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	_icon_rect.stretch_mode  = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon_rect.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	add_child(_icon_rect)

	# ── Overlay de validez (check/cross) ──
	_overlay_rect = TextureRect.new()
	_overlay_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay_rect.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
	_overlay_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_overlay_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay_rect.visible = false
	add_child(_overlay_rect)

	# ── Label de nombre del slot (slot de equipo) ──
	_nombre_label = Label.new()
	_nombre_label.add_theme_font_size_override("font_size", 10)
	_nombre_label.add_theme_color_override("font_color", C_LABEL_DIM)
	_nombre_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_nombre_label.vertical_alignment   = VERTICAL_ALIGNMENT_BOTTOM
	_nombre_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_nombre_label.offset_bottom = -2
	_nombre_label.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	_nombre_label.text    = ItemSlot._slot_label(slot_name)
	_nombre_label.visible = slot_name != ""
	add_child(_nombre_label)


# ── API pública ────────────────────────────────────────────────

## Asigna el ítem al slot y actualiza la visualización.
func set_item(new_item) -> void:
	item = new_item
	_refresh_visual()


## Limpia el slot.
func clear() -> void:
	item = null
	_refresh_visual()


## Marca el slot como seleccionado.
func set_selected(sel: bool) -> void:
	_seleccionado = sel
	_refresh_tint()


## Muestra highlight: 1 = válido (verde), 2 = inválido (rojo), 0 = normal.
func set_highlight(mode: int) -> void:
	_highlight_mode = mode
	_refresh_tint()
	_refresh_overlay()


# ── Visual ─────────────────────────────────────────────────────

func _refresh_visual() -> void:
	# Intentar mostrar preview 3D del ítem
	var model_path := _get_model_path(item)
	if model_path != "" and ResourceLoader.exists(model_path):
		_show_3d_preview(model_path)
		_icon_rect.texture = null
	else:
		_hide_3d_preview()
		var icon_p := _get_icon_path(item)
		if icon_p != "" and ResourceLoader.exists(icon_p):
			_icon_rect.texture = load(icon_p)
		else:
			_icon_rect.texture = null

	_nombre_label.text    = ItemSlot._slot_label(slot_name)
	_nombre_label.visible = slot_name != ""
	_refresh_tint()
	_refresh_overlay()


func _refresh_tint() -> void:
	if _highlight_mode == 1:
		_bg_rect.modulate = C_TINT_VALID
	elif _highlight_mode == 2:
		_bg_rect.modulate = C_TINT_INVALID
	elif _seleccionado:
		_bg_rect.modulate = C_TINT_SEL
		# Cambiar a textura "seleccionado" si existe
		if ResourceLoader.exists(TEX_SLOT_SELECTED):
			_bg_rect.texture = load(TEX_SLOT_SELECTED)
	else:
		_bg_rect.modulate = C_TINT_NORMAL
		if ResourceLoader.exists(TEX_SLOT_NORMAL):
			_bg_rect.texture = load(TEX_SLOT_NORMAL)


func _refresh_overlay() -> void:
	if _highlight_mode == 1 and ResourceLoader.exists(TEX_CHECK):
		_overlay_rect.texture  = load(TEX_CHECK)
		_overlay_rect.modulate = Color(1, 1, 1, 0.55)
		_overlay_rect.visible  = true
	elif _highlight_mode == 2 and ResourceLoader.exists(TEX_CROSS):
		_overlay_rect.texture  = load(TEX_CROSS)
		_overlay_rect.modulate = Color(1, 1, 1, 0.55)
		_overlay_rect.visible  = true
	else:
		_overlay_rect.visible = false


# ── Preview 3D ─────────────────────────────────────────────────

func _show_3d_preview(model_path: String) -> void:
	# Construir el SubViewport la primera vez (lazy)
	if _3d_viewport == null:
		_3d_container = SubViewportContainer.new()
		_3d_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_3d_container.offset_left   = 4
		_3d_container.offset_right  = -4
		_3d_container.offset_top    = 4
		_3d_container.offset_bottom = -14
		_3d_container.mouse_filter  = Control.MOUSE_FILTER_IGNORE
		add_child(_3d_container)

		_3d_viewport = SubViewport.new()
		_3d_viewport.size = Vector2i(96, 96)
		_3d_viewport.transparent_bg = true
		_3d_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		_3d_viewport.world_3d = World3D.new()
		_3d_container.add_child(_3d_viewport)

		# Ambiente con luz ambiental (evita silueta negra en World3D aislado)
		var env := Environment.new()
		env.background_mode = Environment.BG_COLOR
		env.background_color = Color(0.12, 0.13, 0.20, 0.0)
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color(0.85, 0.85, 0.95, 1.0)
		env.ambient_light_energy = 0.6
		var world_env := WorldEnvironment.new()
		world_env.environment = env
		_3d_viewport.add_child(world_env)

		# Cámara del slot
		var cam := Camera3D.new()
		cam.fov = 50.0
		cam.position = Vector3(0.0, 0.6, 1.4)
		# Orientar sin look_at (no estamos en árbol aún)
		cam.rotation_degrees = Vector3(-20, 0, 0)
		_3d_viewport.add_child(cam)

		# Luz principal
		var light := DirectionalLight3D.new()
		light.rotation_degrees = Vector3(-45, 30, 0)
		light.light_energy = 2.0
		_3d_viewport.add_child(light)

		# Luz de relleno
		var fill := DirectionalLight3D.new()
		fill.rotation_degrees = Vector3(30, -60, 0)
		fill.light_energy = 0.7
		fill.light_color = Color(0.85, 0.9, 1.0)
		_3d_viewport.add_child(fill)

		# Anchor para modelos (solo este se limpia al cambiar ítem)
		_3d_anchor = Node3D.new()
		_3d_viewport.add_child(_3d_anchor)

	# Limpiar modelos anteriores (solo hijos del anchor)
	for child in _3d_anchor.get_children():
		child.queue_free()

	# Cargar el nuevo modelo
	var packed: PackedScene = load(model_path)
	if packed == null:
		return
	var inst: Node3D = packed.instantiate()

	# Escala: los GLTFs del dungeon son ~1 unit, los GLB de personajes ~150 units
	var scale_val: float = MODEL_SCALE_DUNGEON
	if model_path.ends_with(".glb"):
		scale_val = MODEL_SCALE_WEAPON
	inst.scale = Vector3.ONE * scale_val

	_3d_anchor.add_child(inst)
	_3d_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_3d_container.visible = true
	_icon_rect.visible = false


func _hide_3d_preview() -> void:
	if _3d_container:
		_3d_container.visible = false
	_icon_rect.visible = true


# ── Helpers ────────────────────────────────────────────────────

## Devuelve el path al modelo 3D del ítem (GLTF del dungeon pack o scene_3d_path).
func _get_model_path(it) -> String:
	if it == null:
		return ""
	# WeaponData puede tener scene_3d_path
	if it is WeaponData and "scene_3d_path" in it and it.scene_3d_path != "":
		return it.scene_3d_path
	# ArmorData e ItemData pueden tener model_path (si se agrega en el futuro)
	if "model_path" in it and it.model_path != "":
		return it.model_path
	return ""


func _get_icon_path(it) -> String:
	if it == null:
		return ""
	if it is ArmorData:
		return it.icon_path
	elif it is ItemData:
		return it.icon_path
	elif it is WeaponData and "icon_path" in it:
		return it.icon_path
	return ""


static func _slot_label(sn: String) -> String:
	match sn:
		"head":      return "Cabeza"
		"chest":     return "Pecho"
		"legs":      return "Piernas"
		"boots":     return "Botas"
		"weapon":    return "Arma"
		"offhand":   return "Escudo"
		"accessory": return "Accesorio"
	return ""


# ── Input & Drag ──────────────────────────────────────────────

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			slot_clicked.emit(self)


func _get_drag_data(_at_position: Vector2):
	if item == null:
		return null
	slot_drag_started.emit(self)
	# Preview de drag: icono Kenney del ítem si existe, si no label de texto
	var preview := PanelContainer.new()
	preview.custom_minimum_size = Vector2(52, 52)
	var tex := TextureRect.new()
	tex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tex.expand_mode  = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var icon_p := _get_icon_path(item)
	if icon_p != "" and ResourceLoader.exists(icon_p):
		tex.texture = load(icon_p)
	else:
		var lbl := Label.new()
		lbl.text = item.display_name if "display_name" in item else "Ítem"
		lbl.add_theme_color_override("font_color", Color.WHITE)
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		preview.add_child(lbl)
	preview.add_child(tex)
	set_drag_preview(preview)
	return {"from_slot": self, "item": item}


func _can_drop_data(_at_position: Vector2, data) -> bool:
	return data is Dictionary and data.has("from_slot") and data.has("item")


func _drop_data(_at_position: Vector2, data) -> void:
	if data is Dictionary and data.has("from_slot"):
		item_dropped.emit(data["from_slot"] as ItemSlot, self)
