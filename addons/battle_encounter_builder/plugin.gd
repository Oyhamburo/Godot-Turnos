@tool
extends EditorPlugin
##
## Battle Encounter Builder: dock para crear y editar encuentros de batalla.
## Menú: Project > Battle Encounter Builder
##

const DOCK_SCRIPT := preload("res://addons/battle_encounter_builder/encounter_builder_dock.gd")
const MENU_NAME := "Battle Encounter Builder"

var _dock: Control


func _enter_tree() -> void:
	add_tool_menu_item(MENU_NAME, _on_menu_pressed)
	call_deferred("_setup_dock")


func _setup_dock() -> void:
	_dock = DOCK_SCRIPT.new()
	_dock.custom_minimum_size = Vector2(280, 400)
	if _dock.has_method("set_plugin"):
		_dock.set_plugin(self)
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, _dock)


func _exit_tree() -> void:
	remove_tool_menu_item(MENU_NAME)
	if _dock:
		remove_control_from_docks(_dock)
		_dock.queue_free()
		_dock = null


func _on_menu_pressed() -> void:
	var base: Control = get_editor_interface().get_base_control()
	var dock_container: Control = _find_dock_containing(_dock)
	if dock_container:
		dock_container.show()
		# Intentar hacer visible el tab si está en un TabContainer
		var parent := _dock.get_parent()
		while parent:
			if parent is TabContainer:
				var tc: TabContainer = parent as TabContainer
				for i in range(tc.get_tab_count()):
					if tc.get_tab_control(i) == _dock or _dock.is_ancestor_of(tc.get_tab_control(i)):
						tc.current_tab = i
						break
				break
			parent = parent.get_parent()
	else:
		_dock.show()


func _find_dock_containing(control: Control) -> Control:
	var p := control.get_parent()
	while p:
		if p.get_class() == "EditorDockManager" or "Dock" in p.name:
			return p
		p = p.get_parent()
	return null
