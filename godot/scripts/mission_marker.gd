extends Node2D
## Marcador de misión: pin + delincuente en escena.

signal pressed(mission_id: String)

var mission_id: String = ""
var _selected: bool = false
var _status: String = "open"
var _ring_rot: float = 0.0
var _bob: float = 0.0
var _title: String = ""

@onready var hit: Button = $Hit
@onready var title: Label = $Title
@onready var suspect: Sprite2D = $Suspect


func _ready() -> void:
	hit.pressed.connect(_on_pressed)
	hit.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func setup(mission: Dictionary) -> void:
	mission_id = mission["id"]
	position = mission["pos"]
	add_to_group("mission_marker")
	refresh(mission)


func refresh(mission: Dictionary) -> void:
	_title = str(mission.get("title", ""))
	title.text = _title
	_status = str(mission.get("status", "open"))
	var icon := str(mission.get("suspect_icon", ""))
	if icon == "" and is_instance_valid(CharacterDB):
		icon = CharacterDB.delinquent_icon_for_mission(mission_id)
	if suspect:
		if ResourceLoader.exists(icon):
			suspect.texture = load(icon)
			suspect.visible = _status in ["open", "dispatched", "resolving"]
			suspect.position = Vector2(28, -6)
			suspect.scale = Vector2(0.95, 0.95)
		else:
			suspect.visible = false
	set_selected(_selected)
	queue_redraw()


func set_selected(on: bool) -> void:
	_selected = on
	queue_redraw()


func _process(delta: float) -> void:
	_ring_rot += delta * 0.7
	_bob += delta * 2.4
	queue_redraw()


func _draw() -> void:
	var accent := Color(0.92, 0.18, 0.22)
	match _status:
		"dispatched", "resolving":
			accent = Color(0.25, 0.55, 1.0)
		"resolved":
			accent = Color(0.25, 0.85, 0.4)
		"failed":
			accent = Color(0.55, 0.55, 0.55)

	var bob_y := sin(_bob) * 2.0
	var center := Vector2(0, -18 + bob_y)

	# Sombra en suelo (como la patrulla)
	draw_circle(Vector2(0, 8), 14.0, Color(0, 0, 0, 0.32))

	# Luces de alerta azul/roja parpadeantes (mismo lenguaje que patrulla)
	if _status == "open":
		var t := sin(_bob * 4.2)
		var blue_on := t >= 0.0
		var blue := Color(0.15, 0.45, 1.0, 1.0)
		var red := Color(1.0, 0.12, 0.18, 1.0)
		var left_col := blue if blue_on else Color(0.15, 0.18, 0.25, 0.45)
		var right_col := red if not blue_on else Color(0.15, 0.18, 0.25, 0.45)
		draw_rect(Rect2(-9, 3, 7, 4), left_col, true)
		draw_rect(Rect2(2, 3, 7, 4), right_col, true)
		draw_circle(Vector2(-5, 5), 9.0, Color(left_col.r, left_col.g, left_col.b, 0.35))
		draw_circle(Vector2(5, 5), 9.0, Color(right_col.r, right_col.g, right_col.b, 0.35))

	draw_circle(Vector2(0, 4), 26.0 if _selected else 18.0, Color(accent.r, accent.g, accent.b, 0.22))

	var radius := 38.0 if _selected else 32.0
	var dashes := 20
	for i in range(dashes):
		if i % 2 == 0:
			continue
		var a0 := _ring_rot + (TAU * float(i) / float(dashes))
		var a1 := a0 + TAU / float(dashes) * 0.65
		_draw_arc_segment(Vector2.ZERO, radius, a0, a1, Color(accent.r, accent.g, accent.b, 0.95), 3.5)

	var R := 18.0
	var diamond := PackedVector2Array([
		center + Vector2(0, -R),
		center + Vector2(R, 0),
		center + Vector2(0, R),
		center + Vector2(-R, 0),
	])
	draw_colored_polygon(diamond, accent.darkened(0.12))
	draw_polyline(diamond + PackedVector2Array([diamond[0]]), Color(1, 0.55, 0.55, 1), 3.5, true)
	var r2 := 11.0
	var inner := PackedVector2Array([
		center + Vector2(0, -r2),
		center + Vector2(r2, 0),
		center + Vector2(0, r2),
		center + Vector2(-r2, 0),
	])
	draw_colored_polygon(inner, accent.darkened(0.32))

	var white := Color(1, 1, 1, 1)
	draw_rect(Rect2(center + Vector2(-3, -10), Vector2(6, 12)), white)
	draw_circle(center + Vector2(0, 8), 2.8, white)

	var pin_top := center.y + R - 1.0
	var pin := PackedVector2Array([
		Vector2(-8, pin_top),
		Vector2(8, pin_top),
		Vector2(0, pin_top + 14),
	])
	draw_colored_polygon(pin, accent)


func _draw_arc_segment(c: Vector2, radius: float, a0: float, a1: float, color: Color, width: float) -> void:
	var pts := PackedVector2Array()
	var steps := 6
	for i in range(steps + 1):
		var t := float(i) / float(steps)
		var a := lerpf(a0, a1, t)
		pts.append(c + Vector2(cos(a), sin(a)) * radius)
	draw_polyline(pts, color, width, true)


func _on_pressed() -> void:
	pressed.emit(mission_id)
