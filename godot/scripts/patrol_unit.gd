extends Node2D
## Patrulla: personaje policía + luces azul/roja.

var patrol_id: String = ""
var _status: String = "available"
var _flash: float = 0.0
var _callsign: String = ""
var _icon_path: String = ""

@onready var label: Label = $Label
@onready var portrait: Sprite2D = $Portrait


func setup(patrol: Dictionary) -> void:
	patrol_id = patrol["id"]
	refresh(patrol)


func refresh(patrol: Dictionary) -> void:
	position = patrol["pos"]
	_callsign = str(patrol.get("callsign", "?"))
	_status = str(patrol.get("status", "available"))
	label.text = _callsign
	_icon_path = str(patrol.get("map_icon", patrol.get("portrait", "")))
	if portrait and ResourceLoader.exists(_icon_path):
		portrait.texture = load(_icon_path)
		portrait.visible = true
		# Iconos circulares ~72px: tamaño legible en el mapa
		portrait.scale = Vector2(1.05, 1.05)
		portrait.position = Vector2(0, -26)
	elif portrait:
		portrait.visible = false
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

	# Soft ground shadow under character
	draw_circle(Vector2(0, 8), 12.0, Color(0, 0, 0, 0.28))

	# Light bar near feet / cruiser cue
	var left_col := blue if blue_on else dim
	var right_col := red if not blue_on else dim
	if not active:
		left_col = Color(0.2, 0.55, 0.95, 0.45)
		right_col = Color(0.95, 0.25, 0.3, 0.45)

	draw_rect(Rect2(-8, 4, 6, 4), left_col, true)
	draw_rect(Rect2(2, 4, 6, 4), right_col, true)

	var glow_a := 0.4 if active else 0.14
	draw_circle(Vector2(-5, 6), 8.0, Color(left_col.r, left_col.g, left_col.b, glow_a))
	draw_circle(Vector2(5, 6), 8.0, Color(right_col.r, right_col.g, right_col.b, glow_a))

	if active:
		draw_circle(Vector2(0, 10), 14.0, Color(left_col.r, left_col.g, left_col.b, 0.1))
