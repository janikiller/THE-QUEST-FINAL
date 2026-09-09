extends Node2D
## Marcador táctico: anillo de color + icono + etiqueta (título / subtítulo).

signal pressed(mission_id: String)

const ICON_DIR := "res://assets/map/tactical_icons/"

var mission_id: String = ""
var _selected: bool = false
var _status: String = "open"
var _pulse: float = 0.0
var _accent: Color = Color(0.92, 0.18, 0.22)
var _headline: String = "INCIDENTE"
var _subline: String = ""
var _icon_tex: Texture2D

@onready var hit: Button = $Hit
@onready var label_panel: PanelContainer = $LabelPanel
@onready var headline: Label = $LabelPanel/Margin/VBox/Headline
@onready var subline: Label = $LabelPanel/Margin/VBox/Subline
@onready var icon: Sprite2D = $Icon


func _ready() -> void:
	hit.pressed.connect(_on_pressed)
	hit.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_style_label_panel()


func setup(mission: Dictionary) -> void:
	mission_id = mission["id"]
	position = mission["pos"]
	add_to_group("mission_marker")
	refresh(mission)


func refresh(mission: Dictionary) -> void:
	_status = str(mission.get("status", "open"))
	var style := _tactical_style(mission)
	_accent = style["color"]
	_headline = str(style["headline"])
	_subline = str(style["subline"])
	_icon_tex = style["icon"] as Texture2D
	if icon:
		icon.texture = _icon_tex
		icon.modulate = Color(1, 1, 1, 1)
	if headline:
		headline.text = _headline
	if subline:
		subline.text = _subline
	_style_label_panel()
	_fit_label_panel()
	_layout_hit()
	set_selected(_selected)
	queue_redraw()


func set_selected(on: bool) -> void:
	_selected = on
	queue_redraw()


func _process(delta: float) -> void:
	_pulse += delta * 2.6
	queue_redraw()


func _style_label_panel() -> void:
	if label_panel == null:
		return
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.06, 0.09, 0.82)
	sb.border_color = Color(_accent.r, _accent.g, _accent.b, 0.55 if _selected else 0.28)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	label_panel.add_theme_stylebox_override("panel", sb)
	if headline:
		headline.add_theme_color_override("font_color", Color(1, 1, 1, 0.96))
		headline.add_theme_font_size_override("font_size", 11)
	if subline:
		subline.add_theme_color_override("font_color", Color(0.82, 0.86, 0.9, 0.88))
		subline.add_theme_font_size_override("font_size", 9)


func _fit_label_panel() -> void:
	if label_panel == null:
		return
	# Círculo arriba; etiqueta debajo extendida a la derecha
	var w := 100.0
	w = maxf(w, float(_headline.length()) * 7.4 + 18.0)
	w = maxf(w, float(_subline.length()) * 5.5 + 18.0)
	w = minf(w, 168.0)
	label_panel.offset_left = -18.0
	label_panel.offset_top = 16.0
	label_panel.offset_right = -18.0 + w
	label_panel.offset_bottom = 54.0
	label_panel.custom_minimum_size = Vector2(w, 0)
	label_panel.z_index = 3


func _layout_hit() -> void:
	if hit == null:
		return
	var right := 110.0
	if label_panel:
		right = maxf(right, label_panel.offset_right + 8.0)
	hit.offset_left = -36.0
	hit.offset_top = -48.0
	hit.offset_right = right
	hit.offset_bottom = 40.0


func _draw() -> void:
	var accent := _accent
	match _status:
		"dispatched", "resolving":
			accent = accent.lerp(Color(0.25, 0.55, 1.0), 0.35)
		"resolved":
			accent = Color(0.25, 0.85, 0.4)
		"failed":
			accent = Color(0.5, 0.5, 0.5)

	var bob := sin(_pulse) * 1.4
	var center := Vector2(0, -14 + bob)
	var r := 22.0 if _selected else 20.0
	var glow_a := 0.34 + absf(sin(_pulse * 1.5)) * 0.16
	if _selected:
		glow_a += 0.12

	# Sombra suelo
	draw_circle(Vector2(0, 12), 12.0, Color(0, 0, 0, 0.3))

	# Halo exterior (glow táctico)
	draw_circle(center, r + 14.0, Color(accent.r, accent.g, accent.b, glow_a * 0.28))
	draw_circle(center, r + 8.0, Color(accent.r, accent.g, accent.b, glow_a * 0.55))
	draw_circle(center, r + 4.0, Color(accent.r, accent.g, accent.b, glow_a * 0.75))

	# Disco interior oscuro
	draw_circle(center, r - 0.5, Color(0.04, 0.06, 0.09, 0.94))

	# Anillo grueso de color
	_draw_ring(center, r - 2.0, r + 2.8, accent)
	# Anillo fino brillante
	_draw_ring(center, r + 3.0, r + 4.2, Color(1, 1, 1, 0.65))

	# Posicionar icono blanco
	if icon:
		icon.position = center
		icon.scale = Vector2(0.48, 0.48)
		icon.modulate = Color(1, 1, 1, 0.98)
		icon.z_index = 2

	# Ancla al suelo
	draw_line(center + Vector2(0, r + 3), Vector2(0, 10), Color(accent.r, accent.g, accent.b, 0.5), 2.0, true)


