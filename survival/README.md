# CRESPO — Valmora

Juego de supervivencia 2D inventado desde cero.

Despiertas como **Crespo** en la isla de **Valmora**. Cada partida genera un mapa nuevo: playas, pinos, ciénagas, riscos y ruinas.

## Jugar

```bash
# desde la raíz del repo
python3 -m http.server 8080
# abre http://localhost:8080/survival/?auto=1
```

O abre `survival/index.html` con un servidor local (módulos ES).

## Controles

| Tecla | Acción |
|-------|--------|
| WASD | Mover |
| Espacio | Correr |
| E | Recolectar / beber / comer bayas |
| F | Fogata (3 madera + 1 pedernal) |
| Q | Lanzar piedra a lobos |

## Sistemas

- Mapa procedural (ruido + biomas + recursos)
- Vida, hambre, sed, calor, resistencia
- Ciclo día / noche
- Lobos de noche
- Minimapa
