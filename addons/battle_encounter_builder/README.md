# Battle Encounter Builder

Plugin de editor para crear y editar encuentros de batalla (tablero, unidades, obstáculos, suelos).

## Activar el plugin

1. Project > Project Settings > Plugins
2. Activar **Battle Encounter Builder**

## Uso

1. **Abrir:** Project > Battle Encounter Builder (o usar el dock lateral derecho)
2. **Config:** Cargar un `.tres` existente o "New" para crear uno nuevo
3. **Board:** Ajustar width, height, tile_size y seed
4. **Players / Enemies:** "Add Player" / "Add Enemy" para añadir spawns. "Auto-fill 1" para rellenar automáticamente
5. **Obstacles:** Modo manual/random/pattern y densidad
6. **Floors:** Modo single/weighted/manual
7. **Generate Preview:** Genera el encuentro y lo aplica a la escena abierta (si tiene BattleBoard y Units)
8. **Bake to Scene:** Escribe tiles y unidades en la escena actual (con undo)
9. **Clear Generated:** Elimina los nodos generados por el plugin
10. **Save:** Guardar el BattleEncounterConfig como `.tres`

## Requisitos

- Escena abierta con nodos `BattleBoard` (y `BattleBoard/Tiles`) y `Units` (hermano de BattleBoard).
- Ejemplo: `BattleScene.tscn`

## Generar un encuentro en BattleScene

1. Abrir `scenes/battle/BattleScene.tscn`
2. En el dock Battle Encounter Builder: New o Load `data/battles/configs/encounter_test_4x4.tres`
3. Ajustar parámetros si se desea
4. Pulsar **Bake to Scene**
5. (Opcional) Si quieres usar el layout baked en runtime: en el Inspector de BattleScene, desasignar `battle_config` (dejarlo vacío). Así BattleFlow usará los nodos baked en lugar de regenerar.
6. Guardar la escena (Ctrl+S)

## Rutas de assets

- Unidades: `res://scenes/units/`
- Pisos: `res://scenes/floors/` y `res://assets/KayKit_DungeonRemastered_1.1_FREE/Assets/gltf/`
- Si no hay assets, se usa fallback (PlaneMesh)
