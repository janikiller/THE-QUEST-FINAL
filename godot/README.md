# THE QUEST FINAL — Comisaría (Godot 4.3)

Gestiona una comisaría en 2D: mapa de ciudad, misiones que aparecen solas, revisión en centralita y **despacho de patrullas por radio**.

## Abrir el proyecto

1. Instala **Godot 4.3+** (Standard, no hace falta Mono).
2. En Godot: **Import** → carpeta `godot/` de este repo.
3. Pulsa **F5** (o Play).

No tienes que crear nodos: escenas, scripts y autoloads ya están cableados.

## Cómo se juega

1. En el mapa aparecen marcadores de misión (Barrio Norte: Centro, Puerto, Residencial, Industrial, Avenida Lumen).
2. Click en un marcador (o en la lista de la derecha) para **revisar** la misión (imagen + briefing).
3. Elige una patrulla **disponible**.
4. Pulsa **Transmitir por radio · Enviar patrulla**.
5. La unidad va al punto, reporta por radio y vuelve a la comisaría.
6. Ganas **prestigio** si la intervención sale bien (bonus si la especialidad de la unidad coincide con la categoría).

## Controles

- Click: seleccionar misión / UI
- **Esc**: limpiar selección

## Estructura

```
godot/
  project.godot
  autoload/          GameState + RadioBus
  scenes/            main, city_map, markers, patrols, UI
  scripts/           lógica de mapa, spawner, despacho, HUD
  data/              station.json + catálogo de eventos
  assets/            tiles de misión + retratos de unidades
```

## Notas

- El catálogo de eventos reutiliza los tiles de `assets/events`.
- Si Godot pide reimportar texturas al abrir, acepta: es normal la primera vez.
