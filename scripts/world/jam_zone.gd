class_name JamZone
extends Node3D
## Банка варенья: прилипаешь на пару секунд, зато +3 сладкой пыльцы.

const RADIUS := 1.3

var _ready_at := 0.0


func _physics_process(_delta: float) -> void:
	var game := Game.I
	if game == null or game.state != Game.State.SORTIE or Game.clock < _ready_at:
		return
	var bee := game.bee
	if not is_instance_valid(bee) or bee.global_position.distance_to(global_position) > RADIUS + Bee.RADIUS:
		return
	_ready_at = Game.clock + 6.0
	bee.stick(2.2)
	Sfx.play("jam")
	Fx.burst(bee.global_position, Palette.JAM, 8, 1.5, 0.1)
	bee.add_pollen(3, true)
	game.say(Lines.pick(Lines.JAM))
	game.toast("Прилипла! +3 сладкой пыльцы")
