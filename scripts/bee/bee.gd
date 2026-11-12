class_name Bee
extends CharacterBody3D
## Пчела игрока. Управление одним пальцем:
## ведёшь — летит к пальцу; отпустил — зависает, её сносит ветром;
## быстрый свайп — рывок (им можно протаранить осу).
## Чем больше пыльцы несёт, тем толще и медленнее.

const MAX_SPEED := 8.5
const ACCEL := 26.0
const HOVER_BRAKE := 5.0
const CRUISE_HEIGHT := 2.1
const DASH_SPEED := 17.0
const DASH_TIME := 0.32
const DASH_COOLDOWN := 0.9
const CAPACITY := 30
const COLLECT_RATE := 6.0
const RARE_COLLECT_RATE := 11.0
const RADIUS := 0.38

var pollen := 0
var steering := false
var local_control := true  # false — управляет бот или игрок по сети
var heading := 0.0  # курс в радианах (для вида от первого лица)
var sting_ready_at := 0.0
var cruise_height := CRUISE_HEIGHT  # в перегонках — высота колец  # в охоте на дачников: когда снова можно ужалить
var current_flower: Flower

var _finger: FingerTracker
var _visual: BeeVisual
var _dash_until := 0.0
var _dash_ready_at := 0.0
var _stuck_until := 0.0
var _stun_until := 0.0
var _last_crash := -10.0
var _collect_acc := 0.0
var _dash_dir := Vector3.ZERO
var _external := Vector3.ZERO
var _full_said := false


static func spawn(parent: Node3D, at: Vector3) -> Bee:
	var b := Bee.new()
	b.name = "Пчела"
	b.motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	b.collision_layer = 2
	b.collision_mask = 1
	b.position = at

	var cs := CollisionShape3D.new()
	var sp := SphereShape3D.new()
	sp.radius = RADIUS
	cs.shape = sp
	b.add_child(cs)

	var vis := BeeVisual.new()
	vis.name = "Вид"
	b.add_child(vis)
	var scene := Shape.art("bee")
	if scene:
		Shape.place_art(scene, vis, Vector3.ZERO, 0.0, false)
	else:
		BeeVisual.build_placeholder(vis, false)
	vis.bind(b)
	b._visual = vis

	b._finger = FingerTracker.new()
	b.add_child(b._finger)
	parent.add_child(b)
	return b


func load_fraction() -> float:
	return float(pollen) / CAPACITY


func is_dashing() -> bool:
	return Game.clock < _dash_until


func is_stuck() -> bool:
	return Game.clock < _stuck_until


## Для автотеста: вести пчелу к точке, как будто палец там.
func debug_steer(target) -> void:
	_finger.debug_world_target = target


func _stats() -> SortieStats:
	return Game.I.stats if Game.I else null


func _process(_delta: float) -> void:
	_finger.active = local_control and Game.I != null and Game.I.bee_controls_active()
	_finger.fpv_yaw = heading if Game.I and Game.I.fpv and local_control else null
	var swipe := _finger.poll()
	steering = _finger.is_held() and Game.clock >= _stun_until
	if swipe != Vector2.ZERO and Game.clock >= _dash_ready_at:
		dash(FingerTracker.screen_dir_to_world(get_viewport().get_camera_3d(), swipe))


func _physics_process(delta: float) -> void:
	var world := Game.I.world if Game.I else null
	var horiz := Vector3(velocity.x, 0.0, velocity.z)
	var cap := MAX_SPEED * lerpf(1.0, 0.62, load_fraction())
	if is_stuck():
		cap *= 0.25

	if is_dashing():
		horiz = _dash_dir * DASH_SPEED
	elif steering:
		var target = _finger.world_point(global_position.y)
		if target != null:
			var to: Vector3 = target - global_position
			to.y = 0.0
			var dist := to.length()
			var desired := to / dist * minf(cap, dist * 2.2) if dist > 0.25 else Vector3.ZERO
			horiz = horiz.move_toward(desired, ACCEL * delta)
	else:
		horiz = horiz.move_toward(Vector3.ZERO, HOVER_BRAKE * delta)

	if world:
		horiz += world.wind * (0.25 if steering else 1.0) * delta
	horiz += _external * delta
	_external = Vector3.ZERO

	if is_stuck():
		horiz = horiz.limit_length(cap)
	elif not is_dashing():
		horiz = horiz.limit_length(maxf(cap * 1.8, 12.0))

	# Высота: зависли рядом с цветком — опускаемся к нему.
	var target_y := cruise_height
	current_flower = null
	if horiz.length() > 1.0:
		heading = lerp_angle(heading, atan2(horiz.x, horiz.z), clampf(6.0 * delta, 0.0, 1.0))
	if world and Game.I.state == Game.State.SORTIE and not is_dashing() and horiz.length() < 3.6:
		var f := world.nearest_flower(global_position, 1.7)
		if f:
			current_flower = f
			target_y = f.head_pos().y + 0.45
	var bob := sin(Game.clock * 3.1) * 0.12
	var vy := (target_y + bob - global_position.y) * 4.0

	var before := Vector3(horiz.x, vy, horiz.z)
	velocity = before
	move_and_slide()
	_handle_collisions(before)
	_collect(delta)


