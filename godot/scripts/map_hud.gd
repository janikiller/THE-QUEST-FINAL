extends Control
## HUD mínimo del mapa: solo info + acceso a misiones. El mapa es para moverse.

@onready var time_label: Label = %TimeLabel
@onready var prestige_label: Label = %PrestigeLabel
@onready var radio_toast: Label = %RadioToast
@onready var btn_missions: Button = %BtnMissions
@onready var hint: Label = %Hint


func _ready() -> void:
	GameState.time_changed.connect(func(t): time_label.text = t)
	GameState.prestige_changed.connect(func(v): prestige_label.text = "Prestigio %d" % v)
	RadioBus.radio_message.connect(_on_radio)
	btn_missions.pressed.connect(_open_missions)
	time_label.text = "%02d:%02d" % [GameState.hour, GameState.minute]
	prestige_label.text = "Prestigio %d" % GameState.prestige
	hint.text = "WASD / flechas mover · Click misión para abrir · M lista de misiones"


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("toggle_missions") or (event is InputEventKey and event.pressed and event.keycode == KEY_M):
		_open_missions()


func _open_missions() -> void:
	var router := get_parent()
	if router and router.has_method("show_missions"):
		router.show_missions()


func _on_radio(text: String, kind: String) -> void:
	var prefix := ""
	match kind:
		"alert":
			prefix = "⚠ "
		"dispatch":
			prefix = "📡 "
		"resolve":
			prefix = "✓ "
	radio_toast.text = prefix + text
	radio_toast.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(3.5)
	tw.tween_property(radio_toast, "modulate:a", 0.0, 0.8)
