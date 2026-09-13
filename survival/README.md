# CRESPO — Niebla Norte

Supervivencia zombie en ciudad 2D inventada.

Eres **Crespo** en **Niebla Norte**: calles, manzanas, canal y muertos. Saquea, construye una base y aguanta la noche.

## Jugar

```bash
python3 -m http.server 8080
# http://localhost:8080/survival/
# http://localhost:8080/survival/?auto=1
```

## Controles

| Tecla | Acción |
|-------|--------|
| WASD | Mover |
| Espacio | Correr (hace ruido) |
| Ratón | Apuntar |
| Clic izq. | Disparar (o melee si no hay arma de fuego) |
| E | Saquear / registrar muebles / beber del canal |
| Q / F | Cuerpo a cuerpo (culatazo si llevas arma de fuego) |
| R | Consumir (botiquín → comida → agua) |
| 1-5 | Equipar arma de la hotbar |
| T | Ciclar ropa → mochila → luz |
| B | Ciclo de construcción (barricada / puerta / base) |
| Enter | Colocar construcción |
| 0 / Esc | Cancelar construcción |

## Sistemas

- Ciudad procedural (calles, edificios, parques, parking, canal)
- Día/noche, clima y farolas
- Oleadas de zombis cada vez más duras
- Armas melee y de fuego con munición
- Ropa visible, mochila y linterna/farol equipables
- Base: marca suelo, cercála con barricadas y puerta
