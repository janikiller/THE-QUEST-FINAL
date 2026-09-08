extends Control
## HUD mínimo del mapa: info + misiones + velocidad + clima/música.

@onready var time_label: Label = %TimeLabel
@onready var prestige_label: Label = %PrestigeLabel
@onready var radio_toast: Label = %RadioToast
@onready var btn_missions: Button = %BtnMissions
@onready var btn_inventory: Button = %BtnInventory
@onready var btn_weather: Button = %BtnWeather
@onready var btn_music: Button = %BtnMusic
@onready var hint: Label = %Hint
@onready var btn_speed_1: Button = %BtnSpeed1
@onready var btn_speed_4: Button = %BtnSpeed4
@onready var btn_speed_16: Button = %BtnSpeed16
@onready var btn_speed_60: Button = %BtnSpeed60

var _speed_group: ButtonGroup


func _ready() -> void:
	GameState.time_changed.connect(func(t):
		time_label.text = t
		_update_tod_hint()
	)
	GameState.prestige_changed.connect(func(_v): _update_tod_hint())
	GameState.time_speed_changed.connect(func(_s): _sync_speed_buttons())
	GameState.weather_changed.connect(func(_w): _update_tod_hint())
	RadioBus.radio_message.connect(_on_radio)
	btn_missions.pressed.connect(_open_missions)
	btn_inventory.pressed.connect(_open_inventory)
	btn_weather.pressed.connect(func(): GameState.cycle_weather())
	btn_music.pressed.connect(func(): AudioDirector.toggle_music())
	AudioDirector.music_toggled.connect(func(on): btn_music.text = "MÚSICA" if on else "MUTE")
	_speed_group = ButtonGroup.new()
	for b in [btn_speed_1, btn_speed_4, btn_speed_16, btn_speed_60]:
		b.button_group = _speed_group
	btn_speed_1.pressed.connect(func(): GameState.set_time_speed(1.0))
	btn_speed_4.pressed.connect(func(): GameState.set_time_speed(4.0))
	btn_speed_16.pressed.connect(func(): GameState.set_time_speed(16.0))
	btn_speed_60.pressed.connect(func(): GameState.set_time_speed(60.0))
	time_label.text = "%02d:%02d" % [GameState.hour, GameState.minute]
	hint.text = "WASD mover · M misiones · I inventario · CLIMA · MÚSICA · 1-4 velocidad · rueda zoom"
	_update_tod_hint()
	_sync_speed_buttons()


func _update_tod_hint() -> void:
	var tod := GameState.time_of_day()
	var label := "DÍA"
	match tod:
		"dusk":
			label = "ATARDECER"
		"night":
			label = "NOCHE"
	prestige_label.text = "★%d  %s  %s  %dx" % [
		GameState.prestige, label, GameState.weather_label(), int(round(GameState.time_speed))
	]
	btn_weather.text = GameState.weather_label()


func _sync_speed_buttons() -> void:
	var s := int(round(GameState.time_speed))
	btn_speed_1.button_pressed = s == 1
	btn_speed_4.button_pressed = s == 4
	btn_speed_16.button_pressed = s == 16
	btn_speed_60.button_pressed = s == 60


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("toggle_missions") or (event is InputEventKey and event.pressed and event.keycode == KEY_M):
		_open_missions()
	elif event.is_action_pressed("toggle_inventory") or (event is InputEventKey and event.pressed and event.keycode == KEY_I):
		_open_inventory()
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1:
				GameState.set_time_speed(1.0)
			KEY_2:
				GameState.set_time_speed(4.0)
			KEY_3:
				GameState.set_time_speed(16.0)
			KEY_4:
				GameState.set_time_speed(60.0)
			KEY_PERIOD, KEY_EQUAL:
				GameState.cycle_time_speed()
			KEY_C:
				GameState.cycle_weather()
			KEY_N:
				AudioDirector.toggle_music()


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
			prefix = "! "
		"dispatch":
			prefix = "> "
		"resolve":
			prefix = "OK "
	radio_toast.text = prefix + text
	radio_toast.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(3.5)
	tw.tween_property(radio_toast, "modulate:a", 0.0, 0.8)
