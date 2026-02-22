extends Resource
class_name WeaponData

enum WeaponType { SWORD, BOW, STAFF, AXE, DAGGER, WAND, SPEAR, UNARMED, SHIELD }
enum SlotMode { RIGHT_HAND, LEFT_HAND, TWO_HANDED }

# ── Identidad ────────────────────────────────────────────────
@export var display_name: String = "Arma"
@export var weapon_type: WeaponType = WeaponType.SWORD
@export var slot: SlotMode = SlotMode.RIGHT_HAND

# ── Visual 3D ────────────────────────────────────────────────
@export var scene_3d_path: String = ""
@export var hand_offset_pos: Vector3 = Vector3.ZERO
@export var hand_offset_rot: Vector3 = Vector3.ZERO
## Mano donde se instancia el modelo 3D. Solo relevante para armas TWO_HANDED.
## RIGHT_HAND=0 (default), LEFT_HAND=1. No afecta las estadísticas ni el slot de combate.
@export_enum("RIGHT_HAND", "LEFT_HAND") var visual_hand: int = 0

# ── Proyectil (opcional, solo para armas de arco/ballesta) ───
## Ruta al GLB/GLTF de la flecha individual. Vacío = sin proyectil.
@export var projectile_scene_path: String = ""
## Ruta al GLB/GLTF del manojo de flechas (habilidad _up). Vacío = usa projectile_scene_path.
@export var projectile_bundle_path: String = ""

# ── Bonificaciones de stats (se suman al equipar, se restan al desequipar) ──
@export_group("Stat Bonuses")
@export var bonus_physical_damage: int = 0
@export var bonus_magic_damage: int = 0
@export var bonus_armor: int = 0
@export var bonus_magic_resist: int = 0
@export var bonus_speed: int = 0
@export_range(0.0, 1.0) var bonus_evasion: float = 0.0
@export_range(0.0, 1.0) var bonus_crit_chance: float = 0.0

# ── Precio (tienda) ─────────────────────────────────────────
@export_group("Precio")
@export var buy_price: int = 0
@export var sell_price: int = 0

# ── Habilidades ─────────────────────────────────────────────
# Cada entrada: { "display_name", "physical", "magic", "hit_chance", "range", "anim_name",
#                  "aoe_radius" (opcional, int), "aoe_friendly_fire" (opcional, bool) }
# "range": 1 = melee (adyacente), 99 = distancia (siempre disponible)
# "aoe_radius": radio Manhattan del area de efecto (0 o ausente = single target)
# "aoe_friendly_fire": si true, aliados y el propio atacante reciben daño si están en el area
@export var abilities: Array[Dictionary] = []
