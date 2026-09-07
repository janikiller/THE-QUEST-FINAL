# THE QUEST FINAL

RPG isométrico policial. Este branch añade el catálogo de **Eventos en la ciudad** listo para usar en el juego.

## Assets de eventos

Convertidos desde la lámina de referencia a tiles usables:

| Carpeta | Contenido |
|---|---|
| `assets/events/tiles/` | 70 escenarios · 7 categorías × 10 eventos |
| `assets/events/categories/` | 7 tarjetas de categoría (Delitos, Emergencias, Tráfico, Civiles, Organizado, Clima, Especiales) |
| `assets/source/city_events_reference.jpg` | Lámina original |

Datos de juego en `data/`:

- `events.json` — catálogo completo (severidad, unidades, XP, duración, ruta del tile)
- `event_categories.json` — categorías + color + lista de IDs
- `events_index.json` — índice rápido `byId` / `byCategory`

## Preview (centralita)

```bash
python3 -m http.server 8080
```

Abre `http://localhost:8080/public/events.html` para:

1. Filtrar por categoría
2. Seleccionar un evento y **despacharlo** como misión activa
3. Aplicar clima de ciudad
4. Generar un evento aleatorio

## Código

- `src/CityEvents.js` — despachador de eventos / clima / resolución de misiones
- `scripts/slice_city_events.py` — re-corta la lámina si cambia la referencia
- `public/events-app.js` — centralita visual

## Uso rápido en tu motor

```js
import { CityEvents } from "./src/CityEvents.js";

const city = new CityEvents({
  catalog: await fetch("./data/events.json").then((r) => r.json()),
  categories: await fetch("./data/event_categories.json").then((r) => r.json()),
});

// Misión
const heist = city.dispatch("atraco_a_banco");
console.log(heist.location, heist.units, heist.xp);

// Clima
city.setWeather("tormenta_electrica");

// Aleatorio de una categoría
city.dispatchRandom({ category: "trafico" });

// Resolver
city.resolve(heist.instanceId, { success: true });
```

## Categorías

1. **Delitos** — robos, peleas, secuestro…
2. **Emergencias** — incendios, explosión, derrumbe…
3. **Tráfico** — controles, persecución, atropello…
4. **Civiles** — desaparecidos, crisis, auxilio…
5. **Organizado** — lab ilegal, redada, contrabando…
6. **Clima** — lluvia, niebla, ola de calor… (afecta atmósfera)
7. **Eventos especiales** — concierto, feria, operación especial…
