class_name HexGrid

## Tamaño del hex (radio desde centro a vértice); el mesh del pack tiene bounds ~1.15
const HEX_SIZE: float = 1.0

static func hex_to_world(q: int, r: int, y: float = 0.0) -> Vector3:
	var x: float = HEX_SIZE * (sqrt(3.0) * float(q) + sqrt(3.0) / 2.0 * float(r))
	var z: float = HEX_SIZE * (1.5 * float(r))
	return Vector3(x, y, z)

static func world_to_hex(world_x: float, world_z: float) -> Vector2i:
	var q: float = (world_x / (HEX_SIZE * sqrt(3.0))) - (world_z / (HEX_SIZE * 3.0))
	var r: float = world_z / (HEX_SIZE * 1.5)
	return _axial_round(q, r)

static func _axial_round(q: float, r: float) -> Vector2i:
	var s: float = -q - r
	var q_i: int = int(roundi(q))
	var r_i: int = int(roundi(r))
	var s_i: int = int(roundi(s))
	var q_diff: float = absf(q_i - q)
	var r_diff: float = absf(r_i - r)
	var s_diff: float = absf(s_i - s)
	if q_diff > r_diff and q_diff > s_diff:
		q_i = -r_i - s_i
	elif r_diff > s_diff:
		r_i = -q_i - s_i
	return Vector2i(q_i, r_i)

static func get_neighbours(q: int, r: int) -> Array[Vector2i]:
	return [
		Vector2i(q + 1, r),
		Vector2i(q + 1, r - 1),
		Vector2i(q, r - 1),
		Vector2i(q - 1, r),
		Vector2i(q - 1, r + 1),
		Vector2i(q, r + 1)
	]

static func is_neighbour(from_q: int, from_r: int, to_q: int, to_r: int) -> bool:
	var n: Array[Vector2i] = get_neighbours(from_q, from_r)
	for v in n:
		if v.x == to_q and v.y == to_r:
			return true
	return false

## Retorna todos los hexes alcanzables desde 'origen' en 1..pasos pasos dentro de valid_hexes.
## Incluye todos los hexes intermedios (el jugador puede detenerse en cualquiera).
static func get_hexes_en_rango(origen: Vector2i, pasos: int, valid_hexes: Array[Vector2i]) -> Array[Vector2i]:
	var visitados: Dictionary = {}
	var frontera: Array[Vector2i] = [origen]
	visitados[origen] = true
	var resultado: Array[Vector2i] = []
	for _i in range(pasos):
		var siguiente: Array[Vector2i] = []
		for hex in frontera:
			for vecino in get_neighbours(hex.x, hex.y):
				if visitados.has(vecino):
					continue
				if vecino in valid_hexes:
					visitados[vecino] = true
					siguiente.append(vecino)
					resultado.append(vecino)
		frontera = siguiente
	return resultado

## Camino más corto desde origen hasta destino usando BFS dentro de valid_hexes.
## Devuelve array de hexes desde el primer paso hasta el destino (sin incluir origen).
## Devuelve [] si no hay camino o si origen == destino.
static func encontrar_camino(origen: Vector2i, destino: Vector2i, valid_hexes: Array[Vector2i]) -> Array[Vector2i]:
	if origen == destino:
		return []
	var padres: Dictionary = {}
	var cola: Array[Vector2i] = [origen]
	padres[origen] = origen
	while not cola.is_empty():
		var actual: Vector2i = cola.pop_front()
		if actual == destino:
			var camino: Array[Vector2i] = []
			var cursor: Vector2i = destino
			while cursor != origen:
				camino.push_front(cursor)
				cursor = padres[cursor]
			return camino
		for vecino in get_neighbours(actual.x, actual.y):
			if padres.has(vecino):
				continue
			if vecino in valid_hexes:
				padres[vecino] = actual
				cola.append(vecino)
	return []
