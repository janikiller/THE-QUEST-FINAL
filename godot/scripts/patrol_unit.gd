extends Node2D
## Unidad de patrulla en el mapa (punto + callsign).

var patrol_id: String = ""

@onready var body: ColorRect = $Body
@onready var label: Label = $Label


func setup(patrol: Dictionary) -> void:
	patrol_id = patrol["id"]
	refresh(patrol)


func refresh(patrol: Dictionary) -> void:
	position = patrol["pos"]
	label.text = str(patrol.get("callsign", "?"))
	match str(patrol.get("status", "available")):
		"available":
			body.color = Color(0.35, 0.75, 0.45)
		"en_route":
			body.color = Color(0.95, 0.75, 0.25)
		"on_scene":
			body.color = Color(0.35, 0.6, 1.0)
		"returning":
			body.color = Color(0.7, 0.55, 0.95)
		_:
			body.color = Color(0.6, 0.6, 0.6)