## Отскок от стен и стёкол; сильный удар — рассыпаем пыльцу.
func _handle_collisions(before: Vector3) -> void:
	var worst := 0.0
	var normal := Vector3.ZERO
	var bounce := 0.5
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		var n := c.get_normal()
		var impact := -before.dot(n)
		if impact > worst:
			worst = impact
			normal = n
			var collider := c.get_collider()
			bounce = float(collider.get_meta("bounce", 0.5)) if collider else 0.5
	if worst < 0.5:
		return

	var out := before.bounce(normal) * bounce
	velocity = Vector3(out.x, velocity.y, out.z)
	_dash_until = 0.0

	if worst < 6.0 or Game.clock - _last_crash < 0.7:
		return
	_last_crash = Game.clock
	_stun_until = Game.clock + 0.45
	var s := _stats()
	if s:
		s.crashes += 1
	if pollen > 0:
		drop_pollen(maxi(1, roundi(pollen * 0.25)))
	_visual.tumble()
	Fx.stars(global_position)
	if local_control:
		Sfx.play("thud")
	Game.I.say(Lines.pick(Lines.CRASH))
	if local_control:
		Game.vibrate(40)


func _collect(delta: float) -> void:
	if current_flower == null or pollen >= CAPACITY:
		_collect_acc = 0.0
		return
	if current_flower.head_pos().distance_to(global_position) > 1.05:
		return
	_collect_acc += (RARE_COLLECT_RATE if current_flower.rare else COLLECT_RATE) * delta
	var want := floori(_collect_acc)
	if want <= 0:
		return
	_collect_acc -= want
	var got := current_flower.take(mini(want, CAPACITY - pollen))
	if got > 0:
		add_pollen(got, true)
		if local_control:
			Sfx.play("pop", -8.0, 0.9 + load_fraction() * 0.5)
		if randf() < 0.35:
			Fx.burst(current_flower.head_pos() + Vector3(0, 0.1, 0), Palette.GOLD, 4, 1.2, 0.08, -1.5)


func dash(dir: Vector3) -> void:
	if dir == Vector3.ZERO:
		return
	_dash_dir = dir.normalized()
	_dash_until = Game.clock + DASH_TIME
	_dash_ready_at = Game.clock + DASH_COOLDOWN
	_stuck_until = 0.0
	_visual.dash()
	if local_control:
		Sfx.play("whoosh", -4.0)


# ── Пыльца ─────────────────────────────────────────────────

func add_pollen(amount: int, collected: bool) -> void:
	var before := pollen
	pollen = clampi(pollen + amount, 0, CAPACITY)
	var s := _stats()
	if collected and s:
		s.pollen_collected += pollen - before
	if pollen >= CAPACITY and not _full_said:
		_full_said = true
		Game.I.say(Lines.pick(Lines.FULL))


func take_all_pollen() -> int:
	var p := pollen
	pollen = 0
	_full_said = false
	return p


func lose_pollen(amount: int) -> int:
	var lost := mini(maxi(0, amount), pollen)
	pollen -= lost
	if pollen < CAPACITY:
		_full_said = false
	return lost


## Рассыпать пыльцу облачками — их можно подобрать обратно.
func drop_pollen(amount: int) -> void:
	var lost := lose_pollen(amount)
	if lost <= 0:
		return
	var s := _stats()
	if s:
		s.pollen_lost += lost
	PollenPickup.scatter(global_position, lost, false)


# ── Внешние воздействия ────────────────────────────────────

func stick(seconds: float) -> void:
	_stuck_until = Game.clock + seconds
	_dash_until = 0.0


func push(force: Vector3) -> void:
	_external += force


func knock(vel: Vector3, stun := 0.35) -> void:
	_dash_until = 0.0
	_stun_until = Game.clock + stun
	velocity = vel
	_visual.tumble()
