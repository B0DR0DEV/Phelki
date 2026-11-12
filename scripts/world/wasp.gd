class_name Wasp
extends CharacterBody3D
## Оса-гопник. Трётся у мусорки. Видит пчелу с пыльцой рядом — гонится
## и отжимает до 5 пыльцы. Пчела врезалась рывком — оса оглушена
## на 3 секунды и роняет всё, что отжала.

const CHASE_SPEED := 6.2
const AGGRO_RADIUS := 9.0
const STEAL := 5
const RADIUS := 0.32

var _visual: Node3D
var _home := Vector3.ZERO
var _carried := 0
var _stun_until := 0.0
var _cooldown_until := 0.0
var _seed := 0.0
var _yaw := 0.0


static func spawn(parent: Node3D, home: Vector3) -> Wasp:
	var w := Wasp.new()
	w.name = "Оса"
	w.motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	w.collision_layer = 2
	w.collision_mask = 1
	w.position = home
	w._home = home
	w._seed = randf() * 100.0

	var cs := CollisionShape3D.new()
	var sp := SphereShape3D.new()
	sp.radius = RADIUS
	cs.shape = sp
	w.add_child(cs)

	var vis := WingFlap.new()
	vis.name = "Вид"
	vis.speed = 60.0
	vis.scale = Vector3.ONE * 0.85
	var scene := Shape.art("wasp")
	if scene:
		Shape.place_art(scene, vis, Vector3.ZERO, 0.0, false)
	else:
		BeeVisual.build_placeholder(vis, true)
	w.add_child(vis)
	w._visual = vis
	parent.add_child(w)
	return w


func is_stunned() -> bool:
	return Game.clock < _stun_until


func reset_to_home() -> void:
	position = _home
	velocity = Vector3.ZERO
	_carried = 0
	_stun_until = 0.0
	_cooldown_until = 0.0


func _physics_process(delta: float) -> void:
	if is_stunned():
		velocity.y -= 9.8 * delta
		move_and_slide()
		return

	var game := Game.I
	var bee: Bee = game.bee if game and game.state == Game.State.SORTIE else null
	if not is_instance_valid(bee):
		bee = null

	var chase := bee != null and bee.pollen > 0 and Game.clock > _cooldown_until and _carried < 15 \
		and bee.global_position.distance_to(_home) < AGGRO_RADIUS
	var target: Vector3
	if chase:
		target = bee.global_position
	else:
		var t := Game.clock
		target = _home + Vector3(sin(t * 0.9 + _seed) * 1.6, sin(t * 1.7 + _seed) * 0.3, cos(t * 0.7 + _seed) * 1.6)

	var desired := ((target - global_position) * 2.0).limit_length(CHASE_SPEED if chase else 3.0)
	velocity = velocity.move_toward(desired, 20.0 * delta)
	move_and_slide()

	if bee and bee.global_position.distance_to(global_position) < RADIUS + Bee.RADIUS + 0.05:
		_touch(bee)


func _touch(bee: Bee) -> void:
	var game := Game.I
	if bee.is_dashing():
		_stun(bee.velocity)
		return
	if Game.clock < _cooldown_until:
		return
	var stolen := bee.lose_pollen(STEAL)
	if stolen > 0:
		_carried += stolen
		game.stats.pollen_stolen += stolen
		game.say(Lines.pick(Lines.WASP_STEAL))
		Sfx.play("steal")
		game.toast("Осы отжали %d пыльцы" % stolen)
	var away := bee.global_position - global_position
	away.y = 0.0
	bee.knock(away.normalized() * 9.0)
	_cooldown_until = Game.clock + 3.0


func _stun(hit: Vector3) -> void:
	var game := Game.I
	_stun_until = Game.clock + 3.0
	_cooldown_until = _stun_until + 1.0
	velocity = hit * 0.6 + Vector3.UP * 2.0
	game.stats.wasps_rammed += 1
	Sfx.play("slap")
	Fx.stars(global_position)
	game.say(Lines.pick(Lines.WASP_STUN))
	if _carried > 0:
		PollenPickup.scatter(global_position, _carried, true)
		_carried = 0


func _process(delta: float) -> void:
	var v := Vector3(velocity.x, 0.0, velocity.z)
	if v.length_squared() > 0.2:
		_yaw = lerp_angle(_yaw, atan2(v.x, v.z), 8.0 * delta)
	var pitch := 160.0 if is_stunned() else 10.0
	var wobble := sin(Game.clock * 20.0) * 40.0 if is_stunned() else 0.0
	_visual.basis = Basis.from_euler(Vector3(deg_to_rad(pitch), _yaw, deg_to_rad(wobble))) * Basis.from_scale(Vector3.ONE * 0.85)
