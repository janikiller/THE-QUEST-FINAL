extends Node2D
## Marcador de misión con badges tácticos enviados por el jugador (icono + etiqueta).

signal pressed(mission_id: String)

const BADGE_DIR := "res://assets/map/tactical_badges/"

var mission_id: String = ""
var _selected: bool = false
var _status: String = "open"
var _pulse: float = 0.0
var _badge_key: String = "incidente_activo"

@onready var hit: Button = $Hit
@onready var badge: Sprite2D = $Badge
@onready var label_panel: PanelContainer = $LabelPanel


func _ready() -> void:
	hit.pressed.connect(_on_pressed)
	hit.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if label_panel:
		label_panel.visible = false


func setup(mission: Dictionary) -> void:
	mission_id = mission["id"]
	position = mission["pos"]
	add_to_group("mission_marker")
	refresh(mission)


func refresh(mission: Dictionary) -> void:
	_status = str(mission.get("status", "open"))
	_badge_key = _badge_for_mission(mission)
	var path := BADGE_DIR + _badge_key + ".png"
	if badge:
		if ResourceLoader.exists(path):
			badge.texture = load(path) as Texture2D
			badge.visible = true
		else:
			# Fallback a incidente activo
			var fb := BADGE_DIR + "incidente_activo.png"
			if ResourceLoader.exists(fb):
				badge.texture = load(fb) as Texture2D
		badge.centered = true
		badge.position = Vector2(0, -8)
	_apply_badge_modulate()
	_layout_hit()
	set_selected(_selected)
	queue_redraw()


func set_selected(on: bool) -> void:
	_selected = on
	_apply_badge_modulate()
	queue_redraw()


func _apply_badge_modulate() -> void:
	if badge == null:
		return
	var base := Color(1, 1, 1, 1)
	if _status in ["dispatched", "resolving"]:
		base = Color(0.85, 0.92, 1.12, 1.0)
	elif _status == "resolved":
		base = Color(0.75, 1.0, 0.8, 1.0)
	elif _status == "failed":
		base = Color(0.55, 0.55, 0.55, 1.0)
	if _selected:
		base = base.lightened(0.08)
		badge.scale = Vector2(1.02, 1.02)
	else:
		badge.scale = Vector2(0.92, 0.92)
	badge.modulate = base


func _process(delta: float) -> void:
	_pulse += delta * 2.2
	if badge:
		badge.position.y = -8.0 + sin(_pulse) * 1.6
	queue_redraw()


func _draw() -> void:
	draw_circle(Vector2(0, 18), 16.0, Color(0, 0, 0, 0.28))
	if _selected:
		draw_circle(Vector2(0, -8), 42.0, Color(1, 1, 1, 0.08))


func _layout_hit() -> void:
	if hit == null:
		return
	var tw := 150.0
	var th := 128.0
	if badge and badge.texture:
		tw = float(badge.texture.get_width()) * badge.scale.x
		th = float(badge.texture.get_height()) * badge.scale.y
	hit.offset_left = -tw * 0.5
	hit.offset_top = -th * 0.72
	hit.offset_right = tw * 0.5
	hit.offset_bottom = th * 0.38


func _badge_for_mission(mission: Dictionary) -> String:
	var cat := str(mission.get("category", "")).to_lower()
	var eid := str(mission.get("event_id", "")).to_lower()
	var title := str(mission.get("title", "")).to_lower()
	var severity := str(mission.get("severity", "medium")).to_lower()
	var blob := eid + " " + title

	# Eventos concretos
	if "persecucion" in blob or "huida" in blob or "fuga" in blob:
		return "persecucion"
	if "incendio" in blob or "explosion" in blob or "fuga_de_gas" in blob:
		return "incendio"
	if "drogas" in blob or "laboratorio" in blob or "narco" in blob or "contrabando" in blob:
		return "narcotrafico"
	if "transporte_de_armas" in blob or "redada" in blob or "casa_segura" in blob:
		return "entrega_vigilada"
	if "control_de_trafico" in blob or "exceso" in blob or "velocidad" in blob:
		return "control"
	if "seguimiento" in blob or "reunion_sospechosa" in blob:
		return "seguimiento"
	if "auxilio" in blob or "medico" in blob or "crisis" in blob or "intoxic" in blob or "suicid" in blob:
		return "asistencia"
	if "desaparecida" in blob or "perdida" in blob or "ciber" in blob or "corrupcion" in blob:
		return "investigacion"
	if "aeropuerto" in blob:
		return "aeropuerto"
	if "portuario" in blob or "costera" in blob or "marit" in blob or "inundacion" in blob:
		return "zona_costera"
	if "operacion_especial" in blob or "visita_oficial" in blob:
		return "operacion_especial"
	if "escolta" in blob or "proteccion" in blob or "desfile" in blob or "visita" in blob:
		return "proteccion"
	if "registro" in blob or "redada" in blob or "entrada" in blob:
		return "registro"
	if "vigilancia" in blob or "edificio" in blob:
		return "vigilancia"
	if "patrulla" in blob:
		return "patrulla"

	# Por categoría
	match cat:
		"delitos":
			if severity in ["high", "critical"]:
				return "incidente_activo"
			return "operativo"
		"trafico":
			if "atropello" in blob or "vuelco" in blob or "accidente" in blob:
				return "incidente_activo"
			if "ebrio" in blob or "temeraria" in blob:
				return "operativo"
			return "patrulla"
		"emergencias":
			if "incendio" in blob or "explosion" in blob:
				return "incendio"
			return "asistencia"
		"civiles":
			if "agresiva" in blob or "manifestacion" in blob:
				return "operativo"
			if "desaparecida" in blob or "perdida" in blob:
				return "investigacion"
			return "asistencia"
		"organizado":
			if "drogas" in blob or "laboratorio" in blob or "contrabando" in blob:
				return "narcotrafico"
			if "seguimiento" in blob:
				return "seguimiento"
			return "investigacion"
		"especiales":
			if "aeropuerto" in blob:
				return "aeropuerto"
			if "portuario" in blob:
				return "zona_costera"
			if "operacion" in blob or "visita" in blob:
				return "operacion_especial"
			if "concierto" in blob or "deportivo" in blob or "feria" in blob or "festivo" in blob:
				return "proteccion"
			return "operacion_especial"
		_:
			return "incidente_activo"


func _on_pressed() -> void:
	pressed.emit(mission_id)
