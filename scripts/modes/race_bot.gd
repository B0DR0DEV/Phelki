class_name RaceBot
extends Node3D
## Пчела-соперник в перегонках: летит к следующему кольцу,
## немного виляет и иногда зевает.

var target := Vector3.ZERO
var _speed := 8.0
var _vel := Vector3.ZERO
var _visual: WingFlap
var _phase := 0.0
var _slack_until := 0.0


static func spawn(parent: Node3D, at: Vector3) -> RaceBot:
	var b := RaceBot.new()
	b.name = "Соперник"
	b._speed = randf_range(7.4, 8.6)
	b._phase = randf() * 10.0
	var vis := WingFlap.new()
	vis.name = "Вид"
	vis.speed = 60.0
	var scene := Shape.art("bee")
	if scene:
		Shape.place_art(scene, vis, Vector3.ZERO, 0.0, false)
	else:
		BeeVisual.build_placeholder(vis, false)
	b.add_child(vis)
	b._visual = vis
	parent.add_child(b)
	b.global_position = at
	b.target = at
	return b


func _process(delta: float) -> void:
	var mode := get_parent() as RaceMode
	if mode == null or mode.elapsed < 0.0:
		return
	if Game.clock > _slack_until and randf() < 0.002:
		_slack_until = Game.clock + randf_range(0.6, 1.4)  # зазевался
	var spd := _speed * (0.55 if Game.clock < _slack_until else 1.0)
	var wobble := Vector3(sin(Game.clock * 2.3 + _phase), sin(Game.clock * 1.7 + _phase) * 0.4, cos(Game.clock * 2.1 + _phase)) * 0.6
	var desired := (target + wobble - global_position).normalized() * spd
	_vel = _vel.move_toward(desired, 22.0 * delta)
	global_position += _vel * delta
	if _vel.length_squared() > 0.5:
		var yaw := atan2(_vel.x, _vel.z)
		_visual.basis = Basis.from_euler(Vector3(deg_to_rad(15), yaw, 0.0))
