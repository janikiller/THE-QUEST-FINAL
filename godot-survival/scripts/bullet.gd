extends Area2D
class_name Bullet

var velocity := Vector2.ZERO
var damage := 10.0
var life := 1.0
var world: WorldMap
var zombies: Node2D

func setup(pos: Vector2, vel: Vector2, dmg: float, lifetime: float, w: WorldMap, z_root: Node2D) -> void:
	global_position = pos; velocity = vel; damage = dmg; life = lifetime
	world = w; zombies = z_root
	collision_layer = 8; collision_mask = 0; monitoring = false
	var poly := Polygon2D.new()
	poly.polygon = PackedVector2Array([Vector2(-4, -1.5), Vector2(5, -1.5), Vector2(5, 1.5), Vector2(-4, 1.5)])
	poly.color = Color(1.0, 0.9, 0.55)
	add_child(poly)

func _physics_process(dt: float) -> void:
	life -= dt
	if life <= 0.0: queue_free(); return
	var next := global_position + velocity * dt
	var tw := world.px_to_world(next)
	if not world.can_walk(tw.x, tw.y, {"bullet": true}): queue_free(); return
	global_position = next; rotation = velocity.angle()
	for z in zombies.get_children():
		if not (z is Zombie): continue
		if z.global_position.distance_to(global_position) < 18.0:
			z.take_hit(damage, velocity.normalized() * 30.0); queue_free(); return
