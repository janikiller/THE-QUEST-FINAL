# THE QUEST FINAL — Comisaría (Godot 4.7.2)

Gestiona una comisaría sobre el **mapa real de la ciudad**: misiones en distritos, centralita, despacho por radio y pestañas Mapa / Misiones / Patrullas.

## Requisitos

- **Godot 4.7.2** (Standard, no hace falta Mono)  
  Descarga: https://godotengine.org/download/archive/4.7.2-stable/

## Abrir

1. Instala / abre **Godot 4.7.2**
2. **Importar** → carpeta `godot/` de este repo
3. Selecciona `project.godot` → **Importar y editar**
4. **F5**

**No hace falta crear nodos.**

Si Godot avisa de conversión de versión, acepta. Los assets se reimportan solos la primera vez.

## Imágenes usadas

| Archivo | Uso |
|---|---|
| `assets/map/city_map.jpg` | Mapa jugable |
| `assets/ui/mockups/missions_list.jpg` | Referencia UI Misiones |
| `assets/ui/mockups/mission_detail.jpg` | Referencia UI detalle táctico |
| `assets/ui/mockups/patrols_inventory.jpg` | Referencia UI Patrullas |

## Cómo jugar

1. **MAPA** — ciudad completa; marcadores de misión; panel derecho + radio  
2. Click marcador o lista → briefing  
3. Elige patrulla → **Transmitir por radio**  
4. **MISIONES** — filtros (urgentes, delitos, tráfico…) y lista  
5. Informe táctico: opciones (cauteloso / entrada / negociar / bloquear) + confirmar  
6. **PATRULLAS** — unidades, agentes y estado  

Rueda del ratón = zoom · botón central = pan · Esc = limpiar selección

## Controles de cámara

- Rueda: zoom  
- Clic medio + arrastrar: mover mapa  
