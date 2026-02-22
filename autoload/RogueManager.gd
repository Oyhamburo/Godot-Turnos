extends Node
##
## Autoload que gestiona el estado de una partida RogueLike.
## Controla el flujo cíclico: Combate → Recompensa → Combate → Recompensa → Tienda → Boss → Recompensa → Curar → repetir.
##

signal paso_cambiado(paso: int)
signal ronda_cambiada(ronda: int)
signal run_terminada(victoria: bool)

enum Paso {
	IDLE,
	COMBATE_1,
	RECOMPENSA_1,
	COMBATE_2,
	RECOMPENSA_2,
	TIENDA,
	BOSS,
	RECOMPENSA_BOSS,
	CURACION,
}

## Nombres legibles para el HUD.
const NOMBRES_PASO: Dictionary = {
	Paso.IDLE: "Inactivo",
	Paso.COMBATE_1: "Combate 1",
	Paso.RECOMPENSA_1: "Recompensa",
	Paso.COMBATE_2: "Combate 2",
	Paso.RECOMPENSA_2: "Recompensa",
	Paso.TIENDA: "Tienda",
	Paso.BOSS: "Boss",
	Paso.RECOMPENSA_BOSS: "Recompensa Boss",
	Paso.CURACION: "Curación",
}

# ── Estado de la run ──────────────────────────────────────────
var run_activa: bool = false
var ronda: int = 0
var paso_actual: int = Paso.IDLE

## Inventario propio del roguelike (separado de GameManager.player_inventory).
var rogue_inventory: Inventory = null

## HP persistente entre batallas.
var player_hp: int = 0
var player_max_hp: int = 0

## Oro ganado en la última batalla (para el panel de recompensa).
var ultimo_oro_batalla: int = 0

# ── Configuración de escalado ─────────────────────────────────
const BASE_MAP_SIZE: int = 3
const ORO_POR_ENEMIGO: int = 25
const ORO_BONUS_VICTORIA: int = 50
const INTERES_MAX: int = 5

## Escenas y datos de enemigos disponibles.
const ENEMY_SCENES: Array[Dictionary] = [
	{"scene": "res://scenes/units/EnemySkeletonWarrior.tscn", "data": "res://data/units/enemy_skeleton_warrior.tres", "min_ronda": 0},
	{"scene": "res://scenes/units/EnemySkeletonRogue.tscn", "data": "res://data/units/enemy_skeleton_rogue.tres", "min_ronda": 1},
	{"scene": "res://scenes/units/EnemySkeletonMage.tscn", "data": "res://data/units/enemy_skeleton_mage.tres", "min_ronda": 2},
	{"scene": "res://scenes/units/EnemySkeletonMinion.tscn", "data": "res://data/units/enemy_skeleton_minion.tres", "min_ronda": 0},
]

const BOSS_SCENE: String = "res://scenes/units/EnemyMannequinLarge.tscn"
const BOSS_DATA: String = "res://data/units/enemy_mannequin_large.tres"

const PLAYER_SCENE: String = "res://scenes/units/PlayerMannequin.tscn"
const PLAYER_DATA: String = "res://data/units/rogue_player_mannequin.tres"

## Pool de armas para recompensas (paths).
const WEAPON_REWARD_POOL: Array[String] = [
	"res://data/weapons/player_sword.tres",
	"res://data/weapons/player_bow.tres",
	"res://data/weapons/player_axe_2h.tres",
	"res://data/weapons/player_shield.tres",
	"res://data/weapons/player_dagger.tres",
]

## Pool de pociones para recompensas.
const POTION_REWARD_POOL: Array[String] = [
	"res://data/items/pocion_vida.tres",
	"res://data/items/pocion_mana.tres",
	"res://data/items/antidoto.tres",
	"res://data/items/pocion_fuerza.tres",
	"res://data/items/pocion_sigilo.tres",
]


# ══════════════════════════════════════════════════════════════
# MÉTODOS PÚBLICOS
# ══════════════════════════════════════════════════════════════

