extends CharacterBody2D
class_name Player

signal inventory_changed
signal died(reason: String)

const WALK := 105.6
const SPRINT := 168.0

var health := 160.0
var max_health := 160.0
var hunger := 82.0
var thirst := 78.0
var stamina := 100.0
var aim := 0.0
var attack_cd := 0.0
var interact_cd := 0.0
var hurt_flash := 0.0
var swing_t := 0.0
var gear_phase := "clothes"

var inv := {}
var equip := {"hand": "bat", "body": "shirt", "bag": null, "light": null}

var world: WorldMap
var zombies: Node2D
var bullets: Node2D
var _keys := {}
var _mouse_down := false

@onready var cam: Camera2D = $Camera2D
@onready var light: PointLight2D = $Light
@onready var body: Polygon2D = $Body
@onready var weapon: Line2D = $Weapon

func setup(w: WorldMap, z_root: Node2D, b_root: Node2D) -> void:
	world = w
	zombies = z_root
	bullets = b_root
	global_position = world.world_to_px(world.spawn)
	inv = {"food": 1, "water": 1, "scrap": 2, "wood": 2, "med": 1, "shirt": 1, "bat": 1, "pistol": 1, "ammo_9mm": 8}
	equip = {"hand": "bat", "body": "shirt", "bag": null, "light": null}
	collision_layer = 2
	collision_mask = 1
	_refresh_light()
	inventory_changed.emit()
	GameState.set_toast("Niebla Norte. Ratón apunta · clic dispara · Q melee · E saquea.")

func _physics_process(dt: float) -> void:
	if GameState.dead: return
	attack_cd = maxf(0.0, attack_cd - dt)
	interact_cd = maxf(0.0, interact_cd - dt)
	hurt_flash = maxf(0.0, hurt_flash - dt)
	swing_t = maxf(0.0, swing_t - dt)
	aim = (get_global_mouse_position() - global_position).angle()
	_move(dt); _input_actions(); _vitals(dt); _visuals()
	if health <= 0.0:
		_die("Los muertos de Niebla Norte te alcanzaron.")

func _just(k: Key) -> bool:
	var down := Input.is_physical_key_pressed(k)
	var was := bool(_keys.get(k, false))
	_keys[k] = down
	return down and not was

func _clicked() -> bool:
	var down := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	var c := down and not _mouse_down
	_mouse_down = down
	return c

func _move(dt: float) -> void:
	var dir := Vector2(float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)), float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
	var moving := dir.length() > 0.1
	var sprint := Input.is_physical_key_pressed(KEY_SPACE) and stamina > 2.0 and moving
	if moving:
		velocity = dir.normalized() * (SPRINT if sprint else WALK)
		stamina = maxf(0.0, stamina - (16.0 if sprint else 3.0) * dt)
		hunger = maxf(0.0, hunger - (0.9 if sprint else 0.35) * dt)
		thirst = maxf(0.0, thirst - (1.1 if sprint else 0.45) * dt)
		if sprint: GameState.noise_pulse = maxf(GameState.noise_pulse, 2.5)
	else:
		velocity = Vector2.ZERO
		stamina = minf(100.0, stamina + 14.0 * dt)
	move_and_slide()

func _input_actions() -> void:
	for i in 5:
		if _just((KEY_1 + i) as Key): _equip_hotbar(i)
	if _just(KEY_Q) and attack_cd <= 0.0: _melee()
	if _clicked() and attack_cd <= 0.0:
		var w := weapon_data()
		if bool(w.get("firearm", false)): _fire(w)
		else: _melee()
	if _just(KEY_E) and interact_cd <= 0.0: _interact()
	if _just(KEY_R) and interact_cd <= 0.0: _consume()
	if _just(KEY_T): _cycle_gear()
	if _just(KEY_B): _cycle_build()
	if _just(KEY_ENTER) and GameState.build_mode != "": _build()
	if _just(KEY_ESCAPE) or _just(KEY_0): GameState.build_mode = ""

func _vitals(dt: float) -> void:
	hunger = maxf(0.0, hunger - 0.28 * dt)
	thirst = maxf(0.0, thirst - 0.36 * dt)
	if hunger < 8.0: health -= 3.5 * dt
	if thirst < 8.0: health -= 4.5 * dt
	var tw := world.px_to_world(global_position)
	if world.tile_at(tw.x, tw.y) == WorldMap.Tile.BASE:
		stamina = minf(100.0, stamina + 6.0 * dt)

