extends RefCounted
class_name StatusEffect
##
## Efecto de estado individual. Cada instancia representa un efecto activo
## sobre una unidad (veneno, stun, buff, etc.).
##
## Para agregar un efecto nuevo:
##   1. Añadir entrada en enum Tipo
##   2. Añadir entrada en DATOS_EFECTO (emoji, nombre, color)
##   3. Clasificarlo en EFECTOS_BUFF o EFECTOS_DEBUFF
##   4. Implementar su lógica en StatusEffectManager o el hook correspondiente
##

## ═══════════════════════════════════════════════════════════
## Enum de tipos de efectos de estado.
## ═══════════════════════════════════════════════════════════
enum Tipo {
	VENENO,               ## 🟢 Daño mágico por turno. X turnos.
	STUN,                 ## ⚡ Pierde el turno completo. 1-2 turnos.
	CONFUSION,            ## 🌀 Acciones aleatorias + friendly fire. X turnos.
	SANGRADO,             ## 🩸 Daño físico por turno. X turnos.
	FUERZA,               ## 💪 +physical_damage temporal. X turnos.
	POTENCIACION_MAGICA,  ## 🔮 +magic_damage temporal. X turnos.
	ESPINAS,              ## 🌵 Refleja potencia fija al ser golpeado. X turnos.
	ESPEJO,               ## 🪞 Refleja 100% del daño recibido al atacante. X turnos.
	QUEMADURA,            ## 🔥 Daño mágico por turno (fuego). X turnos.
	ELECTROCUTADO,        ## ⚡ Penalización drástica al hit_chance del atacante. X turnos.
	ENREDADO,             ## 🌿 No puede moverse (SP=0 para movimiento). X turnos.
	SIGILO,               ## 👤 No targeteable por ataques single-target. X turnos.
	ENFERMEDAD,           ## 🤢 No puede curarse con pociones/hechizos. X turnos.
	EVASION_MEJORADA,     ## 🦅 +evasion% temporal. X turnos.
}


## ═══════════════════════════════════════════════════════════
## Datos estáticos por tipo: emoji, nombre para UI, color popup.
## ═══════════════════════════════════════════════════════════
const DATOS_EFECTO: Dictionary = {
	Tipo.VENENO: {
		"emoji": "🟢",
		"nombre": "Veneno",
		"color": Color(0.2, 0.85, 0.2),
	},
	Tipo.STUN: {
		"emoji": "⚡",
		"nombre": "Aturdido",
		"color": Color(1.0, 0.9, 0.2),
	},
	Tipo.CONFUSION: {
		"emoji": "🌀",
		"nombre": "Confusión",
		"color": Color(0.8, 0.4, 1.0),
	},
	Tipo.SANGRADO: {
		"emoji": "🩸",
		"nombre": "Sangrado",
		"color": Color(0.85, 0.15, 0.15),
	},
	Tipo.FUERZA: {
		"emoji": "💪",
		"nombre": "Fuerza",
		"color": Color(1.0, 0.6, 0.2),
	},
	Tipo.POTENCIACION_MAGICA: {
		"emoji": "🔮",
		"nombre": "Pot. Mágica",
		"color": Color(0.6, 0.3, 1.0),
	},
	Tipo.ESPINAS: {
		"emoji": "🌵",
		"nombre": "Espinas",
		"color": Color(0.4, 0.7, 0.2),
	},
	Tipo.ESPEJO: {
		"emoji": "🪞",
		"nombre": "Espejo",
		"color": Color(0.7, 0.85, 1.0),
	},
	Tipo.QUEMADURA: {
		"emoji": "🔥",
		"nombre": "Quemadura",
		"color": Color(1.0, 0.4, 0.1),
	},
	Tipo.ELECTROCUTADO: {
		"emoji": "⚡",
		"nombre": "Electrocutado",
		"color": Color(0.9, 0.9, 0.3),
	},
	Tipo.ENREDADO: {
		"emoji": "🌿",
		"nombre": "Enredado",
		"color": Color(0.3, 0.7, 0.3),
	},
	Tipo.SIGILO: {
		"emoji": "👤",
		"nombre": "Sigilo",
		"color": Color(0.5, 0.5, 0.6),
	},
	Tipo.ENFERMEDAD: {
		"emoji": "🤢",
		"nombre": "Enfermedad",
		"color": Color(0.6, 0.75, 0.1),
	},
	Tipo.EVASION_MEJORADA: {
		"emoji": "🦅",
		"nombre": "Evasión+",
		"color": Color(0.3, 0.8, 0.9),
	},
}