## Inicia una nueva run desde cero.
func iniciar_run() -> void:
	ronda = 0
	paso_actual = Paso.COMBATE_1
	run_activa = true
	player_hp = 0
	player_max_hp = 0
	ultimo_oro_batalla = 0

	# Inventario fresco
	rogue_inventory = Inventory.new()
	rogue_inventory.gold = 0
	# Arma inicial: puños del mannequin
	var arma_inicial_path := "res://data/weapons/mannequin_large_fists.tres"
	if ResourceLoader.exists(arma_inicial_path):
		var arma: WeaponData = load(arma_inicial_path) as WeaponData
		if arma:
			rogue_inventory.add_weapon(arma)
			rogue_inventory.equipped_right = arma

	# Poción de vida inicial
	var pocion_path := "res://data/items/pocion_vida.tres"
	if ResourceLoader.exists(pocion_path):
		var pocion: ItemData = load(pocion_path) as ItemData
		if pocion:
			rogue_inventory.add_item(pocion)

	print("[RogueManager] Run iniciada — Ronda 0, Paso: COMBATE_1")
	paso_cambiado.emit(paso_actual)


## Avanza al siguiente paso del ciclo.
func avanzar_paso() -> void:
	match paso_actual:
		Paso.COMBATE_1:
			paso_actual = Paso.RECOMPENSA_1
		Paso.RECOMPENSA_1:
			paso_actual = Paso.COMBATE_2
		Paso.COMBATE_2:
			paso_actual = Paso.RECOMPENSA_2
		Paso.RECOMPENSA_2:
			paso_actual = Paso.TIENDA
		Paso.TIENDA:
			paso_actual = Paso.BOSS
		Paso.BOSS:
			paso_actual = Paso.RECOMPENSA_BOSS
		Paso.RECOMPENSA_BOSS:
			paso_actual = Paso.CURACION
		Paso.CURACION:
			ronda += 1
			paso_actual = Paso.COMBATE_1
			ronda_cambiada.emit(ronda)
			print("[RogueManager] Nueva ronda: %d" % ronda)
	print("[RogueManager] Paso: %s" % NOMBRES_PASO.get(paso_actual, "???"))
	paso_cambiado.emit(paso_actual)


## Calcula el interés basado en el oro actual: floor(gold/5), max 5.
func calcular_interes() -> int:
	if rogue_inventory == null:
		return 0
	return mini(INTERES_MAX, int(floor(float(rogue_inventory.gold) / 5.0)))


## Otorga el interés al inventario.
func otorgar_interes() -> int:
	var interes: int = calcular_interes()
	if interes > 0 and rogue_inventory:
		rogue_inventory.add_gold(interes)
		print("[RogueManager] Interés otorgado: +%d oro" % interes)
	return interes


## Calcula el oro de la última batalla (llamado desde battle_flow).
func calcular_oro_batalla(enemigos_muertos: int, todos_vivos: bool) -> int:
	var total: int = enemigos_muertos * ORO_POR_ENEMIGO
	if todos_vivos:
		total += ORO_BONUS_VICTORIA
	ultimo_oro_batalla = total
	if rogue_inventory:
		rogue_inventory.add_gold(total)
	print("[RogueManager] Oro batalla: +%d" % total)
	return total


## Genera un BattleConfig en memoria para el combate actual.
func generar_batalla_config(es_boss: bool) -> BattleConfig:
	var config := BattleConfig.new()
	var size: int = BASE_MAP_SIZE + ronda
	config.width = size
	config.height = size
	config.tile_size = 4.0
	config.facing_mode = "look_at_nearest_opponent"

	# Spawn del jugador: esquina inferior izquierda
	var player_spawn := SpawnEntry.new()
	player_spawn.unit_scene = load(PLAYER_SCENE) as PackedScene
	if ResourceLoader.exists(PLAYER_DATA):
		player_spawn.unit_data = load(PLAYER_DATA) as UnitData
	player_spawn.spawn_coords = Vector2i(0, size - 1)
	player_spawn.team = "player"
	config.spawns.append(player_spawn)

	if es_boss:
		_agregar_boss(config, size)
	else:
		_agregar_enemigos_normales(config, size)

	return config


## Guarda el HP del jugador tras la batalla.
func guardar_estado_jugador_desde_unidades(units: Array) -> void:
	for u in units:
		if u is Unit and u.team == Unit.Team.PLAYER and u.alive:
			player_hp = u.stats.hp
			player_max_hp = u.stats.max_hp
			print("[RogueManager] HP guardado: %d/%d" % [player_hp, player_max_hp])
			return
	# Si no hay jugador vivo, HP = 0
	player_hp = 0


## Cura completamente al jugador.
func curar_completo() -> void:
	if player_max_hp > 0:
		player_hp = player_max_hp
		print("[RogueManager] Curación completa: %d/%d" % [player_hp, player_max_hp])


