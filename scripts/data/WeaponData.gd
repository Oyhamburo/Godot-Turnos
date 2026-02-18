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

# ── Bonificaciones de stats (se suman al equipar, se restan al desequipar) ──
@export_group("Stat Bonuses")
@export var bonus_physical_damage: int = 0
@export var bonus_magic_damage: int = 0
@export var bonus_armor: int = 0
@export var bonus_magic_resist: int = 0
@export var bonus_speed: int = 0
@export_range(0.0, 1.0) var bonus_evasion: float = 0.0
@export_range(0.0, 1.0) var bonus_crit_chance: float = 0.0

# ── Habilidades ─────────────────────────────────────────────
# Cada entrada: { "display_name", "physical", "magic", "hit_chance", "range", "anim_name" }
# "range": 1 = melee (adyacente), 99 = distancia (siempre disponible)
@export var abilities: Array[Dictionary] = []
