# Turnos3D

Juego de combate por turnos en 3D desarrollado con **Godot 4.5**.

## Descripción

Turnos3D es un juego de batalla por turnos donde el jugador controla un equipo de unidades contra enemigos. El orden de turnos se determina por la velocidad (iniciativa) de cada unidad. En cada turno del jugador puedes seleccionar un objetivo enemigo para atacar o pasar el turno.

## Características

- **Sistema de combate por turnos**: Orden de turnos basado en velocidad/iniciativa
- **Unidades jugador y enemigo**: Cada equipo con sus propias estadísticas (HP, ataque, velocidad)
- **Animaciones**: Movimiento hacia el objetivo, animación de ataque y efectos visuales (flash al recibir daño, muerte)
- **IA de enemigos**: Los enemigos atacan al jugador con menor HP
- **UI de batalla**: Timeline de turnos, selección de objetivos, panel de opciones

## Requisitos

- [Godot Engine 4.5](https://godotengine.org/) o superior

## Cómo ejecutar

1. Clona el repositorio
2. Abre el proyecto con Godot 4.5
3. Presiona F5 o el botón "Play" para ejecutar

## Estructura del proyecto

```
├── autoload/          # Settings (configuración global)
├── scenes/            # Escenas principales (MainMenu, Battle, Units)
├── scripts/
│   ├── combat/        # CombatManager - lógica de batalla
│   ├── data/          # UnitData - recurso de datos
│   ├── ui/            # BattleUI, MainMenu, OptionsPanel, TurnSlot
│   └── units/         # Unit, PlayerUnit, EnemyUnit
└── project.godot
```

## Licencia

Proyecto de código abierto.