func weapon_data() -> Dictionary:
	var id = equip.hand
	if id == null:
		return {"id": "", "label": "Manos", "damage": 18.0, "range": 1.15, "cd": 0.35, "stamina": 5.0, "firearm": false, "icon": "✊"}
	var def := ItemDB.get_def(str(id))
	var w := def.duplicate()
	w.id = str(id); w.firearm = bool(def.get("firearm", false))
	w.damage = float(def.get("damage", 18)); w.range = float(def.get("range", 1.15))
	w.cd = float(def.get("cd", 0.35)); w.stamina = float(def.get("stamina", 5))
	return w

func hotbar() -> Array:
	var owned: Array = []
	for id in ItemDB.WEAPONS:
		if int(inv.get(id, 0)) > 0: owned.append(id)
	var slots: Array = []
	for i in 5:
		var id = owned[i] if i < owned.size() else null
		var def := ItemDB.get_def(str(id)) if id else {}
		var ammo_n = int(inv.get(str(def.ammo), 0)) if def.get("firearm", false) else null
		slots.append({"index": i, "id": id, "label": def.get("label", ""), "icon": def.get("icon", "·"), "ammo": ammo_n, "active": id != null and equip.hand == id, "empty": id == null})
	return slots

func _equip_hotbar(i: int) -> void:
	var slots := hotbar()
	if i >= slots.size() or slots[i].empty:
		GameState.set_toast("Hotbar %d vacío." % (i + 1)); return
	var id: String = slots[i].id
	if equip.hand == id:
		equip.hand = null; GameState.set_toast("Mano libre.")
	else:
		equip.hand = id; GameState.set_toast("Arma: %s" % ItemDB.label_of(id))
	inventory_changed.emit()

func _fire(w: Dictionary) -> void:
	var ammo_id := str(w.get("ammo", ""))
	if ammo_id == "" or int(inv.get(ammo_id, 0)) <= 0:
		GameState.set_toast("Sin munición."); attack_cd = 0.2; return
	inv[ammo_id] = int(inv[ammo_id]) - 1
	if inv[ammo_id] <= 0: inv.erase(ammo_id)
	attack_cd = float(w.cd)
	stamina = maxf(0.0, stamina - float(w.stamina))
	GameState.noise_pulse = maxf(GameState.noise_pulse, minf(2.6, float(w.get("noise", 8)) * 0.22))
	GameState.muzzle_flash = 0.16
	GameState.add_shake(0.28 if int(w.get("pellets", 1)) > 1 else 0.14)
	for i in int(w.get("pellets", 1)):
		var ang := aim + randf_range(-1, 1) * float(w.get("spread", 0))
		var b := preload("res://scenes/bullet.tscn").instantiate()
		bullets.add_child(b)
		b.setup(global_position + Vector2.from_angle(ang) * 18.0, Vector2.from_angle(ang) * float(w.get("bullet_speed", 20)) * 48.0, float(w.damage), float(w.range) / float(w.get("bullet_speed", 20)), world, zombies)
	var left := int(inv.get(ammo_id, 0))
	if left == 0: GameState.set_toast("%s: sin balas." % w.label)
	elif left <= 5: GameState.set_toast("%s: %d balas." % [w.label, left])
	inventory_changed.emit()

func _melee() -> void:
	var w := weapon_data()
	var firearm := bool(w.get("firearm", false))
	var dmg := maxf(12.0, floor(float(w.damage) * 0.28)) if firearm else float(w.damage)
	var mrange := (1.2 if firearm else float(w.range)) * 48.0
	attack_cd = 0.4 if firearm else float(w.cd)
	swing_t = 0.22
	stamina = maxf(0.0, stamina - (8.0 if firearm else float(w.stamina)))
	GameState.noise_pulse = maxf(GameState.noise_pulse, 1.6 if firearm else 2.2)
	var hit := false
	var dir := Vector2.from_angle(aim)
	for z in zombies.get_children():
		if not (z is Zombie): continue
		var to_z: Vector2 = z.global_position - global_position
		var dist := to_z.length()
		if dist > mrange or dist < 0.01 or to_z.normalized().dot(dir) < 0.15: continue
		z.take_hit(dmg, dir * 40.0); hit = true; GameState.add_shake(0.14)
	GameState.set_toast(("Culatazo." if firearm else "Golpeas.") if hit else "Cortas el aire.")

