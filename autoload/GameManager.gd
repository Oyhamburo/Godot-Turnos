extends Node
##
## Autoload global que persiste entre escenas.
## Contiene el inventario compartido del jugador y metadata de navegación.
##

## Inventario único del jugador: armas, oro, items, equipment.
## Compartido entre ciudad (tiendas), exploración y batalla.
var player_inventory: Inventory = null

## Escena a la que volver tras terminar una batalla.
## Se setea antes de lanzar la batalla (ej: ExploreMap o ThirdPersonMap).
## Si está vacío, vuelve al MainMenu como fallback.
var return_scene_after_battle: String = ""

## Oro ganado en la última batalla (para que la escena destino lo use si quiere).
var last_battle_reward_gold: int = 0

## Oro base que otorga cada enemigo derrotado.
const ORO_POR_ENEMIGO: int = 25

## Oro bonus por victoria completa (todos los jugadores sobrevivieron).
const ORO_BONUS_VICTORIA: int = 50


func _ready() -> void:
	_inicializar_inventario()


## Crea el inventario inicial del jugador con oro, armas y pociones por defecto.
func _inicializar_inventario() -> void:
	player_inventory = Inventory.new()
	player_inventory.gold = 150
	# Arma inicial (Knight por defecto)
	_agregar_arma("res://data/weapons/swords/player_sword.tres", true)   # equipped_right
	_agregar_arma("res://data/weapons/shields/player_shield.tres", false)  # equipped_left
	# Pociones iniciales
	_agregar_item("res://data/items/pocion_vida.tres")
	_agregar_item("res://data/items/pocion_vida.tres")
	_agregar_item("res://data/items/pocion_mana.tres")
	_agregar_item("res://data/items/antidoto.tres")
	# Pociones de buff (efectos de estado)
	_agregar_item("res://data/items/pocion_fuerza.tres")
	_agregar_item("res://data/items/pocion_sigilo.tres")


## Agrega una poción/consumible al inventario.
func _agregar_item(path: String) -> void:
	if not ResourceLoader.exists(path):
		return
	var item: ItemData = load(path) as ItemData
	if item:
		player_inventory.add_item(item)


## Agrega un arma al inventario y opcionalmente la equipa.
func _agregar_arma(path: String, mano_derecha: bool) -> void:
	if not ResourceLoader.exists(path):
		return
	var w: WeaponData = load(path) as WeaponData
	if not w:
		return
	player_inventory.add_weapon(w)
	if mano_derecha:
		player_inventory.equipped_right = w
	else:
		player_inventory.equipped_left = w


## Calcula y otorga la recompensa de oro al ganar una batalla.
## Retorna el total de oro ganado.
func otorgar_recompensa_batalla(enemigos_derrotados: int, victoria_total: bool) -> int:
	var total: int = enemigos_derrotados * ORO_POR_ENEMIGO
	if victoria_total:
		total += ORO_BONUS_VICTORIA
	player_inventory.add_gold(total)
	last_battle_reward_gold = total
	print("[GameManager] Recompensa batalla: %d oro (%d enemigos x %d + bonus %d)" % [
		total, enemigos_derrotados, ORO_POR_ENEMIGO,
		ORO_BONUS_VICTORIA if victoria_total else 0
	])
	return total
