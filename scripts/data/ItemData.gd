extends Resource
class_name ItemData

enum ItemType { HEAL_HP, HEAL_MANA, ANTIDOTE }

@export var display_name: String = "Ítem"
@export var item_type: ItemType = ItemType.HEAL_HP
@export var description: String = ""
@export var effect_value: int = 20
