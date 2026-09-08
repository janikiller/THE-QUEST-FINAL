extends Node2D
## Patrulla como luces de policía azul/roja.

var patrol_id: String = ""
var _status: String = "available"
var _flash: float = 0.0
var _callsign: String = ""

@onready var label: Label = $Label


func setup(patrol: Dictionary) -> void:
	patrol_id = patrol["id"]
	refresh(patrol)


func refresh(patrol: Dictionary) -> void:
	position = patrol["pos"]
	_callsign = str(patrol.get("callsign", "?"))
	_status = str(patrol.get("status", "available"))
	label.text = _callsign if _status != "available" else ""
	queue_redraw()


func _process(delta: float) -> void:
	_flash += delta * (10.0 if _status in ["en_route", "on_scene", "returning"] else 4.0)
	queue_redraw()


func _draw() -> void:
	var active := _status != "available"
	var t := sin(_flash)
	var blue_on := t >= 0.0
	var red := Color(1.0, 0.12, 0.18, 1.0)
	var blue := Color(0.15, 0.45, 1.0, 1.0)
	var dim := Color(0.15, 0.18, 0.25, 0.55)

	# Body / cruiser silhouette
	draw_rect(Rect2(-7, -4, 14, 8), Color(0.08, 0.1, 0.14, 0.9), true)
	draw_rect(Rect2(-7, -4, 14, 8), Color(0.4, 0.45, 0.55, 0.7), false, 1.0)

	# Light bar
	var left_col := blue if blue_on else dim
	var right_col := red if not blue_on else dim
	if not active:
		left_col = Color(0.2, 0.55, 0.95, 0.55)
		right_col = Color(0.95, 0.25, 0.3, 0.55)

	draw_rect(Rect2(-6, -7, 5, 4), left_col, true)
	draw_rect(Rect2(1, -7, 5, 4), right_col, true)

	# Glow blooms
	var glow_a := 0.35 if active else 0.12
	draw_circle(Vector2(-3.5, -5), 7.0, Color(left_col.r, left_col.g, left_col.b, glow_a))
	draw_circle(Vector2(3.5, -5), 7.0, Color(right_col.r, right_col.g, right_col.b, glow_a))

	# Ground light wash when moving
	if active:
		draw_circle(Vector2(0, 6), 10.0, Color(left_col.r, left_col.g, left_col.b, 0.12))
		draw_circle(Vector2(0, 6), 10.0, Color(right_col.r, right_col.g, right_col.b, 0.08))
