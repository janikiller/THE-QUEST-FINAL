extends Node2D
## Arranque CRESPO / Niebla Norte.

@onready var world: WorldMap = $World
@onready var col_root: Node2D = $Collisions
@onready var player: Player = $Player
@onready var zombies: Node2D = $Zombies
@onready var bullets: Node2D = $Bullets
@onready var lamps_root: Node2D = $Lamps
@onready var overlay: CanvasModulate = $DayNight
@onready var hud: HUD = $HUD
@onready var rain: CPUParticles2D = $Rain

func _ready() -> void:
	randomize()
	GameState.reset_run()
	world.generate(randi())
	world.build_collisions(col_root)
	player.setup(world, zombies, bullets)
	hud.setup(player)
	_spawn_lamps()
	_seed_zombies(5)
	GameState.show_wave_banner("NIEBLA NORTE")
	print("CRESPO/Niebla Norte listo — spawn ", world.spawn)

func _process(dt: float) -> void:
	GameState.tick(dt)
	_update_daynight()
	_update_waves(dt)
	_update_rain()

func _spawn_lamps() -> void:
	for c in lamps_root.get_children():
		c.queue_free()
	var tex: Texture2D = preload("res://assets/light.png")
	for lamp in world.lamps:
		var l := PointLight2D.new()
		l.position = world.world_to_px(Vector2(lamp) + Vector2(0.5, 0.5))
		l.color = Color(1.0, 0.85, 0.55)
		l.energy = 1.1
		l.texture = tex
		l.texture_scale = 3.2
		lamps_root.add_child(l)

func _seed_zombies(n: int) -> void:
	var tries := 0
	while zombies.get_child_count() < n and tries < n * 40:
		tries += 1
		var p := Vector2(2 + randf() * (WorldMap.SIZE - 4), 2 + randf() * (WorldMap.SIZE - 4))
		if not world.can_walk(p.x, p.y, {}): continue
		if p.distance_to(world.spawn) < 12.0: continue
		_spawn_zombie_at(world.world_to_px(p), 0)

func _spawn_zombie_at(pos: Vector2, wave: int) -> void:
	var z := preload("res://scenes/zombie.tscn").instantiate()
	zombies.add_child(z)
	z.setup(world, player, pos, wave)

func _update_daynight() -> void:
	var phase := GameState.day_phase()
	var night_c := Color(0.25, 0.28, 0.4)
	var day_c := Color(1, 1, 1)
	var c := day_c.lerp(night_c, 1.0 - float(phase.light))
	if float(phase.thunder) > 0.0:
		c = c.lerp(Color(0.9, 0.92, 1.0), float(phase.thunder) * 1.5)
	overlay.color = c
	GameState.ambient = c
	for l in lamps_root.get_children():
		l.enabled = bool(phase.night) or float(phase.light) < 0.7
		l.energy = 1.25 if phase.night else 0.55

func _update_rain() -> void:
	var phase := GameState.day_phase()
	rain.emitting = float(phase.rain) > 0.15
	rain.amount = int(40 + float(phase.rain) * 120)
	rain.global_position = player.global_position + Vector2(0, -360)

func _update_waves(dt: float) -> void:
	if GameState.dead: return
	var phase := GameState.day_phase()
	match GameState.wave_phase:
		"countdown":
			GameState.wave_timer -= dt
			if GameState.wave_timer <= 0.0:
				GameState.wave += 1
				GameState.wave_quota = mini(42, 5 + GameState.wave * 3 + (2 if phase.night else 0))
				GameState.wave_spawned = 0
				GameState.wave_phase = "spawning"
				GameState.set_toast("Oleada %d: llegan %d zombis." % [GameState.wave, GameState.wave_quota])
				GameState.show_wave_banner("OLEADA %d" % GameState.wave)
		"spawning":
			var rate := 2.6 + GameState.wave * 0.18
			if GameState.wave_spawned < GameState.wave_quota and randf() < dt * rate:
				if _try_spawn_wave_zombie():
					GameState.wave_spawned += 1
			if GameState.wave_spawned >= GameState.wave_quota:
				GameState.wave_phase = "fighting"
		"fighting":
			if zombies.get_child_count() == 0:
				GameState.wave_phase = "clear"
				GameState.wave_timer = 1.2
				GameState.set_toast("Oleada %d limpia." % GameState.wave)
				GameState.show_wave_banner("OLEADA %d LIMPIA" % GameState.wave)
		"clear":
			GameState.wave_timer -= dt
			if GameState.wave_timer <= 0.0:
				GameState.wave_phase = "countdown"
				GameState.wave_timer = maxf(10.0, 20.0 - GameState.wave * 0.4)
				GameState.set_toast("Siguiente oleada en %ds." % int(ceil(GameState.wave_timer)))

func _try_spawn_wave_zombie() -> bool:
	for i in 20:
		var ang := randf() * TAU
		var dist := 12.0 + randf() * 16.0
		var p := world.px_to_world(player.global_position) + Vector2.from_angle(ang) * dist
		if not world.can_walk(p.x, p.y, {}): continue
		_spawn_zombie_at(world.world_to_px(p), GameState.wave)
		return true
	return false
