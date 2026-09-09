extends CharacterBody2D
## Agente controlable en el mapa — marcador con luces de policía.

@export var speed: float = 220.0

@onready var body: ColorRect = $Body
@onready var label: Label = $Label
@onready var shadow: ColorRect = $Shadow

var facing: Vector2 = Vector2.DOWN
var can_move: bool = true
var _flash: float = 0.0


func _ready() -> void:
	add_to_group("player")
	var hq: Array = GameState.station.get("hq_pos", [748, 470])
	global_position = Vector2(float(hq[0]), float(hq[1]))
	label.text = "U.P.R."
	if body:
		body.visible = false
	if shadow:
		shadow.visible = false


func _process(delta: float) -> void:
	_flash += delta * 7.0
	queue_redraw()


func _physics_process(_delta: float) -> void:
	if not can_move:
		velocity = Vector2.ZERO
		return
	var dir := Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_up", "move_down")
	)
	# Fallback a flechas del UI por si el proyecto se abre sin el input map nuevo
	if dir.length() < 0.1:
		dir = Vector2(
			Input.get_axis("ui_left", "ui_right"),
			Input.get_axis("ui_up", "ui_down")
		)
	if dir.length() > 0.1:
		facing = dir.normalized()
		velocity = facing * speed
	else:
		velocity = Vector2.ZERO
	move_and_slide()
	var size: Array = GameState.station.get("map_size", [1536, 1024])
	global_position.x = clampf(global_position.x, 40.0, float(size[0]) - 40.0)
	global_position.y = clampf(global_position.y, 40.0, float(size[1]) - 40.0)


func _draw() -> void:
	var t := sin(_flash)
	var blue_on := t >= 0.0
	var blue := Color(0.15, 0.5, 1.0, 1.0)
	var red := Color(1.0, 0.15, 0.22, 1.0)
	var left := blue if blue_on else Color(0.1, 0.15, 0.25, 0.55)
	var right := red if not blue_on else Color(0.1, 0.15, 0.25, 0.55)

	draw_circle(Vector2(0, 12), 13.0, Color(0, 0, 0, 0.32))
	draw_circle(Vector2(0, -4), 18.0, Color(0.05, 0.08, 0.12, 0.94))
	draw_arc(Vector2(0, -4), 18.0, 0.0, TAU, 32, Color(0.35, 0.65, 1.0, 0.75), 2.5, true)

	draw_rect(Rect2(-14, -10, 12, 10), left, true)
	draw_rect(Rect2(2, -10, 12, 10), right, true)
	draw_circle(Vector2(-8, -5), 11.0, Color(left.r, left.g, left.b, 0.38))
	draw_circle(Vector2(8, -5), 11.0, Color(right.r, right.g, right.b, 0.38))
