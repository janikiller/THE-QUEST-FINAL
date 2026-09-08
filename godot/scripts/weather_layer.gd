extends Node2D
## Capas de clima: lluvia, salpicaduras, niebla, arena y flash de rayo.

@onready var rain: GPUParticles2D = $Rain
@onready var splashes: GPUParticles2D = $Splashes
@onready var fog: Sprite2D = $Fog
@onready var wet_overlay: ColorRect = $WetOverlay
@onready var flash: ColorRect = $Flash
@onready var droplets: Node2D = $CameraDroplets

var _map_size: Vector2 = Vector2(1536, 1024)
var _droplet_sprites: Array = []
var _flash_tw: Tween
var _dust: GPUParticles2D


func _ready() -> void:
	_map_size = Vector2(
		float(GameState.station.get("map_size", [1536, 1024])[0]),
		float(GameState.station.get("map_size", [1536, 1024])[1])
	)
	_setup_rain()
	_setup_splashes()
	_setup_fog()
	_setup_flash()
	_setup_droplets()
	_setup_dust()
	GameState.weather_changed.connect(_apply_weather)
	GameState.lightning_flash.connect(_do_flash)
	_apply_weather(GameState.weather)


func _setup_dust() -> void:
	_dust = GPUParticles2D.new()
	_dust.name = "Dust"
	add_child(_dust)
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(1.0, 0.15, 0)
	mat.spread = 18.0
	mat.initial_velocity_min = 80.0
	mat.initial_velocity_max = 220.0
	mat.gravity = Vector3(20, 10, 0)
	mat.scale_min = 0.6
	mat.scale_max = 1.8
	mat.color = Color(0.86, 0.68, 0.42, 0.45)
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(40.0, _map_size.y * 0.55, 1.0)
	_dust.process_material = mat
	_dust.amount = 500
	_dust.lifetime = 2.2
	_dust.preprocess = 0.8
	_dust.visibility_rect = Rect2(Vector2(-80, -80), _map_size + Vector2(160, 160))
	_dust.position = Vector2(-20, _map_size.y * 0.5)
	_dust.emitting = false
	_dust.z_index = 41
	if ResourceLoader.exists("res://assets/weather/sprites/dust_grain.png"):
		_dust.texture = load("res://assets/weather/sprites/dust_grain.png")
	elif ResourceLoader.exists("res://assets/weather/sprites/rain_splash.png"):
		_dust.texture = load("res://assets/weather/sprites/rain_splash.png")



func _setup_rain() -> void:
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0.15, 1.0, 0)
	mat.spread = 6.0
	mat.initial_velocity_min = 420.0
	mat.initial_velocity_max = 680.0
	mat.gravity = Vector3(40, 980, 0)
	mat.scale_min = 0.7
	mat.scale_max = 1.4
	mat.color = Color(0.75, 0.85, 1.0, 0.55)
	rain.process_material = mat
	rain.amount = 900
	rain.lifetime = 1.1
	rain.preprocess = 0.6
	rain.visibility_rect = Rect2(Vector2(-80, -80), _map_size + Vector2(160, 160))
	rain.position = Vector2(_map_size.x * 0.5, -40)
	rain.emitting = false
	if ResourceLoader.exists("res://assets/weather/sprites/rain_streak.png"):
		rain.texture = load("res://assets/weather/sprites/rain_streak.png")
	rain.z_index = 40


func _setup_splashes() -> void:
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 180.0
	mat.initial_velocity_min = 10.0
	mat.initial_velocity_max = 40.0
	mat.gravity = Vector3(0, 30, 0)
	mat.scale_min = 0.5
	mat.scale_max = 1.2
	mat.color = Color(0.8, 0.9, 1.0, 0.35)
	splashes.process_material = mat
	splashes.amount = 120
	splashes.lifetime = 0.35
	splashes.explosiveness = 0.0
	splashes.visibility_rect = Rect2(Vector2.ZERO, _map_size)
	splashes.position = _map_size * 0.5
	splashes.emitting = false
	if ResourceLoader.exists("res://assets/weather/sprites/rain_splash.png"):
		splashes.texture = load("res://assets/weather/sprites/rain_splash.png")
	splashes.z_index = 39


func _setup_fog() -> void:
	fog.centered = true
	fog.position = _map_size * 0.5
	fog.modulate = Color(1, 1, 1, 0)
	fog.z_index = 35
	if ResourceLoader.exists("res://assets/weather/sprites/fog_blob.png"):
		fog.texture = load("res://assets/weather/sprites/fog_blob.png")
		fog.scale = Vector2(_map_size.x / 200.0, _map_size.y / 100.0)