## ═══════════════════════════════════════════════════════════
## Clasificaciones automáticas para lógica del manager.
## ═══════════════════════════════════════════════════════════

## Efectos que causan daño al inicio de cada turno (DoT).
const EFECTOS_DANO_POR_TURNO: Array = [
	Tipo.VENENO,
	Tipo.SANGRADO,
	Tipo.QUEMADURA,
]

## Efectos positivos (buffs) — benefician a la unidad.
const EFECTOS_BUFF: Array = [
	Tipo.FUERZA,
	Tipo.POTENCIACION_MAGICA,
	Tipo.ESPINAS,
	Tipo.ESPEJO,
	Tipo.SIGILO,
	Tipo.EVASION_MEJORADA,
]

## Efectos negativos (debuffs) — perjudican a la unidad.
const EFECTOS_DEBUFF: Array = [
	Tipo.VENENO,
	Tipo.STUN,
	Tipo.CONFUSION,
	Tipo.SANGRADO,
	Tipo.QUEMADURA,
	Tipo.ELECTROCUTADO,
	Tipo.ENREDADO,
	Tipo.ENFERMEDAD,
]


## ═══════════════════════════════════════════════════════════
## Propiedades de instancia
## ═══════════════════════════════════════════════════════════

## Tipo de efecto (del enum Tipo).
var tipo: Tipo

## Turnos restantes antes de expirar. Se decrementa al inicio de cada turno.
var duracion_restante: int

## Potencia del efecto. Significado varía según tipo:
##   DoT (veneno/sangrado/quemadura): daño por turno.
##   Buff (fuerza/pot. mágica): cantidad añadida al stat.
##   Espinas: daño fijo reflejado al atacante.
##   Electrocutado: penalización a hit_chance (en porcentaje, ej: 30 = -30%).
##   Evasión mejorada: porcentaje añadido (ej: 20 = +0.20 evasion).
var potencia: int

## Referencia a la unidad que aplicó el efecto (para espejo/espinas/confusion).
## Puede ser null si fue aplicado por una poción (auto-buff).
var unidad_fuente = null  # Unit o null


func _init(p_tipo: int = 0, p_duracion: int = 1, p_potencia: int = 0, p_fuente = null) -> void:
	tipo = p_tipo as Tipo
	duracion_restante = maxi(1, p_duracion)
	potencia = maxi(0, p_potencia)
	unidad_fuente = p_fuente


## Devuelve el emoji asociado al tipo de efecto.
func obtener_emoji() -> String:
	if DATOS_EFECTO.has(tipo):
		return DATOS_EFECTO[tipo].get("emoji", "?")
	return "?"


## Devuelve el nombre legible para UI.
func obtener_nombre() -> String:
	if DATOS_EFECTO.has(tipo):
		return DATOS_EFECTO[tipo].get("nombre", "Desconocido")
	return "Desconocido"


## Devuelve el color para popups flotantes.
func obtener_color() -> Color:
	if DATOS_EFECTO.has(tipo):
		return DATOS_EFECTO[tipo].get("color", Color.WHITE)
	return Color.WHITE


## Devuelve true si este efecto es un buff (positivo).
func es_buff() -> bool:
	return tipo in EFECTOS_BUFF


## Devuelve true si este efecto es un debuff (negativo).
func es_debuff() -> bool:
	return tipo in EFECTOS_DEBUFF


## Devuelve true si el efecto ya expiró (duracion_restante <= 0).
func expirado() -> bool:
	return duracion_restante <= 0
