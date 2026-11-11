class_name HoneyJar
extends Node3D
## Банка мёда, которую дачник должен утащить. Пробежал рядом — подобрал.

const RADIUS := 1.1

var _visual: Node3D
var _phase := 0.0
var _taken := false


static func spawn(parent: Node3D, at: Vector3) -> HoneyJar:
	var j := HoneyJar.new()
	j.name = "Банка мёда"
	j.position = at
	j._phase = randf() * 10.0
	var vis := Shape.node("Вид", j, Vector3(0, 0.6, 0))
	var scene := Shape.art("honey_jar")
	if scene:
		Shape.place_art(scene, vis, Vector3.ZERO, 0.0, false)
	else:
		Shape.make(Shape.CYLINDER, vis, Vector3.ZERO, Vector3(0.36, 0.24, 0.36), Palette.HONEY, false, "Мёд")
		Shape.make(Shape.CYLINDER, vis, Vector3(0, 0.27, 0), Vector3(0.38, 0.04, 0.38), Palette.RED, false, "Крышка")
		Shape.make(Shape.BOX, vis, Vector3(0, 0.02, -0.18), Vector3(0.22, 0.16, 0.01), Palette.WHITE, false, "Этикетка")
	# Маячок, чтобы банку было видно издалека
	Shape.make(Shape.SPHERE, vis, Vector3(0, 1.1, 0), Vector3.ONE * 0.22, Palette.GOLD, false, "Маячок")
	j._visual = vis
	parent.add_child(j)
	return j


func _process(delta: float) -> void:
	_visual.position.y = 0.6 + sin(Game.clock * 2.2 + _phase) * 0.12
	_visual.rotate_y(deg_to_rad(70.0) * delta)

	if _taken:
		return
	var game := Game.I
	var m := game.escape if game else null
	if m == null or not is_instance_valid(m.human) or m.human.frozen:
		return
	var d := m.human.global_position - global_position
	d.y = 0.0
	if d.length() < RADIUS + 0.38:
		_taken = true
		m.on_jar_taken(self)
		queue_free()
