extends RefCounted
class_name StatusEffectManager
##
## Gestor de efectos de estado para una unidad. Composición dentro de Unit.
##
## Responsabilidades:
##   - Aplicar/remover efectos con reglas de refresh (no stackea, refresca duración).
##   - Tick de inicio de turno: DoT, decrementar duraciones, limpiar expirados.
##   - Gestión de modificadores de stats (buffs) con revert limpio al expirar.
##   - Sistema de inmunidades por tipo.
##   - Señales para UI (FloatingHUD muestra emojis de efectos activos).
##

signal efecto_aplicado(efecto: StatusEffect)
signal efecto_removido(efecto: StatusEffect)
signal efecto_tick(efecto: StatusEffect, dano: int)

## Referencia a la unidad dueña (se asigna en _init).
var _unidad = null  # Unit

## Lista de efectos activos sobre la unidad.
var _efectos_activos: Array[StatusEffect] = []

## Inmunidades activas: si un Tipo está en esta lista, el efecto no se aplica.
var _inmunidades: Array = []  # Array de StatusEffect.Tipo

## Registro de modificadores de stats aplicados por buffs, para revertirlos al expirar.
## Clave: StatusEffect.Tipo → valor: Dictionary { "stat_name": cantidad_sumada }
var _modificadores_aplicados: Dictionary = {}


func _init(unidad = null) -> void:
	_unidad = unidad


## ═══════════════════════════════════════════════════════════
## APLICAR / REMOVER EFECTOS
## ═══════════════════════════════════════════════════════════

## Aplica un efecto de estado a la unidad.
## Si el efecto ya existe, refresca duración y potencia (NO stackea).
## Devuelve true si se aplicó, false si fue bloqueado por inmunidad.
func aplicar_efecto(efecto: StatusEffect) -> bool:
	if efecto == null:
		return false

	# Chequear inmunidad
	if es_inmune(efecto.tipo):
		if _unidad and _unidad.has_method("show_floating_text"):
			_unidad.show_floating_text(
				"%s ¡Inmune!" % efecto.obtener_emoji(),
				Color(0.7, 0.7, 0.7))
		print("[StatusEffectManager] %s es inmune a %s" % [
			_unidad.display_name if _unidad else "?", efecto.obtener_nombre()])
		return false

	# Si ya existe el mismo tipo: refrescar duración y potencia (no duplicar)
	var existente: StatusEffect = obtener_efecto(efecto.tipo)
	if existente:
		existente.duracion_restante = maxi(existente.duracion_restante, efecto.duracion_restante)
		existente.potencia = maxi(existente.potencia, efecto.potencia)
		if _unidad and _unidad.has_method("show_floating_text"):
			_unidad.show_floating_text(
				"%s %s (renovado)" % [efecto.obtener_emoji(), efecto.obtener_nombre()],
				efecto.obtener_color())
		print("[StatusEffectManager] %s: %s renovado (%d turnos, potencia %d)" % [
			_unidad.display_name if _unidad else "?",
			efecto.obtener_nombre(), existente.duracion_restante, existente.potencia])
		return true

	# Aplicar nuevo efecto
	_efectos_activos.append(efecto)

	# Aplicar modificadores de stats si es un buff
	_aplicar_modificador_stats(efecto)

	# Popup flotante
	if _unidad and _unidad.has_method("show_floating_text"):
		_unidad.show_floating_text(
			"%s %s (%d)" % [efecto.obtener_emoji(), efecto.obtener_nombre(), efecto.duracion_restante],
			efecto.obtener_color())

	print("[StatusEffectManager] %s: +%s (%d turnos, potencia %d)" % [
		_unidad.display_name if _unidad else "?",
		efecto.obtener_nombre(), efecto.duracion_restante, efecto.potencia])

	efecto_aplicado.emit(efecto)
	return true


