# CRESPO — Niebla Norte

Supervivencia zombie en ciudad 2D inventada.

Eres **Crespo** en **Niebla Norte**: calles, manzanas, canal y muertos. Saquea, construye una base y aguanta la noche.

## Jugar

```bash
python3 -m http.server 8080
# http://localhost:8080/survival/
```

## Controles

| Tecla | Acción |
|-------|--------|
| WASD | Mover |
| Espacio | Correr (hace ruido) |
| E | Saquear / beber del canal |
| Q | Golpear con tubería |
| R | Consumir (botiquín → comida → agua) |
| 1 | Modo barricada |
| 2 | Modo puerta |
| 3 | Marcar base |
| B | Colocar construcción |
| 0 / Esc | Cancelar construcción |

## Sistemas

- Ciudad procedural (calles, edificios, parques, parking, canal)
- Zombies de día y peores de noche
- Base: marca suelo, cercála con barricadas y puerta
- Los zombies no cruzan puertas sanas; pueden romperlas
- Inventario: latas, agua, chatarra, tablas, botiquín
