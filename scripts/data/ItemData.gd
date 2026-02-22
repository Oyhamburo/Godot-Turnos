extends Resource
class_name ItemData

## Tipos de ítem. Los valores HEAL_* son compatibles con los .tres existentes.
enum ItemType {
	HEAL_HP,        # 0 — poción de HP (retrocompatible)
	HEAL_MANA,      # 1 — poción de maná (retrocompatible)
	ANTIDOTE,       # 2 — antídoto (retrocompatible)
	CONSUMABLE,     # 3 — consumible genérico
	MATERIAL,       # 4 — material/crafting
	ARMOR_HEAD,     # 5 — casco/yelmo
	ARMOR_CHEST,    # 6 — pechera/coraza
	ARMOR_LEGS,     # 7 — grebas/pantalón
	ARMOR_BOOTS,    # 8 — botas
	SHIELD,         # 9 — escudo (mano izquierda)
	ACCESSORY,      # 10 — accesorio/anillo/amuleto
	STATUS_EFFECT,  # 11 — poción que aplica un efecto de estado (buff o debuff)
}

@export var display_name: String = "Ítem"
@export var item_type: ItemType = ItemType.HEAL_HP
@export var description: String = ""
@export var effect_value: int = 20

## Modificadores de stats al equipar. Claves válidas: hp, atk, def, speed, weight
## Ejemplo: {"def": 5, "hp": 10, "speed": -1, "weight": 8}
@export var stats_mod: Dictionary = {}

## Path a un PNG/SVG para mostrar en el inventario. Vacío = sin ícono.
@export var icon_path: String = ""

## Path a un GLTF para mostrar como preview 3D en el slot de inventario.
## Usar assets del KayKit_DungeonRemastered pack cuando corresponda.
@export var model_path: String = ""

## Precio al que el jugador puede VENDER este ítem en la tienda.
@export var sell_price: int = 0

## Precio al que el jugador puede COMPRAR este ítem en la tienda.
@export var buy_price: int = 0

## ═══════════════════════════════════════════════════════════
## Efecto de Estado (solo para item_type == STATUS_EFFECT)
## ═══════════════════════════════════════════════════════════

## Tipo de efecto a aplicar (StatusEffect.Tipo como int). -1 = ninguno.
@export_group("Efecto de Estado")
@export var status_effect_tipo: int = -1

## Duración en turnos del efecto.
@export var status_effect_duracion: int = 3

## Potencia del efecto (significado depende del tipo, ver StatusEffect).
@export var status_effect_potencia: int = 0