## Remueve todas las instancias de un tipo de efecto.
func remover_efecto(tipo: StatusEffect.Tipo) -> void:
	var removidos: Array[StatusEffect] = []
	for i in range(_efectos_activos.size() - 1, -1, -1):
		if _efectos_activos[i].tipo == tipo:
			removidos.append(_efectos_activos[i])
			_efectos_activos.remove_at(i)

	for efecto in removidos:
		_remover_modificador_stats(efecto.tipo)
		efecto_removido.emit(efecto)
		if _unidad and _unidad.has_method("show_floating_text"):
			_unidad.show_floating_text(
				"%s %s terminó" % [efecto.obtener_emoji(), efecto.obtener_nombre()],
				Color(0.7, 0.7, 0.7))
		print("[StatusEffectManager] %s: -%s" % [
			_unidad.display_name if _unidad else "?", efecto.obtener_nombre()])


## Remueve todos los debuffs activos.
func remover_todos_debuffs() -> void:
	var tipos_a_remover: Array = []
	for efecto in _efectos_activos:
		if efecto.es_debuff() and not efecto.tipo in tipos_a_remover:
			tipos_a_remover.append(efecto.tipo)
	for tipo in tipos_a_remover:
		remover_efecto(tipo)


## Limpia absolutamente todos los efectos (llamar al morir la unidad).
func limpiar_todos() -> void:
	for efecto in _efectos_activos:
		_remover_modificador_stats(efecto.tipo)
		efecto_removido.emit(efecto)
	_efectos_activos.clear()
	_modificadores_aplicados.clear()


## ═══════════════════════════════════════════════════════════
## QUERIES
## ═══════════════════════════════════════════════════════════

## Devuelve true si la unidad tiene un efecto activo de este tipo.
func tiene_efecto(tipo: StatusEffect.Tipo) -> bool:
	for efecto in _efectos_activos:
		if efecto.tipo == tipo:
			return true
	return false


## Devuelve la instancia activa del efecto, o null si no existe.
func obtener_efecto(tipo: StatusEffect.Tipo) -> StatusEffect:
	for efecto in _efectos_activos:
		if efecto.tipo == tipo:
			return efecto
	return null


## Devuelve una copia del array de efectos activos (para UI).
func obtener_efectos_activos() -> Array[StatusEffect]:
	return _efectos_activos.duplicate()


## ═══════════════════════════════════════════════════════════
## INMUNIDADES
## ═══════════════════════════════════════════════════════════

## Devuelve true si la unidad es inmune a este tipo de efecto.
func es_inmune(tipo: StatusEffect.Tipo) -> bool:
	return tipo in _inmunidades


## Agrega una inmunidad. Si el efecto ya estaba activo, lo remueve.
func agregar_inmunidad(tipo: StatusEffect.Tipo) -> void:
	if not tipo in _inmunidades:
		_inmunidades.append(tipo)
	# Si el efecto ya estaba activo, removerlo inmediatamente
	if tiene_efecto(tipo):
		remover_efecto(tipo)


## Quita una inmunidad.
func remover_inmunidad(tipo: StatusEffect.Tipo) -> void:
	var idx: int = _inmunidades.find(tipo)
	if idx >= 0:
		_inmunidades.remove_at(idx)


## ═══════════════════════════════════════════════════════════
## TICK DE INICIO DE TURNO
## ═══════════════════════════════════════════════════════════

