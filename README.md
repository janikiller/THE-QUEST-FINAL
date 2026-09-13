# THE QUEST FINAL

Roguelike policial de cartas en Godot 4.7.2. **Una patrulla (García)** interviene en misiones del mapa.

## CRESPO — Supervivencia zombie (ciudad)

Ciudad procedural **Niebla Norte**: [`survival/`](survival/). Calles, saqueo, zombies y base construible.

```bash
python3 -m http.server 8080
# http://localhost:8080/survival/
```

## Jugar (Godot)

```bash
# Godot 4.7.2 → Import → carpeta godot/ → F5
# https://godotengine.org/download/archive/4.7.2-stable/
```

- **Clic en una misión** → empieza el combate de cartas
- **I** → mazo · **M** → lista de misiones · WASD mapa

Detalle: [`godot/README.md`](godot/README.md)

## Importante si usas el ZIP de GitHub

Abre siempre la carpeta `godot/` (no la raíz). Si aún ves inventario antiguo, estás en una descarga vieja de `main`: usa el PR/rama de combate de cartas o actualiza `main` tras el merge.