func _setup_flash() -> void:
	flash.position = Vector2.ZERO
	flash.size = _map_size
	flash.color = Color(0.85, 0.9, 1.0, 0.0)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.z_index = 50
	wet_overlay.position = Vector2.ZERO
	wet_overlay.size = _map_size
	wet_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Rain emits across the whole map from above
	if rain.process_material is ParticleProcessMaterial:
		var mat: ParticleProcessMaterial = rain.process_material
		mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		mat.emission_box_extents = Vector3(_map_size.x * 0.55, 20.0, 1.0)
	rain.position = Vector2(_map_size.x * 0.5, -30)
	if splashes.process_material is ParticleProcessMaterial:
		var sm: ParticleProcessMaterial = splashes.process_material
		sm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		sm.emission_box_extents = Vector3(_map_size.x * 0.5, _map_size.y * 0.5, 1.0)
	splashes.position = _map_size * 0.5


func _setup_droplets() -> void:
	for i in 18:
		var s := Sprite2D.new()
		if ResourceLoader.exists("res://assets/weather/sprites/camera_droplet.png"):
			s.texture = load("res://assets/weather/sprites/camera_droplet.png")
		s.modulate.a = 0.0
		s.z_index = 60
		droplets.add_child(s)
		_droplet_sprites.append(s)
	_scatter_droplets()


func _scatter_droplets() -> void:
	for s in _droplet_sprites:
		s.position = Vector2(
			GameState._rng.randf() * _map_size.x,
			GameState._rng.randf() * _map_size.y
		)
		s.scale = Vector2.ONE * GameState._rng.randf_range(0.7, 1.6)
		s.rotation = GameState._rng.randf_range(-0.4, 0.4)


func _process(delta: float) -> void:
	if GameState.weather in ["rain", "storm", "drizzle"]:
		for s in _droplet_sprites:
			s.modulate.a = move_toward(s.modulate.a, GameState._rng.randf_range(0.15, 0.45), delta * 0.6)
			s.position.y += delta * 8.0
			if s.position.y > _map_size.y:
				s.position.y = -10
				s.position.x = GameState._rng.randf() * _map_size.x
	else:
		for s in _droplet_sprites:
			s.modulate.a = move_toward(s.modulate.a, 0.0, delta * 1.5)
	# Fog drift
	if fog.modulate.a > 0.01:
		fog.position.x = _map_size.x * 0.5 + sin(Time.get_ticks_msec() * 0.0002) * 40.0


func _apply_weather(weather: String) -> void:
	match weather:
		"clear":
			rain.emitting = false
			splashes.emitting = false
			if _dust:
				_dust.emitting = false
			fog.modulate = Color(1, 1, 1, 0)
			wet_overlay.color = Color(0.15, 0.25, 0.4, 0.0)
		"drizzle":
			rain.emitting = true
			rain.amount = 350
			splashes.emitting = true
			splashes.amount = 40
			if _dust:
				_dust.emitting = false
			fog.modulate = Color(1, 1, 1, 0.12)
			wet_overlay.color = Color(0.12, 0.22, 0.4, 0.12)
		"rain":
			rain.emitting = true
			rain.amount = 900
			splashes.emitting = true
			splashes.amount = 120
			if _dust:
				_dust.emitting = false
			fog.modulate = Color(1, 1, 1, 0.2)
			wet_overlay.color = Color(0.1, 0.18, 0.35, 0.22)
		"storm":
			rain.emitting = true
			rain.amount = 1400
			splashes.emitting = true
			splashes.amount = 200
			if _dust:
				_dust.emitting = false
			fog.modulate = Color(1, 1, 1, 0.32)
			wet_overlay.color = Color(0.05, 0.1, 0.25, 0.32)
		"sandstorm":
			rain.emitting = false
			splashes.emitting = false
			if _dust:
				_dust.emitting = true
				_dust.amount = 700
			fog.modulate = Color(0.95, 0.78, 0.5, 0.38)
			wet_overlay.color = Color(0.55, 0.38, 0.18, 0.28)
		_:
			rain.emitting = false
			splashes.emitting = false
			if _dust:
				_dust.emitting = false
			wet_overlay.color = Color(0.15, 0.25, 0.4, 0.0)


func _do_flash() -> void:
	if _flash_tw:
		_flash_tw.kill()
	flash.color.a = 0.55
	_flash_tw = create_tween()
	_flash_tw.tween_property(flash, "color:a", 0.0, 0.35)