func _interact() -> void:
	interact_cd = 0.35
	var pos := world.px_to_world(global_position)
	if world.tile_at(pos.x, pos.y) == WorldMap.Tile.WATER or world.tile_at(pos.x + 0.6, pos.y) == WorldMap.Tile.WATER:
		thirst = minf(100.0, thirst + 20.0); GameState.set_toast("Bebes del canal. Sabe a óxido."); return
	var furn := world.nearest_furniture(pos)
	if not furn.is_empty():
		interact_cd = 0.55
		GameState.noise_pulse = maxf(GameState.noise_pulse, 1.4)
		var result := world.search_container(str(furn.key))
		if bool(result.get("already", false)): GameState.set_toast("%s: ya registrado." % result.label); return
		if bool(result.get("empty", false)): GameState.set_toast("Registras %s… vacío." % str(result.get("label", "mueble")).to_lower()); return
		if not try_take(str(result.id), int(result.get("amount", 1))): GameState.set_toast("Inventario lleno. Equipa mochila (T)."); return
		GameState.set_toast("En %s: %s." % [str(result.label).to_lower(), ItemDB.label_of(str(result.id))]); return
	var floor_item := world.take_floor_loot(pos)
	if not floor_item.is_empty():
		if not try_take(str(floor_item.id), int(floor_item.get("amount", 1))): GameState.set_toast("Inventario lleno."); return
		GameState.set_toast("Saqueas %s." % ItemDB.label_of(str(floor_item.id)))
		GameState.noise_pulse = maxf(GameState.noise_pulse, 1.2); return
	GameState.set_toast("Nada cerca. E saquea · T equipo · Q melee")

func _consume() -> void:
	interact_cd = 0.4
	if int(inv.get("med", 0)) > 0 and health < max_health - 5.0:
		inv["med"] = int(inv["med"]) - 1
		if int(inv["med"]) <= 0:
			inv.erase("med")
		health = minf(max_health, health + 55.0)
		GameState.set_toast("Usas un botiquín.")
		inventory_changed.emit()
		return
	if int(inv.get("food", 0)) > 0 and hunger < 92.0:
		inv["food"] = int(inv["food"]) - 1
		if int(inv["food"]) <= 0:
			inv.erase("food")
		hunger = minf(100.0, hunger + 34.0)
		GameState.set_toast("Comes una lata fría.")
		inventory_changed.emit()
		return
	if int(inv.get("water", 0)) > 0 and thirst < 92.0:
		inv["water"] = int(inv["water"]) - 1
		if int(inv["water"]) <= 0:
			inv.erase("water")
		thirst = minf(100.0, thirst + 40.0)
		GameState.set_toast("Bebe agua embotellada.")
		inventory_changed.emit()
		return
	GameState.set_toast("Nada útil que consumir.")

func try_take(id: String, amount := 1) -> bool:
	var weight := float(ItemDB.get_def(id).get("weight", 1.0)) * amount
	if inv_used() + weight > inv_capacity() + 0.001: return false
	inv[id] = int(inv.get(id, 0)) + amount; inventory_changed.emit(); return true

func inv_used() -> float:
	var n := 0.0
	for id in inv.keys():
		var count := int(inv[id]); if count <= 0: continue
		var def := ItemDB.get_def(str(id))
		var slot := str(def.get("slot", ""))
		var equipped: bool = slot != "" and (equip.hand == id or equip.body == id or equip.bag == id or equip.light == id)
		n += maxf(0.0, float(count - (1 if equipped else 0))) * float(def.get("weight", 1.0))
	return n

func inv_capacity() -> float:
	var cap := GameState.BASE_CAPACITY
	for slot in ["hand", "body", "bag", "light"]:
		var id = equip[slot]
		if id != null: cap += float(ItemDB.get_def(str(id)).get("capacity", 0))
	return cap

func _cycle_gear() -> void:
	match gear_phase:
		"clothes": _cycle_list("body", ItemDB.CLOTHES, "bag")
		"bag": _cycle_list("bag", ItemDB.BAGS, "light")
		_: _cycle_list("light", ItemDB.LIGHTS, "clothes")
	_refresh_light(); inventory_changed.emit()

