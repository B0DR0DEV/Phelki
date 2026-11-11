class_name SmokeCloud
extends Node3D
## Облако дыма из дымаря: клубы раздуваются, висят и тают.

const GROW := 0.35
const HOLD := 2.6
const FADE := 0.6

var _puffs: Array[MeshInstance3D] = []
var _sizes: Array[Vector3] = []
var _born := 0.0


static func spawn(parent: Node3D, at: Vector3) -> void:
	var c := SmokeCloud.new()
	c.name = "Дым"
	c.position = at
	c._born = Game.clock
	for i in 9:
		var p2 := Vector2.from_angle(randf() * TAU) * sqrt(randf()) * 2.4
		var grey := randf_range(0.72, 0.88)
		var puff := Shape.make(Shape.SPHERE, c, Vector3(p2.x, randf_range(-0.6, 0.9), p2.y), Vector3.ONE * 0.01,
			Color(grey, grey, grey * 0.98), false, "Клуб")
		c._puffs.append(puff)
		c._sizes.append(Vector3.ONE * randf_range(1.4, 2.4))
	parent.add_child(c)
	c.global_position = at


func _process(delta: float) -> void:
	var t := Game.clock - _born
	var k := t / GROW if t < GROW else (1.0 if t < GROW + HOLD else 1.0 - (t - GROW - HOLD) / FADE)
	if k <= 0.0:
		queue_free()
		return
	for i in _puffs.size():
		_puffs[i].scale = _sizes[i] * smoothstep(0.0, 1.0, k)
		_puffs[i].position.y += 0.25 * delta
