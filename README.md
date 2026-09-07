# THE QUEST FINAL

RPG policial isométrico / narrativa nocturna. Creas a tu agente, repartes **5 habilidades**, llevas un **inventario** con el personaje a la vista y resuelves el caso **Portal 3** con historia ramificada e imágenes.

## Jugar

```bash
python3 -m http.server 8080
```

Abre [http://localhost:8080/public/](http://localhost:8080/public/)

1. **Crear agente** — unidad, piezas, nombre y 5 puntos de habilidad  
2. **Barrio** — caso principal + misiones de centralita  
3. **Misión** — escenas con imagen, chequeos y ramas  
4. **Inventario (I)** — evidencia, pistas y cinturón  

Sin menús de coches. El personaje se ve con los sprites paper-doll / presets.

## Habilidades

| Habilidad | Uso |
|---|---|
| Persuasión | Hacer hablar, negociar |
| Intimidación | Imponer autoridad |
| Observación | Leer detalles y mentiras |
| Registro | Evidencia y cacheos |
| Táctica | Decisiones arriesgadas |

Suben al superar chequeos y misiones.

## Historia

**Portal 3** — Una tarjeta del Bar Lumen, un nombre (Iván), un portal que huele a lejía. Tus elecciones y habilidades cambian el desenlace.

## Estructura

- `public/` — juego (UI)
- `src/` — `GameState`, `StoryEngine`, `CharacterRenderer`, `PoliceCharacter`, `CityEvents`
- `data/` — personaje, eventos, skills, items, `story.json`
- `assets/character/` — sprites y piezas
- `assets/events/` — tiles de misión (sin coches en UI)

## Controles

- **I** inventario · **Esc** cerrar paneles
