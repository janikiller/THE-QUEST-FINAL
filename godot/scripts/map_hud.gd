extends Control
## HUD mínimo del mapa: solo info + acceso a misiones. El mapa es para moverse.

@onready var time_label: Label = %TimeLabel
@onready var prestige_label: Label = %PrestigeLabel
@onready var radio_toast: Label = %RadioToast
@onready var btn_missions: Button = %BtnMissions
@onready var btn_inventory: Button = %BtnInventory
@onready var hint: Label = %Hint


func _ready() -> void:
	GameState.time_changed.connect(func(t):
		time_label.text = t
		_update_tod_hint()
	)
	GameState.prestige_changed.connect(func(_v): _update_tod_hint())
	RadioBus.radio_message.connect(_on_radio)
	btn_missions.pressed.connect(_open_missions)
	btn_inventory.pressed.connect(_open_inventory)
	time_label.text = "%02d:%02d" % [GameState.hour, GameState.minute]
	hint.text = "WASD / flechas mover · Click misión · M misiones · I inventario · rueda zoom"
	_update_tod_hint()


func _update_tod_hint() -> void:
	var tod := GameState.time_of_day()
	var label := "DÍA"
	match tod:
		"dusk":
			label = "ATARDECER"
		"night":
			label = "NOCHE"
	prestige_label.text = "Prestigio %d   ·   %s" % [GameState.prestige, label]


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("toggle_missions") or (event is InputEventKey and event.pressed and event.keycode == KEY_M):
		_open_missions()
	elif event.is_action_pressed("toggle_inventory") or (event is InputEventKey and event.pressed and event.keycode == KEY_I):
		_open_inventory()


func _open_missions() -> void:
	var router := get_parent()
	if router and router.has_method("show_missions"):
		router.show_missions()


func _open_inventory() -> void:
	var router := get_parent()
	if router and router.has_method("show_inventory"):
		router.show_inventory()


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
