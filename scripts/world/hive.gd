class_name Hive
extends Node3D
## Улей игрока. Влетела пчела с пыльцой — пыльца стала мёдом.
## Большая доставка (20+) — бонус от деда.

const BIG_DELIVERY := 20
const BIG_BONUS := 5
const ZONE_CENTER := Vector3(0.0, 1.4, -0.3)
const ZONE_RADIUS := 1.7

var _body: Node3D
var _body_scale := Vector3.ONE
var _pulse := 0.0


func init(body: Node3D) -> void:
	_body = body
	_body_scale = body.scale


func _physics_process(_delta: float) -> void:
	var game := Game.I
	if game == null or game.state != Game.State.SORTIE or not is_instance_valid(game.bee):
		return
	var bee := game.bee
	if bee.pollen <= 0:
		return
	if bee.global_position.distance_to(to_global(ZONE_CENTER)) > ZONE_RADIUS + Bee.RADIUS:
		return

	var p := bee.take_all_pollen()
	var big := p >= BIG_DELIVERY
	var honey := p + (BIG_BONUS if big else 0)
	game.stats.honey_made += honey
	game.stats.deposits += 1
	game.toast("+%d мёда, бонус деда!" % honey if big else "+%d мёда" % honey)
	game.say(Lines.pick(Lines.BIG_DEPOSIT if big else Lines.DEPOSIT))
	_pulse = 1.0
	Sfx.play("big_chime" if big else "chime", -2.0, 1.0, 0.0)
	Fx.burst(global_position + Vector3(0, 1.3, -0.6), Palette.HONEY, 18 if big else 10, 3.0, 0.14)
	Game.vibrate(30)


func _process(delta: float) -> void:
	if _body == null or _pulse <= 0.0:
		return
	_pulse = move_toward(_pulse, 0.0, delta * 2.5)
	_body.scale = _body_scale * (1.0 + sin(_pulse * PI) * 0.12)
