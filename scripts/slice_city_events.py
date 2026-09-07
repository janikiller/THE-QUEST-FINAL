#!/usr/bin/env python3
"""Slice the city-events reference sheet into usable per-event tiles."""
from __future__ import annotations

import json
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "assets" / "source" / "city_events_reference.jpg"
OUT = ROOT / "assets" / "events"
DATA = ROOT / "data"

# Row bands (inclusive start, exclusive end) measured from the reference sheet.
BANDS = [
    (46, 156),
    (189, 305),
    (335, 443),
    (476, 576),
    (607, 705),
    (737, 813),
    (843, 939),
]

CAT_END = 117  # first pixel of event tiles

CATEGORIES = [
    {
        "id": "delitos",
        "name": "Delitos",
        "tagline": "El crimen nunca descansa",
        "color": "#2f6bff",
        "icon": "shield",
        "events": [
            ("robo_en_tienda", "Robo en tienda", "high", ["policia"], 120),
            ("atraco_a_banco", "Atraco a banco", "critical", ["policia", "swat"], 300),
            ("robo_de_vehiculo", "Robo de vehículo", "medium", ["policia"], 90),
            ("violencia_domestica", "Violencia doméstica", "high", ["policia"], 150),
            ("pelea_en_la_calle", "Pelea en la calle", "medium", ["policia"], 60),
            ("venta_de_drogas", "Venta de drogas", "medium", ["policia"], 120),
            ("vandalismo", "Vandalismo", "low", ["policia"], 45),
            ("robo_en_vivienda", "Robo en vivienda", "high", ["policia"], 150),
            ("secuestro", "Secuestro", "critical", ["policia", "swat"], 360),
            ("huida_de_la_ley", "Huida de la ley", "high", ["policia", "trafico"], 180),
        ],
    },
    {
        "id": "emergencias",
        "name": "Emergencias",
        "tagline": "Cuando cada segundo cuenta",
        "color": "#e23a3a",
        "icon": "flame",
        "events": [
            ("incendio_de_coche", "Incendio de coche", "high", ["bomberos"], 90),
            ("incendio_en_edificio", "Incendio en edificio", "critical", ["bomberos", "samur"], 300),
            ("explosion", "Explosión", "critical", ["bomberos", "policia", "samur"], 240),
            ("fuga_de_gas", "Fuga de gas", "high", ["bomberos"], 120),
            ("accidente_multiple", "Accidente múltiple", "high", ["samur", "policia", "trafico"], 180),
            ("persona_atrapada", "Persona atrapada", "critical", ["bomberos", "samur"], 180),
            ("arbol_caido", "Árbol caído", "medium", ["bomberos", "trafico"], 90),
            ("inundacion", "Inundación", "high", ["bomberos", "policia"], 200),
            ("apagon", "Apagón", "medium", ["policia"], 120),
            ("derrumbe", "Derrumbe", "critical", ["bomberos", "samur", "policia"], 300),
        ],
    },
    {
        "id": "trafico",
        "name": "Tráfico",
        "tagline": "En movimiento, también hay riesgos",
        "color": "#2faf5a",
        "icon": "car",
        "events": [
            ("control_de_trafico", "Control de tráfico", "low", ["trafico"], 60),
            ("exceso_de_velocidad", "Exceso de velocidad", "low", ["trafico"], 45),
            ("accidente_leve", "Accidente leve", "medium", ["trafico", "policia"], 75),
            ("vuelco", "Vuelco", "high", ["trafico", "samur", "bomberos"], 150),
            ("atropello", "Atropello", "critical", ["samur", "policia", "trafico"], 180),
            ("conduccion_temeraria", "Conducción temeraria", "medium", ["trafico"], 60),
            ("persecucion", "Persecución", "critical", ["policia", "trafico"], 200),
            ("vehiculo_averiado", "Vehículo averiado", "low", ["trafico"], 45),
            ("conductor_ebrio", "Conductor ebrio", "high", ["trafico", "policia"], 90),
            ("camion_en_problemas", "Camión en problemas", "medium", ["trafico", "bomberos"], 120),
        ],
    },
    {
        "id": "civiles",
        "name": "Civiles",
        "tagline": "La gente también necesita ayuda",
        "color": "#9b4dff",
        "icon": "people",
        "events": [
            ("persona_desaparecida", "Persona desaparecida", "high", ["policia"], 240),
            ("persona_perdida", "Persona perdida", "medium", ["policia"], 90),
            ("persona_agresiva", "Persona agresiva", "high", ["policia"], 90),
            ("persona_en_crisis", "Persona en crisis", "high", ["policia", "samur"], 120),
            ("auxilio_medico", "Auxilio médico", "high", ["samur"], 90),
            ("animal_suelto", "Animal suelto", "low", ["policia", "k9"], 60),
            ("menor_sin_supervision", "Menor sin supervisión", "medium", ["policia"], 75),
            ("persona_intoxicada", "Persona intoxicada", "medium", ["samur", "policia"], 75),
            ("intento_de_suicidio", "Intento de suicidio", "critical", ["policia", "samur"], 180),
            ("manifestacion", "Manifestación", "medium", ["policia", "upr"], 180),
        ],
    },
    {
        "id": "organizado",
        "name": "Organizado",
        "tagline": "Detrás de cada caso hay algo más",
        "color": "#e0b12a",
        "icon": "mask",
        "events": [
            ("reunion_sospechosa", "Reunión sospechosa", "medium", ["policia"], 120),
            ("laboratorio_ilegal", "Laboratorio ilegal", "critical", ["policia", "swat"], 300),
            ("transporte_de_armas", "Transporte de armas", "critical", ["policia", "swat"], 240),
            ("redada", "Redada", "critical", ["swat", "policia"], 240),
            ("seguimiento", "Seguimiento", "medium", ["policia"], 180),
            ("casa_segura", "Casa segura", "high", ["policia", "swat"], 200),
            ("contrabando", "Contrabando", "high", ["policia", "trafico"], 180),
            ("ciberdelito", "Ciberdelito", "medium", ["policia"], 150),
            ("corrupcion", "Corrupción", "high", ["policia"], 240),
            ("trata_de_personas", "Trata de personas", "critical", ["policia", "swat"], 360),
        ],
    },
    {
        "id": "clima",
        "name": "Clima",
        "tagline": "El tiempo también afecta",
        "color": "#4eb7ff",
        "icon": "cloud",
        "events": [
            ("dia_soleado", "Día soleado", "low", [], 0),
            ("lluvia", "Lluvia", "low", ["trafico"], 0),
            ("tormenta_electrica", "Tormenta eléctrica", "medium", ["bomberos", "trafico"], 0),
            ("niebla", "Niebla", "medium", ["trafico"], 0),
            ("nieve", "Nieve", "medium", ["trafico"], 0),
            ("viento_fuerte", "Viento fuerte", "medium", ["bomberos", "trafico"], 0),
            ("ola_de_calor", "Ola de calor", "medium", ["samur"], 0),
            ("tormenta_tropical", "Tormenta tropical", "high", ["bomberos", "policia", "trafico"], 0),
            ("granizo", "Granizo", "medium", ["trafico"], 0),
            ("inundaciones", "Inundaciones", "high", ["bomberos", "policia"], 0),
        ],
    },
    {
        "id": "especiales",
        "name": "Eventos especiales",
        "tagline": "La ciudad siempre se mueve",
        "color": "#ff7a2f",
        "icon": "calendar",
        "events": [
            ("concierto", "Concierto", "medium", ["policia", "upr"], 240),
            ("evento_deportivo", "Evento deportivo", "medium", ["policia", "upr", "samur"], 240),
            ("feria", "Feria", "low", ["policia"], 180),
            ("desfile", "Desfile", "medium", ["policia", "upr", "trafico"], 180),
            ("visita_oficial", "Visita oficial", "high", ["policia", "swat", "upr"], 300),
            ("protesta", "Protesta", "high", ["policia", "upr"], 200),
            ("obras", "Obras", "low", ["trafico"], 120),
            ("festivo", "Festivo", "low", ["policia"], 180),
            ("accidente_portuario", "Accidente portuario", "critical", ["bomberos", "samur", "policia"], 300),
            ("operacion_especial", "Operación especial", "critical", ["swat", "policia"], 360),
        ],
    },
]

