class_name BeeBot
extends CharacterBody3D
## Пчела-бот в режиме побега. Окружает дачника со своей стороны,
## жалит и отлетает. Мухобойкой сбивается (3 с), дымом усыпляется.
## В третьей части её место займёт живой игрок-пчела по сети.

const STING_COOLDOWN := 2.3
const RADIUS := 0.25

var speed := 5.0  # чуть медленнее бегущего дачника: стоять на месте нельзя
var attacking := false  # решает матч: жалить сейчас или кружить рядом
var _visual: Node3D
var _angle := 0.0
var _height := 1.4
var _yaw := 0.0
var _stun_until := 0.0
var _sleep_until := 0.0
var _retreat_until := 0.0
var _next_sting := 0.0
var _wake_at := 0.0


static func spawn(parent: Node3D, at: Vector3, angle_deg: float, wake_delay: float) -> BeeBot:
	var b := BeeBot.new()
	b.name = "Пчела-бот"
	b.motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	b.collision_layer = 4
	b.collision_mask = 1
	b.position = at
	b._angle = angle_deg
	b._height = randf_range(1.1, 1.7)
	b._wake_at = Game.clock + wake_delay
	b.speed *= randf_range(0.9, 1.1)

	var cs := CollisionShape3D.new()
	var sp := SphereShape3D.new()
	sp.radius = RADIUS
	cs.shape = sp
	b.add_child(cs)

	var vis := WingFlap.new()
	vis.name = "Вид"
	vis.speed = randf_range(50.0, 62.0)
	var scene := Shape.art("bee")
	if scene:
		Shape.place_art(scene, vis, Vector3.ZERO, 0.0, false)
	else:
		BeeVisual.build_placeholder(vis, false)
	b.add_child(vis)
	b._visual = vis
	parent.add_child(b)
	return b


func stunned() -> bool:
	return Game.clock < _stun_until


func asleep() -> bool:
	return Game.clock < _sleep_until


func awake() -> bool:
	return Game.clock >= _wake_at


func disabled() -> bool:
	return stunned() or asleep()


## Для сетевой копии на клиенте: состояние приходит с сервера.
func net_flags(is_stunned: bool, is_asleep: bool) -> void:
	_stun_until = Game.clock + 0.2 if is_stunned else 0.0
	_sleep_until = Game.clock + 0.2 if is_asleep else 0.0


func stun(seconds: float, push: Vector3) -> void:
	_stun_until = Game.clock + seconds
	velocity = push


func sleep(seconds: float) -> void:
	_sleep_until = maxf(_sleep_until, Game.clock + seconds)


func _physics_process(delta: float) -> void:
	var game := Game.I
	var m := game.escape if game else null
	var human: Human = m.nearest_human(global_position) if m else null
	var pos := global_position

	if stunned():
		velocity.y -= 9.8 * delta
		move_and_slide()
		return
	if asleep():
		# Спит: медленно оседает
		var drift := Vector3(0, -0.6 if pos.y > 0.6 else 0.0, 0)
		velocity = velocity.move_toward(drift, 8.0 * delta)
		move_and_slide()
		return

	var goal: Vector3
	var spd := speed
	if human == null or Game.clock < _wake_at:
		# Ещё не заметила: кружит у улья
		var a := Game.clock * 0.8 + deg_to_rad(_angle)
		goal = game.world.hive_position + Vector3(cos(a) * 2.5, 2.0, sin(a) * 2.5)
		spd = 3.0
	else:
		var target := human.global_position + Vector3(0, _height, 0)
		if Game.clock < _retreat_until:
			var away := pos - target
			away.y = 0.0
			goal = pos + away.normalized() * 3.0 + Vector3(0, 0.6, 0)
		else:
			# Каждая заходит со своей стороны, точка захода медленно вращается
			var side := Basis(Vector3.UP, deg_to_rad(_angle + Game.clock * 35.0)) * Vector3.BACK
			goal = target + side * (0.45 if attacking else 3.4)
			if not attacking:
				goal.y += 0.8
			var hv := human.velocity
			hv.y = 0.0
			goal += hv * 0.25  # упреждение

	var desired := ((goal - pos) * 2.5).limit_length(spd)
	if m:
		for other in m.bots:
			if other == self or not is_instance_valid(other):
				continue
			var d := pos - other.global_position
			var sq := d.length_squared()
			if sq < 0.64 and sq > 0.0001:
				desired += d / sq * 0.6
	velocity = velocity.move_toward(desired, 18.0 * delta)
	move_and_slide()

	# Укус
	if human and attacking and Game.clock >= _wake_at and Game.clock >= _next_sting and Game.clock >= _retreat_until:
		var chest := human.global_position + Vector3(0, 1.3, 0)
		if chest.distance_to(global_position) < 0.95 and human.try_sting():
			_next_sting = Game.clock + STING_COOLDOWN
			_retreat_until = Game.clock + 0.9


func _process(delta: float) -> void:
	var v := Vector3(velocity.x, 0.0, velocity.z)
	if v.length_squared() > 0.2:
		_yaw = lerp_angle(_yaw, atan2(v.x, v.z), 10.0 * delta)
	var pitch := 12.0
	var roll := 0.0
	if stunned():
		pitch = 170.0
		roll = sin(Game.clock * 20.0) * 30.0
	elif asleep():
		pitch = 0.0
		roll = 70.0 + sin(Game.clock * 2.0) * 10.0
	_visual.basis = Basis.from_euler(Vector3(deg_to_rad(pitch), _yaw, deg_to_rad(roll))) * Basis.from_scale(Vector3.ONE * 0.6)