func _cycle_list(slot: String, ids: Array, next_phase: String) -> void:
	var owned: Array = []
	for id in ids:
		if int(inv.get(id, 0)) > 0: owned.append(id)
	if owned.is_empty():
		gear_phase = next_phase; GameState.set_toast("Sin %s." % slot); return
	var cur = equip[slot]
	if cur == null or not owned.has(cur):
		equip[slot] = owned[0]; GameState.set_toast("Equipas %s." % ItemDB.label_of(owned[0])); return
	var idx := owned.find(cur)
	if idx < owned.size() - 1:
		equip[slot] = owned[idx + 1]; GameState.set_toast("Equipas %s." % ItemDB.label_of(owned[idx + 1])); return
	var prev = equip[slot]; equip[slot] = null
	if inv_used() > inv_capacity():
		equip[slot] = prev; GameState.set_toast("Demasiada carga."); gear_phase = next_phase; return
	GameState.set_toast("Guardas el equipo."); gear_phase = next_phase

func _cycle_build() -> void:
	var cycle := ["", "wall", "door", "claim"]
	var i := cycle.find(GameState.build_mode)
	GameState.build_mode = cycle[(i + 1) % cycle.size()]
	match GameState.build_mode:
		"": GameState.set_toast("Construcción cancelada.")
		"wall": GameState.set_toast("Modo barricada — Enter.")
		"door": GameState.set_toast("Modo puerta — Enter.")
		"claim": GameState.set_toast("Modo base — Enter.")

func _build() -> void:
	interact_cd = 0.45
	var mode := GameState.build_mode
	var cost := {"scrap": 2, "wood": 1}
	if mode == "claim": cost = {"scrap": 1, "wood": 1}
	for id in cost.keys():
		if int(inv.get(id, 0)) < int(cost[id]): GameState.set_toast("Falta material."); return
	var dir := Vector2.from_angle(aim)
	var tw := world.px_to_world(global_position)
	var bx := int(floor(tw.x if mode == "claim" else tw.x + dir.x * 1.15))
	var by := int(floor(tw.y if mode == "claim" else tw.y + dir.y * 1.15))
	var cur := world.tile_at(bx + 0.5, by + 0.5)
	if mode == "claim":
		if cur in [WorldMap.Tile.WALL, WorldMap.Tile.WATER, WorldMap.Tile.VOID]: GameState.set_toast("Suelo no usable."); return
		for id in cost.keys(): inv[id] = int(inv[id]) - int(cost[id])
		world.set_tile(bx, by, WorldMap.Tile.BASE); GameState.set_toast("Base marcada.")
	else:
		if cur in [WorldMap.Tile.WALL, WorldMap.Tile.WATER, WorldMap.Tile.DOOR]: GameState.set_toast("No puedes construir ahí."); return
		for id in cost.keys(): inv[id] = int(inv[id]) - int(cost[id])
		if mode == "door":
			world.set_tile(bx, by, WorldMap.Tile.DOOR); world.doors["%d,%d" % [bx, by]] = 55.0
		else:
			world.set_tile(bx, by, WorldMap.Tile.BARRICADE)
		GameState.set_toast("Colocado."); GameState.noise_pulse = maxf(GameState.noise_pulse, 2.0)
	inventory_changed.emit()

func take_damage(amount: float) -> void:
	var mult := 1.0
	if equip.body != null: mult = float(ItemDB.get_def(str(equip.body)).get("bite_mult", 1.0))
	health -= amount * mult; hurt_flash = 0.4
	GameState.add_shake(0.35); GameState.set_toast("¡Un zombie te muerde!")

func _die(reason: String) -> void:
	if GameState.dead: return
	health = 0.0; GameState.dead = true; GameState.death_reason = reason
	GameState.add_shake(0.9); died.emit(reason)

func _refresh_light() -> void:
	if equip.light == null: light.enabled = false; return
	var def := ItemDB.get_def(str(equip.light))
	light.enabled = true
	light.texture_scale = float(def.get("light_radius", 3.5)) * 0.55
	light.color = def.get("light_color", Color(1, 0.9, 0.7)); light.energy = 1.15

func _visuals() -> void:
	var fill := Color(0.35, 0.4, 0.45)
	if equip.body != null: fill = ItemDB.get_def(str(equip.body)).get("color", fill)
	if hurt_flash > 0.0: fill = fill.lerp(Color(0.85, 0.2, 0.2), hurt_flash)
	body.color = fill
	var length := 22.0 + (sin((1.0 - swing_t / 0.22) * PI) * 10.0 if swing_t > 0.0 else 0.0)
	weapon.points = PackedVector2Array([Vector2.ZERO, Vector2(length, 0)])
	rotation = aim
	if cam: cam.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * GameState.shake * 14.0
