extends CharacterBody2D
## Agente controlable en el mapa (WASD / flechas).

@export var speed: float = 220.0

@onready var body: ColorRect = $Body
@onready var label: Label = $Label
@onready var shadow: ColorRect = $Shadow

var facing: Vector2 = Vector2.DOWN


func _ready() -> void:
	add_to_group("player")
	var hq: Array = GameState.station.get("hq_pos", [748, 470])
	global_position = Vector2(float(hq[0]), float(hq[1]))
	label.text = "TÚ"
	_pulse()


func _physics_process(_delta: float) -> void:
	var dir := Vector2(
		Input.get_axis("ui_left", "ui_right"),
		Input.get_axis("ui_up", "ui_down")
	)
	if dir.length() > 0.1:
		facing = dir.normalized()
		velocity = facing * speed
	else:
		velocity = Vector2.ZERO
	move_and_slide()
	# Keep inside map
	var size: Array = GameState.station.get("map_size", [1536, 1024])
	global_position.x = clampf(global_position.x, 40.0, float(size[0]) - 40.0)
	global_position.y = clampf(global_position.y, 40.0, float(size[1]) - 40.0)


func _pulse() -> void:
	var tw := create_tween().set_loops()
	tw.tween_property(shadow, "modulate:a", 0.25, 0.9).from(0.55)