## Procesa todos los efectos activos al inicio del turno de la unidad:
##   1. Aplica daño por turno (DoT: veneno, sangrado, quemadura).
##   2. Decrementa duración de todos los efectos.
##   3. Remueve efectos expirados (revierte buffs).
## Retorna el daño total de DoT aplicado este turno.
func tick_inicio_turno() -> int:
	if _efectos_activos.is_empty():
		return 0

	var dano_total: int = 0

	# 1. Aplicar daño por turno (DoT)
	for efecto in _efectos_activos:
		if efecto.tipo in StatusEffect.EFECTOS_DANO_POR_TURNO and efecto.potencia > 0:
			var dano: int = efecto.potencia
			dano_total += dano

			# Aplicar daño: veneno/quemadura = mágico, sangrado = físico
			if _unidad and _unidad.has_method("take_damage_split"):
				if efecto.tipo == StatusEffect.Tipo.SANGRADO:
					_unidad.stats.apply_damage_direct(dano, 0)
				else:
					_unidad.stats.apply_damage_direct(0, dano)

			# Popup flotante de daño DoT
			if _unidad and _unidad.has_method("show_floating_text"):
				_unidad.show_floating_text(
					"%s -%d" % [efecto.obtener_emoji(), dano],
					efecto.obtener_color())

			efecto_tick.emit(efecto, dano)

			print("[StatusEffectManager] %s: %s tick → -%d HP" % [
				_unidad.display_name if _unidad else "?",
				efecto.obtener_nombre(), dano])

	# Chequear si murió por DoT
	if _unidad and _unidad.stats and _unidad.stats.hp <= 0 and _unidad.alive:
		_unidad.die()

	# 2. Decrementar duración de TODOS los efectos
	for efecto in _efectos_activos:
		efecto.duracion_restante -= 1

	# 3. Remover expirados (iterar en reversa para no romper índices)
	for i in range(_efectos_activos.size() - 1, -1, -1):
		if _efectos_activos[i].expirado():
			var expirado: StatusEffect = _efectos_activos[i]
			_efectos_activos.remove_at(i)
			_remover_modificador_stats(expirado.tipo)
			efecto_removido.emit(expirado)

			if _unidad and _unidad.has_method("show_floating_text"):
				_unidad.show_floating_text(
					"%s %s terminó" % [expirado.obtener_emoji(), expirado.obtener_nombre()],
					Color(0.7, 0.7, 0.7))

			print("[StatusEffectManager] %s: %s expiró" % [
				_unidad.display_name if _unidad else "?",
				expirado.obtener_nombre()])

	return dano_total


## ═══════════════════════════════════════════════════════════
## MODIFICADORES DE STATS (BUFFS)
## ═══════════════════════════════════════════════════════════

## Aplica los modificadores de stats correspondientes al efecto.
## Solo actúa sobre buffs que afectan stats directamente.
func _aplicar_modificador_stats(efecto: StatusEffect) -> void:
	if not _unidad or not _unidad.stats:
		return

	var mods: Dictionary = {}

	match efecto.tipo:
		StatusEffect.Tipo.FUERZA:
			## 💪 Fuerza: +potencia a physical_damage
			_unidad.stats.physical_damage += efecto.potencia
			mods["physical_damage"] = efecto.potencia

		StatusEffect.Tipo.POTENCIACION_MAGICA:
			## 🔮 Potenciación Mágica: +potencia a magic_damage
			_unidad.stats.magic_damage += efecto.potencia
			mods["magic_damage"] = efecto.potencia

		StatusEffect.Tipo.EVASION_MEJORADA:
			## 🦅 Evasión Mejorada: +potencia% a evasion (ej: 20 → +0.20)
			var aumento: float = efecto.potencia / 100.0
			_unidad.stats.evasion = clampf(_unidad.stats.evasion + aumento, 0.0, 1.0)
			mods["evasion"] = aumento

		_:
			return  # No es un buff que modifique stats

	if not mods.is_empty():
		_modificadores_aplicados[efecto.tipo] = mods
		_unidad.stats.notify_stats_changed()
		print("[StatusEffectManager] %s: stats modificados por %s → %s" % [
			_unidad.display_name if _unidad else "?",
			efecto.obtener_nombre(), str(mods)])


## Revierte los modificadores de stats de un efecto al expirar/remover.
func _remover_modificador_stats(tipo: StatusEffect.Tipo) -> void:
	if not _unidad or not _unidad.stats:
		return
	if not _modificadores_aplicados.has(tipo):
		return

	var mods: Dictionary = _modificadores_aplicados[tipo]

	if mods.has("physical_damage"):
		_unidad.stats.physical_damage = maxi(0, _unidad.stats.physical_damage - mods["physical_damage"])

	if mods.has("magic_damage"):
		_unidad.stats.magic_damage = maxi(0, _unidad.stats.magic_damage - mods["magic_damage"])

	if mods.has("evasion"):
		_unidad.stats.evasion = clampf(_unidad.stats.evasion - mods["evasion"], 0.0, 1.0)

	_modificadores_aplicados.erase(tipo)
	_unidad.stats.notify_stats_changed()
	print("[StatusEffectManager] %s: stats revertidos al remover %s" % [
		_unidad.display_name if _unidad else "?",
		StatusEffect.DATOS_EFECTO.get(tipo, {}).get("nombre", "?")])