func _draw_ring(c: Vector2, r_in: float, r_out: float, color: Color) -> void:
	var steps := 40
	var pts_out := PackedVector2Array()
	var pts_in := PackedVector2Array()
	for i in range(steps + 1):
		var a := TAU * float(i) / float(steps)
		var d := Vector2(cos(a), sin(a))
		pts_out.append(c + d * r_out)
		pts_in.append(c + d * r_in)
	# Relleno anillo por triángulos
	for i in range(steps):
		var poly := PackedVector2Array([pts_out[i], pts_out[i + 1], pts_in[i + 1], pts_in[i]])
		draw_colored_polygon(poly, color)


func _tactical_style(mission: Dictionary) -> Dictionary:
	var cat := str(mission.get("category", ""))
	var eid := str(mission.get("event_id", "")).to_lower()
	var title := str(mission.get("title", "Incidente"))
	var severity := str(mission.get("severity", "medium"))
	var blurb := str(mission.get("blurb", ""))
	var sub := title
	if blurb != "":
		sub = blurb
		if sub.length() > 34:
			sub = sub.substr(0, 32) + "…"

	var headline := "INCIDENTE"
	var color := Color(0.92, 0.22, 0.24)
	var icon_name := "bang"

	# Por evento concreto (prioridad)
	if "incendio" in eid:
		headline = "INCENDIO"
		color = Color(1.0, 0.55, 0.12)
		icon_name = "fire"
	elif "persecucion" in eid or "huida" in eid:
		headline = "PERSECUCIÓN"
		color = Color(0.95, 0.18, 0.22)
		icon_name = "car"
	elif "drogas" in eid or "laboratorio" in eid or "contrabando" in eid or "trata" in eid:
		headline = "NARCOTRÁFICO" if ("drogas" in eid or "laboratorio" in eid) else "OPERATIVO"
		color = Color(0.92, 0.16, 0.2)
		icon_name = "crosshair"
	elif "control_de_trafico" in eid:
		headline = "CONTROL"
		color = Color(0.2, 0.55, 1.0)
		icon_name = "shield"
	elif "seguimiento" in eid or "reunion_sospechosa" in eid:
		headline = "SEGUIMIENTO"
		color = Color(0.25, 0.78, 0.42)
		icon_name = "binoculars"
	elif "auxilio" in eid or "medico" in eid or "crisis" in eid or "suicid" in eid:
		headline = "ASISTENCIA"
		color = Color(0.95, 0.2, 0.28)
		icon_name = "medical"
	elif "desaparecida" in eid or "perdida" in eid or "ciber" in eid or "corrupcion" in eid:
		headline = "INVESTIGACIÓN"
		color = Color(0.95, 0.78, 0.15)
		icon_name = "search"
	elif "aeropuerto" in eid or "portuario" in eid:
		headline = "AEROPUERTO" if "aeropuerto" in eid else "PUERTO"
		color = Color(0.62, 0.35, 0.95)
		icon_name = "plane"
	elif "operacion_especial" in eid or "visita_oficial" in eid:
		headline = "OPERACIÓN ESPECIAL"
		color = Color(0.55, 0.58, 0.65)
		icon_name = "flag"
	elif "vigilancia" in title.to_lower() or "edificio" in eid:
		headline = "VIGILANCIA"
		color = Color(0.25, 0.55, 0.95)
		icon_name = "building"
	else:
		# Por categoría / severidad
		match cat:
			"delitos":
				if severity in ["high", "critical"]:
					headline = "INCIDENTE ACTIVO"
					color = Color(0.94, 0.16, 0.2)
					icon_name = "bang"
				else:
					headline = "OPERATIVO"
					color = Color(0.9, 0.25, 0.28)
					icon_name = "bang"
			"trafico":
				headline = "PATRULLA"
				color = Color(0.22, 0.78, 0.4)
				icon_name = "people"
			"emergencias":
				headline = "EMERGENCIA"
				color = Color(1.0, 0.5, 0.12)
				icon_name = "fire"
			"civiles":
				headline = "ASISTENCIA"
				color = Color(0.7, 0.35, 0.95)
				icon_name = "people"
			"organizado":
				headline = "INVESTIGACIÓN"
				color = Color(0.95, 0.78, 0.15)
				icon_name = "search"
			"especiales":
				headline = "EVENTO"
				color = Color(1.0, 0.55, 0.2)
				icon_name = "flag"
			_:
				headline = "INCIDENTE"
				color = Color(0.92, 0.22, 0.24)
				icon_name = "bang"

	# Subtítulo: si el headline ya resume, usa el título de la misión
	if sub == title or blurb == "":
		sub = title
	elif title.length() <= 28:
		sub = title

	var path := ICON_DIR + icon_name + ".png"
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = load(path) as Texture2D

	return {
		"headline": headline,
		"subline": sub,
		"color": color,
		"icon": tex,
	}


func _on_pressed() -> void:
	pressed.emit(mission_id)