SEVERITY_XP = {
    "low": 25,
    "medium": 50,
    "high": 100,
    "critical": 200,
}


def crop_inset(im: Image.Image, inset: int = 2) -> Image.Image:
    if inset <= 0:
        return im
    return im.crop((inset, inset, im.width - inset, im.height - inset))


def main() -> None:
    img = Image.open(SRC).convert("RGB")
    w, h = img.size
    tile_w = (w - 2 - CAT_END) / 10

    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / "categories").mkdir(parents=True, exist_ok=True)
    (OUT / "tiles").mkdir(parents=True, exist_ok=True)

    categories_out = []
    events_out = []

    for row_idx, (cat, (y0, y1)) in enumerate(zip(CATEGORIES, BANDS)):
        cat_dir = OUT / "tiles" / cat["id"]
        cat_dir.mkdir(parents=True, exist_ok=True)

        cat_img = crop_inset(img.crop((2, y0, CAT_END, y1)), 1)
        cat_file = f"events/categories/{cat['id']}.png"
        cat_img.save(OUT / "categories" / f"{cat['id']}.png")

        cat_entry = {
            "id": cat["id"],
            "name": cat["name"],
            "tagline": cat["tagline"],
            "color": cat["color"],
            "icon": cat["icon"],
            "file": cat_file,
            "w": cat_img.width,
            "h": cat_img.height,
            "row": row_idx,
            "eventIds": [],
        }

        for col_idx, (eid, title, severity, units, duration) in enumerate(cat["events"]):
            x0 = int(CAT_END + col_idx * tile_w)
            x1 = int(CAT_END + (col_idx + 1) * tile_w)
            tile = crop_inset(img.crop((x0, y0, x1, y1)), 2)
            rel = f"events/tiles/{cat['id']}/{eid}.png"
            tile.save(ROOT / "assets" / rel)

            event = {
                "id": eid,
                "name": title,
                "category": cat["id"],
                "severity": severity,
                "units": units,
                "durationSec": duration,
                "xp": SEVERITY_XP[severity],
                "file": rel,
                "w": tile.width,
                "h": tile.height,
                "row": row_idx,
                "col": col_idx,
                "dispatchable": cat["id"] != "clima",
                "weather": cat["id"] == "clima",
            }
            events_out.append(event)
            cat_entry["eventIds"].append(eid)

        categories_out.append(cat_entry)
        print(f"sliced {cat['id']}: {len(cat['events'])} tiles")

    DATA.mkdir(parents=True, exist_ok=True)

    events_catalog = {
        "id": "city_events",
        "name": "Eventos en la ciudad",
        "tagline": "Una ciudad viva, llena de historias",
        "mission": "Hacer una ciudad más segura",
        "source": "assets/source/city_events_reference.jpg",
        "grid": {"rows": 7, "cols": 10},
        "count": len(events_out),
        "categoriesSource": "event_categories.json",
        "events": events_out,
    }
    (DATA / "events.json").write_text(
        json.dumps(events_catalog, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )

    categories_catalog = {
        "id": "city_event_categories",
        "categories": categories_out,
    }
    (DATA / "event_categories.json").write_text(
        json.dumps(categories_catalog, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )

    # Lightweight index for quick lookups in engine code.
    index = {
        "byId": {e["id"]: e for e in events_out},
        "byCategory": {
            c["id"]: [eid for eid in c["eventIds"]] for c in categories_out
        },
        "severities": list(SEVERITY_XP.keys()),
        "units": sorted(
            {u for e in events_out for u in e["units"]}
        ),
    }
    (DATA / "events_index.json").write_text(
        json.dumps(index, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )

    print(f"Wrote {len(events_out)} events and {len(categories_out)} categories")


if __name__ == "__main__":
    main()
