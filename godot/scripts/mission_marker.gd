extends Node2D
## Marcador de misión en el mapa.

signal pressed(mission_id: String)

var mission_id: String = ""
var _selected: bool = false

@onready var button: TextureButton = $Button
@onready var pulse: ColorRect = $Pulse
@onready var title: Label = $Title
@onready var status_dot: ColorRect = $StatusDot


func setup(mission: Dictionary) -> void:
	mission_id = mission["id"]
	position = mission["pos"]
	refresh(mission)
	button.pressed.connect(_on_pressed)
	_pulse_anim()


func refresh(mission: Dictionary) -> void:
	title.text = str(mission.get("title", ""))
	var path := GameState.texture_path_for_event_file(str(mission.get("file", "")))
	if ResourceLoader.exists(path):
		button.texture_normal = load(path)
	match str(mission.get("status", "open")):
		"open":
			status_dot.color = Color(0.9, 0.7, 0.25)
		"dispatched", "resolving":
			status_dot.color = Color(0.35, 0.65, 1.0)
		"resolved":
			status_dot.color = Color(0.35, 0.85, 0.45)
		_:
			status_dot.color = Color(0.9, 0.35, 0.35)
	set_selected(_selected)


func set_selected(on: bool) -> void:
	_selected = on
	pulse.visible = on
	modulate = Color(1.15, 1.1, 0.9) if on else Color.WHITE


func _on_pressed() -> void:
	pressed.emit(mission_id)


func _pulse_anim() -> void:
	var tw := create_tween().set_loops()
	tw.tween_property(pulse, "scale", Vector2(1.25, 1.25), 0.9).from(Vector2(1, 1))
	tw.parallel().tween_property(pulse, "modulate:a", 0.15, 0.9).from(0.45)
