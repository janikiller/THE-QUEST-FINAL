extends CharacterBody2D
class_name Zombie

var hp := 40.0
var speed := 55.0
var damage := 15.0
var stun := 0.0
var hit_flash := 0.0
var attack_cd := 0.0
var wave := 0
var world: WorldMap
var player: Player

@onready var body: Polygon2D = $Body

func setup(w: WorldMap, p: Player, pos: Vector2, wave_n := 0) -> void:
	world = w; player = p; wave = wave_n; global_position = pos
	var sh := 1.0 + maxf(0, wave_n - 1) * 0.14
	var ss := 1.0 + maxf(0, wave_n - 1) * 0.07
	var sd := 1.0 + maxf(0, wave_n - 1) * 0.05
	hp = (38.0 + randf() * 28.0) * sh
	speed = (42.0 + randf() * 28.0) * ss
	damage = 15.0 * sd
	collision_layer = 4; collision_mask = 1

func _physics_process(dt: float) -> void:
	if GameState.dead or player == null: return
	stun = maxf(0.0, stun - dt); hit_flash = maxf(0.0, hit_flash - dt); attack_cd = maxf(0.0, attack_cd - dt)
	_visual()
	if stun > 0.0:
		velocity = Vector2.ZERO; move_and_slide(); return
	var phase := GameState.day_phase()
	var aggro := ((11.0 if phase.night else 7.0) + (6.0 if GameState.noise_pulse > 0.0 else 0.0)) * 48.0
	var to_p: Vector2 = player.global_position - global_position
	var dist := to_p.length()
	if dist < aggro:
		var spd := speed * (1.28 if phase.night else 1.0)
		velocity = to_p.normalized() * spd
	else:
		velocity = Vector2.ZERO
	move_and_slide()
	if dist < 28.0 and attack_cd <= 0.0:
		player.take_damage(damage); attack_cd = 0.95

func take_hit(dmg: float, knock: Vector2) -> void:
	hp -= dmg; stun = maxf(stun, 0.28); hit_flash = 0.2
	global_position += knock * 0.02
	if hp <= 0.0:
		GameState.kills += 1; GameState.add_shake(0.12); queue_free()

func _visual() -> void:
	var c := Color(0.45, 0.55, 0.35)
	if hit_flash > 0.0: c = c.lerp(Color(0.9, 0.35, 0.3), minf(1.0, hit_flash * 4.0))
	body.color = c
