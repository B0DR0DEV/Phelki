class_name Human
extends CharacterBody3D
## Дачник («неуважающий»). Тот же один палец: ведёшь — бежит к пальцу;
## быстрый свайп — перекат (пока катится, не жалят).
## Кнопки: мухобойка (сбивает пчёл перед собой) и дымарь (усыпляет всех вокруг).
## Каждый укус раздувает лицо и руки и замедляет. Отёк 100% — скорая.

const SWAT_COOLDOWN := 0.8
const SMOKE_COOLDOWN := 10.0
const SWAT_RANGE := 2.3
const SMOKE_RADIUS := 4.0
const STING_SWELLING := 0.06  # ~17 укусов до скорой
const RUN_SPEED := 5.4
const ACCEL := 32.0
const DODGE_SPEED := 12.0
const DODGE_TIME := 0.32
const DODGE_COOLDOWN := 1.3
const GRAVITY := 20.0
const CALM_AFTER := 4.0  # секунд без укусов — и отёк начинает спадать
const CALM_RATE := 0.02  # в секунду

var swelling := 0.0
var frozen := false
var local_control := true  # false — управляет бот или игрок по сети
var facing := 0.0  # курс в радианах

var _visual: HumanVisual
var _finger: FingerTracker
var _dodge_until := 0.0
var _dodge_ready_at := 0.0
var _swat_ready_at := 0.0
var _smoke_ready_at := 0.0
var _sting_grace := 0.0
var _last_sting := -100.0
var _dodge_dir := Vector3.ZERO


static func spawn(parent: Node3D, at: Vector3) -> Human:
	var h := Human.new()
	h.name = "Дачник"
	h.collision_layer = 2
	h.collision_mask = 1
	h.position = at

	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.38
	cap.height = 2.0
	cs.shape = cap
	cs.position = Vector3(0, 1, 0)
	h.add_child(cs)

	var vis := HumanVisual.new()
	vis.name = "Вид"
	h.add_child(vis)
	vis.build(h)
	h._visual = vis

	h._finger = FingerTracker.new()
	h.add_child(h._finger)
	parent.add_child(h)
	return h


func is_dodging() -> bool:
	return Game.clock < _dodge_until


func invulnerable() -> bool:
	return is_dodging() or frozen


func swat_ready_in() -> float:
	return maxf(0.0, _swat_ready_at - Game.clock)


func smoke_ready_in() -> float:
	return maxf(0.0, _smoke_ready_at - Game.clock)


func debug_steer(target) -> void:
	_finger.debug_world_target = target


func _match() -> EscapeMatch:
	return Game.I.escape if Game.I else null


func _process(_delta: float) -> void:
	_finger.active = local_control and not frozen and Game.I != null and Game.I.state == Game.State.ESCAPE
	_finger.fpv_yaw = facing if Game.I and Game.I.fpv and local_control else null
	var swipe := _finger.poll()
	if swipe != Vector2.ZERO and Game.clock >= _dodge_ready_at:
		dodge(FingerTracker.screen_dir_to_world(get_viewport().get_camera_3d(), swipe))


func _physics_process(delta: float) -> void:
	if not frozen and Game.clock - _last_sting > CALM_AFTER:
		swelling = maxf(0.0, swelling - CALM_RATE * delta)
	var horiz := Vector3(velocity.x, 0.0, velocity.z)
	var cap := RUN_SPEED * (1.0 - 0.4 * swelling)

	if frozen:
		horiz = horiz.move_toward(Vector3.ZERO, ACCEL * delta)
	elif is_dodging():
		horiz = _dodge_dir * DODGE_SPEED
	elif _finger.is_held():
		var target = _finger.world_point(global_position.y)
		if target != null:
			var to: Vector3 = target - global_position
			to.y = 0.0
			var dist := to.length()
			var desired := to / dist * minf(cap, dist * 3.0) if dist > 0.3 else Vector3.ZERO
			horiz = horiz.move_toward(desired, ACCEL * delta)
	else:
		horiz = horiz.move_toward(Vector3.ZERO, ACCEL * 0.6 * delta)

	if horiz.length_squared() > 0.5:
		facing = atan2(horiz.x, horiz.z)
	var vy := velocity.y - GRAVITY * delta
	if is_on_floor() and vy < 0.0:
		vy = -0.5
	velocity = Vector3(horiz.x, vy, horiz.z)
	move_and_slide()


