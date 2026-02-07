extends PanelContainer

@onready var label: Label = $"Margin/HBox/NameLabel"
@onready var marker: ColorRect = $"Margin/HBox/Marker"

var _unit: Unit

func setup(unit: Unit, is_current: bool) -> void:
	_unit = unit
	label.text = unit.display_name

	if unit.team == Unit.Team.PLAYER:
		marker.color = Color(0.45, 0.65, 1.0, 1)
	else:
		marker.color = Color(1.0, 0.45, 0.55, 1)

	modulate = Color(1, 1, 1, 1) if is_current else Color(0.85, 0.85, 0.85, 0.7)
