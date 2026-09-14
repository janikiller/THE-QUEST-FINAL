# CRESPO — Niebla Norte

Supervivencia zombie en ciudad 2D inventada.

Eres **Crespo** en **Niebla Norte**: calles, manzanas, canal y muertos. Saquea, construye una base y aguanta la noche.

## Jugar

```bash
python3 -m http.server 8080
# http://localhost:8080/survival/
# http://localhost:8080/survival/?auto=1
# Clima forzado (ambiente + audio):
# ?weather=sandstorm | storm | rain | wind | fog
```

## Ambiente

Clima dinámico con **viento**, **lluvia**, **tormentas**, **tormentas de arena** y ráfagas.
Audio procedural (Web Audio): viento, lluvia, truenos y arena — se activa al empezar.

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
| I | Abrir / cerrar inventario |
| T | Ciclar ropa → mochila → luz |
| B | Ciclo de construcción (barricada / puerta / base) |
| Enter | Colocar construcción |
| 0 / Esc | Cancelar construcción / cerrar inventario |

## Sistemas

- Ciudad procedural apocalíptica (calles rotas, escombros, niebla)
- Día/noche, clima (niebla, lluvia, tormenta) y farolas
- Oleadas de zombis cada vez más duras
- **Jefes cada 3 oleadas** (El Bruto, El Aullador, El Blindado)
- Armas melee y de fuego con munición
- Inventario con **I** (no ocupa el HUD)
- Ropa visible, mochila y linterna/farol equipables
- Base: marca suelo, cercála con barricadas y puerta

## Debug rápido (jefes)

```bash
# Salta cerca de la oleada 3 (con jefe) y acorta timers
http://localhost:8080/survival/?auto=1&boss=1&fastwaves=1
```
