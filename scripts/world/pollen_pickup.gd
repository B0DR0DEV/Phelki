class_name PollenPickup
extends MeshInstance3D
## Облачко рассыпанной пыльцы. Разлетается, зависает на высоте полёта
## и через 25 секунд тает. Пролетел сквозь — подобрал.

const LIFETIME := 25.0
const PICKUP_DELAY := 0.7
const FLOAT_HEIGHT := 1.8
const RADIUS := 0.75

var _value := 0
var _from_wasp := false
var _born := 0.0
var _vel := Vector3.ZERO
var _phase := 0.0


static func scatter(from: Vector3, total: int, from_wasp: bool) -> void:
	if total <= 0 or Game.I == null:
		return
	var parent: Node3D = Game.I.world.dynamic
	var pieces := clampi(total, 1, 6)
	for i in pieces:
		var value := total / pieces + (1 if i < total % pieces else 0)
		if value <= 0:
			continue
		var p := PollenPickup.new()
		p.name = "Пыльца"
		p.mesh = Shape._mesh(Shape.SPHERE)
		p.material_override = Shape.mat(Palette.GOLD, 0.4)
		p.scale = Vector3.ONE * (0.22 + 0.03 * mini(value, 6))
		p._value = value
		p._from_wasp = from_wasp
		p._born = Game.clock
		p._phase = randf() * 10.0
		var d := Vector2.from_angle(randf() * TAU)
		p._vel = Vector3(d.x, 0.6, d.y) * randf_range(3.0, 5.5)
		parent.add_child(p)
		p.global_position = from


func _process(delta: float) -> void:
	var age := Game.clock - _born
	if age > LIFETIME:
		queue_free()
		return
	_vel = _vel.move_toward(Vector3.ZERO, 6.0 * delta)
	var pos := global_position + _vel * delta
	var target_y := FLOAT_HEIGHT + sin(Game.clock * 2.0 + _phase) * 0.15
	pos.y = lerpf(pos.y, target_y, clampf(2.0 * delta, 0.0, 1.0))
	global_position = pos
	visible = LIFETIME - age > 4.0 or fmod(Game.clock * 6.0, 1.0) > 0.35  # мигает перед исчезновением

	if age < PICKUP_DELAY:
		return
	var game := Game.I
	var bee := game.bee if game else null
	if not is_instance_valid(bee) or bee.pollen >= Bee.CAPACITY:
		return
	if bee.global_position.distance_to(global_position) > RADIUS + Bee.RADIUS:
		return

	var add := mini(_value, Bee.CAPACITY - bee.pollen)
	bee.add_pollen(add, false)
	_value -= add
	if game.stats:
		if _from_wasp:
			game.stats.pollen_stolen = maxi(0, game.stats.pollen_stolen - add)
		else:
			game.stats.pollen_lost = maxi(0, game.stats.pollen_lost - add)
	if _value <= 0:
		queue_free()
