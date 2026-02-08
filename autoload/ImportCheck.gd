extends Node
##
## Comprueba al arranque que existan los .import del pack hexagonal.
## Si faltan, Godot muestra: "Cannot open file from path '...hexagons_medieval.png.import'"
##

const HEX_IMPORTS := [
	"res://assets/KayKit_Medieval_Hexagon_Pack_1.0_FREE/Assets/gltf/tiles/rivers/waterless/hexagons_medieval.png.import",
	"res://assets/KayKit_Medieval_Hexagon_Pack_1.0_FREE/Assets/gltf/tiles/coast/waterless/hexagons_medieval.png.import",
]

func _ready() -> void:
	var missing: PackedStringArray = PackedStringArray()
	for path in HEX_IMPORTS:
		if not FileAccess.file_exists(path):
			missing.append(path)
	if missing.size() > 0:
		print("[ImportCheck] Faltan %d archivo(s) .import del pack hexagonal:" % missing.size())
		for p in missing:
			print("  - ", p)
		print("[ImportCheck] Copia hexagons_medieval.png.import desde tiles/base/ a rivers/waterless/ y coast/waterless/ y ajusta source_file en cada uno.")
	else:
		print("[ImportCheck] Texturas del pack hexagonal: OK")
