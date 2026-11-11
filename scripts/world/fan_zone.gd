class_name FanZone
extends Node3D
## Соседский вентилятор: сдувает пчелу вдоль своей оси +Z.
## Зона — коробка перед вентилятором: ширина 2.6, высота 3.2, длина 9.

const HALF_WIDTH := 1.3
const HALF_HEIGHT := 1.6
const LENGTH := 9.0
const STRENGTH := 16.0

var _said_at := -100.0


func _physics_process(_delta: float) -> void:
	var game := Game.I
	if game == null or game.state != Game.State.SORTIE or not is_instance_valid(game.bee):
		return
	var p := to_local(game.bee.global_position)
	if absf(p.x) > HALF_WIDTH or absf(p.y) > HALF_HEIGHT or p.z < 0.0 or p.z > LENGTH:
		return
	game.bee.push(global_basis.z.normalized() * STRENGTH)
	if Game.clock - _said_at > 12.0:
		_said_at = Game.clock
		game.say(Lines.pick(Lines.FAN))