## Termina la run (derrota o abandono).
func terminar_run(victoria: bool) -> void:
	print("[RogueManager] Run terminada — Victoria: %s, Ronda: %d" % [str(victoria), ronda])
	run_activa = false
	paso_actual = Paso.IDLE
	rogue_inventory = null
	run_terminada.emit(victoria)


## Genera 3 items aleatorios para la pantalla de recompensa.
func generar_recompensa_items() -> Array:
	var pool: Array[String] = []
	for path in WEAPON_REWARD_POOL:
		if ResourceLoader.exists(path):
			pool.append(path)

	pool.shuffle()
	var resultado: Array = []
	var count: int = mini(3, pool.size())
	for i in range(count):
		var res: Resource = load(pool[i])
		if res:
			resultado.append(res)
	return resultado


## Genera una poción bonus con 30% de probabilidad.
func generar_pocion_bonus() -> ItemData:
	if randf() > 0.3:
		return null
	var pool: Array[String] = []
	for path in POTION_REWARD_POOL:
		if ResourceLoader.exists(path):
			pool.append(path)
	if pool.is_empty():
		return null
	var path: String = pool[randi() % pool.size()]
	return load(path) as ItemData


## Retorna el tamaño del mapa para la ronda actual.
func get_map_size() -> int:
	return BASE_MAP_SIZE + ronda


## Retorna el multiplicador de stats para la ronda actual.
func get_stat_multiplier() -> float:
	return 1.0 + 0.15 * ronda


# ══════════════════════════════════════════════════════════════
# PRIVADOS
# ══════════════════════════════════════════════════════════════

func _agregar_enemigos_normales(config: BattleConfig, size: int) -> void:
	var cantidad: int = clampi(1 + ronda, 1, maxi(1, int(size * size / 3.0)))
	var enemigos_disponibles: Array[Dictionary] = []
	for entry in ENEMY_SCENES:
		if ronda >= entry["min_ronda"]:
			enemigos_disponibles.append(entry)
	if enemigos_disponibles.is_empty():
		enemigos_disponibles.append(ENEMY_SCENES[0])

	var posiciones_usadas: Array[Vector2i] = [Vector2i(0, size - 1)]  # jugador
	for i in range(cantidad):
		var enemy_info: Dictionary = enemigos_disponibles[randi() % enemigos_disponibles.size()]
		var spawn := SpawnEntry.new()
		spawn.unit_scene = load(enemy_info["scene"]) as PackedScene
		spawn.unit_data = _crear_unit_data_escalado(enemy_info["data"])
		spawn.spawn_coords = _buscar_posicion_libre(size, posiciones_usadas)
		spawn.team = "enemy"
		config.spawns.append(spawn)
		posiciones_usadas.append(spawn.spawn_coords)


func _agregar_boss(config: BattleConfig, size: int) -> void:
	var spawn := SpawnEntry.new()
	spawn.unit_scene = load(BOSS_SCENE) as PackedScene
	spawn.unit_data = _crear_unit_data_escalado(BOSS_DATA)
	spawn.spawn_coords = Vector2i(size - 1, 0)
	spawn.team = "enemy"
	config.spawns.append(spawn)


func _crear_unit_data_escalado(path: String) -> UnitData:
	if not ResourceLoader.exists(path):
		return null
	var base: UnitData = load(path).duplicate() as UnitData
	if not base:
		return null
	var mult: float = get_stat_multiplier()
	base.max_hp = int(base.max_hp * mult)
	base.attack = int(base.attack * mult)
	base.physical_damage = int(base.physical_damage * mult)
	base.magic_damage = int(base.magic_damage * mult)
	base.armor = int(base.armor * (1.0 + 0.08 * ronda))
	return base


func _buscar_posicion_libre(size: int, usadas: Array[Vector2i]) -> Vector2i:
	# Intentar posiciones en la mitad superior/derecha del mapa
	for _intento in range(50):
		var x: int = randi() % size
		var y: int = randi() % size
		var pos := Vector2i(x, y)
		if pos not in usadas:
			# Preferir que no esté adyacente al jugador (0, size-1)
			if absi(x) + absi(y - (size - 1)) >= 2:
				return pos
	# Fallback: cualquier posición libre
	for x in range(size):
		for y in range(size):
			var pos := Vector2i(x, y)
			if pos not in usadas:
				return pos
	return Vector2i(size - 1, 0)
