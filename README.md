# THE QUEST FINAL

RPG isométrico con personaje policial modular (paper-doll).

## Assets del personaje

Convertidos desde la lámina de referencia a sprites usables:

| Carpeta | Contenido |
|---|---|
| `assets/character/animations/` | 32 frames · 4 direcciones · idle / caminar / correr / disparar |
| `assets/character/heads/` | Gorra azul, pelos, gorra blanca, pasamontañas |
| `assets/character/uniforms/` | Chaleco azul, alta visibilidad, táctico negro, camisa beige |
| `assets/character/pants/` | Azul, negro, beige, navy |
| `assets/character/back/` | Antena, mochila, botiquín, cuerda |
| `assets/character/belt/` | Funda, taser, porra, esposas, radio, linterna, bolsa |
| `assets/character/variants/` | Variantes de color (espalda) |
| `assets/character/examples/` | Presets finales (patrulla, SWAT, tráfico, K9, especial) |
| `assets/vehicle/` | Patrulla + movimiento + variantes (Policía, Guardia Civil, Tráfico, UPR) |

Datos de juego en `data/`:

- `character.json` — definición del sistema paper-doll
- `character_animations.json` — atlas de animaciones
- `character_parts.json` — catálogo de piezas
- `character_variants.json` — colores y ejemplos
- `presets.json` — loadouts listos
- `vehicle.json` — patrulla

## Preview

```bash
python3 -m http.server 8080
```

Abre `http://localhost:8080/public/` para:

1. **Personalizar** — presets + piezas modulares
2. **Animaciones** — idle / caminar / correr / disparar en 4 direcciones
3. **Patrulla** — vehículo y variantes

## Código

- `src/PoliceCharacter.js` — controlador del personaje (animaciones + capas)
- `public/app.js` — constructor visual

## Uso rápido en tu motor

```js
import { PoliceCharacter } from "./src/PoliceCharacter.js";

const character = new PoliceCharacter({
  animations: await fetch("./data/character_animations.json").then((r) => r.json()),
  parts: await fetch("./data/character_parts.json").then((r) => r.json()),
  loadout: {
    head: "cap_blue",
    uniform: "vest_blue",
    pants: "pants_blue",
    back: null,
    belt: ["holster", "radio"],
  },
});

character.setDirection("front");
character.play("run");
const framePath = character.update(1 / 60); // → character/animations/front_run_N.png
```
