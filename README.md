# THE QUEST FINAL

RPG / simulación policial. Hay dos superficies:

## 1) Godot — Comisaría (juego principal 2D)

Carpeta [`godot/`](godot/): gestiona una comisaría sobre el **mapa real de la ciudad**, con pestañas **Mapa / Misiones / Patrullas**, misiones por distrito y despacho por radio.

```bash
# Abre Godot 4.3+ → Import → selecciona la carpeta godot/
# Luego F5
```

**No tienes que crear nodos.** Escenas, scripts y autoloads ya están en el proyecto.

Imágenes incluidas: mapa de ciudad + mockups de UI en `godot/assets/`.

Detalle: [`godot/README.md`](godot/README.md)

## 2) Web preview (narrativa Portal 3)

La carpeta `public/` tiene un prototipo HTML del caso narrativo / inventario (servidor local):

```bash
python3 -m http.server 8080
# http://localhost:8080/public/
```

## Assets

- `assets/character/` — personaje policial modular  
- `assets/events/` — tiles de incidentes urbanos  
- `godot/assets/` — copia usada por el juego Godot  