func dodge(dir: Vector3) -> void:
	if dir == Vector3.ZERO or frozen:
		return
	_dodge_dir = dir.normalized()
	_dodge_until = Game.clock + DODGE_TIME
	_dodge_ready_at = Game.clock + DODGE_COOLDOWN
	facing = atan2(dir.x, dir.z)
	_visual.roll(DODGE_TIME)
	if local_control:
		Sfx.play("whoosh", -6.0, 0.8)
	var m := _match()
	if m:
		m.stats.dodges += 1


# ── Инструменты ────────────────────────────────────────────

func swat() -> void:
	var m := _match()
	if frozen or m == null or Game.clock < _swat_ready_at:
		return
	_swat_ready_at = Game.clock + SWAT_COOLDOWN
	_visual.swing()
	Sfx.play("whoosh", -8.0, 1.4)

	var fwd := Vector3(sin(facing), 0.0, cos(facing))
	var chest := global_position + Vector3(0, 1.3, 0)
	var hits := 0
	for bot in m.bots:
		if not is_instance_valid(bot) or bot.disabled():
			continue
		var d := bot.global_position - chest
		var dist := d.length()
		if dist > SWAT_RANGE:
			continue
		var flat := Vector3(d.x, 0.0, d.z)
		if dist >= 1.1 and rad_to_deg(fwd.angle_to(flat)) > 75.0:
			continue
		bot.stun(3.0, flat.normalized() * 7.0 + Vector3.UP * 2.0)
		hits += 1
		if hits >= 4:
			break
	# Живые пчёлы-игроки тоже получают мухобойкой
	for pb in m.player_bees:
		if not is_instance_valid(pb):
			continue
		var d := pb.global_position - chest
		var flat := Vector3(d.x, 0.0, d.z)
		if d.length() <= SWAT_RANGE and (d.length() < 1.1 or rad_to_deg(fwd.angle_to(flat)) <= 75.0):
			pb.knock(flat.normalized() * 7.0, 2.0)
			hits += 1

	if hits > 0:
		Sfx.play("slap")
		Fx.stars(chest + fwd * 1.2)
	if hits > 0 and m.is_local(self):
		m.stats.swats += hits
		Game.I.toast("Шлёп!" if hits == 1 else "Шлёп ×%d!" % hits)
		if randf() < 0.35:
			Game.I.say(Lines.pick(Lines.SWAT))


func smoke() -> void:
	var m := _match()
	if frozen or m == null or Game.clock < _smoke_ready_at:
		return
	_smoke_ready_at = Game.clock + SMOKE_COOLDOWN
	SmokeCloud.spawn(m, global_position + Vector3(0, 1.2, 0))
	Sfx.play("puff")
	var slept := 0
	for bot in m.bots:
		if is_instance_valid(bot) and bot.global_position.distance_to(global_position) <= SMOKE_RADIUS:
			bot.sleep(3.5)
			slept += 1
	for pb in m.player_bees:
		if is_instance_valid(pb) and pb.global_position.distance_to(global_position) <= SMOKE_RADIUS:
			pb.stick(3.0)
			slept += 1
	if m.is_local(self):
		m.stats.smokes += 1
		Game.I.toast("Дым! Уснули: %d" % slept if slept > 0 else "Дым!")
	Game.I.say(Lines.pick(Lines.SMOKE_USED))


## Пчела пытается ужалить. true — укус прошёл.
func try_sting() -> bool:
	if invulnerable() or Game.clock < _sting_grace:
		return false
	_sting_grace = Game.clock + 0.6  # после укуса — короткая передышка
	_last_sting = Game.clock
	swelling = minf(1.0, swelling + STING_SWELLING)
	var m := _match()
	if m:
		m.on_stung(self)
	_visual.flinch()
	Sfx.play("sting", -3.0 if m and m.is_local(self) else -12.0)
	if m and m.is_local(self):
		Game.I.cam.shake(0.25)
		Game.vibrate(60)
	return true


func faint() -> void:
	_visual.faint()
