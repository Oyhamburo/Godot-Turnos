extends Resource
class_name ArmorData
##
## Resource que representa una pieza de armadura equipable.
## Análogo a WeaponData pero para equipamiento de cuerpo.
##

enum ArmorSlot {
	HEAD,       # casco / yelmo
	CHEST,      # pechera / coraza
	LEGS,       # grebas / pantalón
	BOOTS,      # botas
	OFFHAND,    # escudo / mano izquierda
	ACCESSORY,  # anillo / amuleto / cinturón
}

## Nombre visible en la UI.
@export var display_name: String = "Armadura"

## Slot donde se equipa.
@export var armor_slot: ArmorSlot = ArmorSlot.CHEST

## Descripción corta para el panel de detalles.
@export var description: String = ""

## Path a un PNG para mostrar en los slots de inventario y equipamiento.
@export var icon_path: String = ""

## Path a un GLTF/GLB para mostrar como preview 3D en el slot de inventario.
## Usar assets del KayKit_DungeonRemastered pack cuando corresponda.
@export var model_path: String = ""

## Modificadores de stats al equipar.
## Claves válidas: hp, atk, def, speed, weight
## Ejemplo: {"def": 5, "hp": 10, "speed": -1, "weight": 8}
@export var stats_mod: Dictionary = {}

## Precio de venta (jugador → tienda).
@export var sell_price: int = 0

## Precio de compra (tienda → jugador).
@export var buy_price: int = 0
