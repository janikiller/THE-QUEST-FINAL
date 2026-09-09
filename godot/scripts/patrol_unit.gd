extends Node2D
## Patrulla en mapa: luces de policía azul/roja (sin retrato).

var patrol_id: String = ""
var _status: String = "available"
var _flash: float = 0.0
var _callsign: String = ""
var _name: String = ""

@onready var label: Label = $Label
@onready var portrait: Sprite2D = $Portrait

const LIGHTS_TEX := "res://assets/map/police_lights_marker.png"


func setup(patrol: Dictionary) -> void:
	patrol_id = patrol["id"]
	refresh(patrol)


func refresh(patrol: Dictionary) -> void:
	position = patrol["pos"]
	_callsign = str(patrol.get("callsign", "?"))
	_name = str(patrol.get("name", ""))
	_status = str(patrol.get("status", "available"))
	label.text = _callsign
	if portrait:
		# Usamos el marcador de luces, no el retrato del agente
		if ResourceLoader.exists(LIGHTS_TEX):
			portrait.texture = load(LIGHTS_TEX)
			portrait.visible = true
			portrait.scale = Vector2(0.72, 0.72)
			portrait.position = Vector2(0, -22)
		else:
			portrait.visible = false
	queue_redraw()


func _process(delta: float) -> void:
	var spd := 4.0
	match _status:
		"en_route", "on_scene":
			spd = 12.0
		"returning":
			spd = 8.0
	_flash += delta * spd
	# Tint del sprite según fase del flash
	if portrait and portrait.visible:
		var t := sin(_flash)
		if t >= 0.0:
			portrait.modulate = Color(0.75, 0.85, 1.25, 1.0)
		else:
			portrait.modulate = Color(1.25, 0.75, 0.8, 1.0)
	queue_redraw()


func _draw() -> void:
	var active := _status != "available"
	var t := sin(_flash)
	var blue_on := t >= 0.0
	var blue := Color(0.12, 0.45, 1.0, 1.0)
	var red := Color(1.0, 0.12, 0.2, 1.0)
	var dim := Color(0.12, 0.14, 0.2, 0.5)

	# Sombra
	draw_circle(Vector2(0, 10), 14.0, Color(0, 0, 0, 0.32))

	# Halo de luces (refuerzo animado sobre el sprite)
	var left_col := blue if blue_on else dim
	var right_col := red if not blue_on else dim
	var glow := 0.55 if active else 0.28
	draw_circle(Vector2(-10, -24), 16.0, Color(left_col.r, left_col.g, left_col.b, glow * 0.45))
	draw_circle(Vector2(10, -24), 16.0, Color(right_col.r, right_col.g, right_col.b, glow * 0.45))
	draw_circle(Vector2(-8, -22), 7.0, Color(left_col.r, left_col.g, left_col.b, glow))
	draw_circle(Vector2(8, -22), 7.0, Color(right_col.r, right_col.g, right_col.b, glow))

	# Barra luminosa bajo el marcador
	draw_rect(Rect2(-14, 2, 12, 5), left_col, true)
	draw_rect(Rect2(2, 2, 12, 5), right_col, true)

	if active:
		draw_arc(Vector2(0, -22), 28.0 + absf(t) * 2.0, 0.0, TAU, 28, Color(left_col.r, left_col.g, left_col.b, 0.22), 2.0, true)
