class_name BearRaid
extends Node3D
## Медведь-рейдер: из леса к улью идёт медведь за мёдом.
## Ты и 8 пчёл-помощниц жалите его. Рывок в медведя жалит сильнее.
## Отбились — медведь убегает, тебе мёд. Не успели — он сел у улья и ест.

const HP := 40.0
const WALK_SPEED := 1.25
const EAT_TIME := 6.0
const SWIPE_EVERY := 4.0
const SWIPE_RADIUS := 3.2
const HELPERS := 8

var hp := HP
var damage_by_player := 0.0
var bee: Bee

var _game: Game
var _world: World
var _bear: Node3D
var _paws: Array[Node3D] = []
var _path_i := 1
var _eating := 0.0
var _fleeing := false
var _ended := false
var _next_swipe := 0.0
var _swipe_anim := -10.0
var _helpers: Array[Dictionary] = []
var _ui := {}
var _elapsed := 0.0


static func begin(game: Game, world: World) -> BearRaid:
	var m := BearRaid.new()
	m.name = "Медведь"
	m._game = game
	m._world = world
	game.add_child(m)
	m._setup()
	return m


func _setup() -> void:
	_bear = Shape.node("Медведь", self)
	var scene := Shape.art("bear")
	if scene:
		Shape.place_art(scene, _bear, Vector3.ZERO, 0.0, false)
	else:
		_build_bear(_bear)
	_bear.global_position = _world.bear_path[0]
	_next_swipe = Game.clock + SWIPE_EVERY

	bee = Bee.spawn(_world, _world.bee_spawn)
	_game.cam.follow(bee, 1.5)
	for i in HELPERS:
		var h := WingFlap.new()
		h.speed = 58.0
		BeeVisual.build_placeholder(h, false)
		add_child(h)
		h.global_position = _world.hive_position + Vector3(randf_range(-2, 2), 2, randf_range(-2, 2))
		_helpers.append({"node": h, "phase": randf() * TAU, "next": Game.clock + randf_range(2.0, 4.0), "dart": -10.0})
	_build_hud()
	_game.say("Медведь идёт к улью! Все на защиту!", 3.0)


func _build_bear(root: Node3D) -> void:
	var fur := Color(0.45, 0.28, 0.16)
	var dark := Color(0.3, 0.18, 0.1)
	Shape.make(Shape.SPHERE, root, Vector3(0, 1.3, 0), Vector3(2.0, 1.8, 2.8), fur, false, "Туловище")
	Shape.make(Shape.SPHERE, root, Vector3(0, 2.1, 1.5), Vector3(1.3, 1.2, 1.2), fur, false, "Голова")
	Shape.make(Shape.SPHERE, root, Vector3(0, 1.95, 2.1), Vector3(0.55, 0.45, 0.5), Color(0.75, 0.6, 0.45), false, "Морда")
	Shape.make(Shape.SPHERE, root, Vector3(0, 2.05, 2.35), Vector3.ONE * 0.18, Palette.BLACK, false, "Нос")
	for side in [-1.0, 1.0]:
		Shape.make(Shape.SPHERE, root, Vector3(0.45 * side, 2.7, 1.4), Vector3.ONE * 0.4, dark, false, "Ухо")
		Shape.make(Shape.SPHERE, root, Vector3(0.3 * side, 2.3, 2.02), Vector3.ONE * 0.13, Palette.BLACK, false, "Глаз")
		for z in [-0.8, 0.8]:
			Shape.make(Shape.CYLINDER, root, Vector3(0.65 * side, 0.4, z), Vector3(0.6, 0.4, 0.6), dark, false, "Лапа")
	for side in [-1.0, 1.0]:
		var paw := Shape.node("Передняя лапа", root, Vector3(0.95 * side, 1.6, 0.9))
		Shape.make(Shape.CAPSULE, paw, Vector3(0, -0.4, 0.2), Vector3(0.45, 0.5, 0.45), dark, false, "Лапища")
		_paws.append(paw)
	# Банка мёда, которую медведь уже где-то утащил
	Shape.make(Shape.CYLINDER, root, Vector3(-0.95, 0.9, 1.3), Vector3(0.35, 0.2, 0.35), Palette.HONEY, false, "Чужой мёд")


func _build_hud() -> void:
	var ui := _game.ui
	var s := ui.new_screen("Медведь")
	ui.place_say(0.73, 0.82)
	var top := UiKit.panel(s, 0.03, 0.9, 0.97, 0.975, UiKit.SHADE)
	UiKit.label(top, "Медведь", 38, 0.03, 0.45, 0.4, 0.95, HORIZONTAL_ALIGNMENT_LEFT, Color.WHITE, true)
	var bar := UiKit.panel(top, 0.03, 0.12, 0.6, 0.4, Color(1, 1, 1, 0.18), 10)
	_ui["hp"] = UiKit.panel(bar, 0, 0, 1, 1, Color(0.85, 0.3, 0.25), 10)
	_ui["dist"] = UiKit.label(top, "", 34, 0.62, 0, 0.97, 1, HORIZONTAL_ALIGNMENT_RIGHT, UiKit.HONEY_BG, true)
	var tag := UiKit.panel(s, 0.03, 0.845, 0.42, 0.89, UiKit.SHADE)
	_ui["arrow"] = UiKit.arrow(tag, 0.03, 0.1, 0.17, 0.9, UiKit.HONEY_BG)
	_ui["tag"] = UiKit.label(tag, "Медведь", 32, 0.2, 0, 0.97, 1, HORIZONTAL_ALIGNMENT_LEFT, Color.WHITE, true)
	ui.view_button(s)
	UiKit.button(s, "Сдаться", 0.72, 0.845, 0.97, 0.89, UiKit.SHADE, Color.WHITE, func(): give_up(), 34)
	var hint := UiKit.panel(s, 0.05, 0.03, 0.95, 0.12, UiKit.SHADE)
	UiKit.label(hint, "Свайп в медведя — сильный укус. Не стой рядом, когда он машет лапой!", 32, 0.04, 0.05, 0.96, 0.95)


func bear_position() -> Vector3:
	return _bear.global_position


func _process(delta: float) -> void:
	if _ended:
		return
	_elapsed += delta
	var hive := _world.hive_position

	# Медведь идёт по пути, у улья садится есть
	if _fleeing:
		var away := (_bear.global_position - hive)
		away.y = 0.0
		_bear.global_position += away.normalized() * 5.0 * delta
		if _bear.global_position.distance_to(hive) > 30.0:
			_finish(true)
		return
	if _path_i < _world.bear_path.size():
		var tgt := _world.bear_path[_path_i]
		var to := tgt - _bear.global_position
		to.y = 0.0
		if to.length() < 0.3:
			_path_i += 1
		else:
			_bear.global_position += to.normalized() * WALK_SPEED * delta
			_bear.rotation.y = lerp_angle(_bear.rotation.y, atan2(to.x, to.z), 4.0 * delta)
			_bear.position.y = absf(sin(_elapsed * 4.0)) * 0.12  # переваливается
	else:
		_eating += delta
		if _eating > 1.0 and fmod(_eating, 2.0) < delta:
			_game.say("Медведь ест наш мёд! Жальте его!", 1.5)
		if _eating >= EAT_TIME:
			_finish(false)
			return

	# Взмах лапой: пчёл рядом отбрасывает
	if Game.clock >= _next_swipe:
		_next_swipe = Game.clock + SWIPE_EVERY
		_swipe_anim = Game.clock
		var center := _bear.global_position + Vector3(0, 1.5, 0)
		if is_instance_valid(bee) and bee.global_position.distance_to(center) < SWIPE_RADIUS:
			var away := bee.global_position - center
			away.y = 0.0
			bee.knock(away.normalized() * 10.0, 1.0)
			_game.toast("Медведь отмахнулся!")
			Game.vibrate(60)
		for h in _helpers:
			h["dart"] = -10.0
	var st := Game.clock - _swipe_anim
	for i in _paws.size():
		var a := sin(clampf(st / 0.5, 0.0, 1.0) * PI) * 80.0 if st < 0.5 else 0.0
		_paws[i].rotation_degrees.x = -a

	_update_bee_stings()
	_update_helpers(delta)
	_update_hud()


func _update_bee_stings() -> void:
	if not is_instance_valid(bee) or Game.clock < bee.sting_ready_at:
		return
	var center := _bear.global_position + Vector3(0, 1.4, 0.4)
	var d := bee.global_position.distance_to(center)
	var dmg := 0.0
	if bee.is_dashing() and d < 2.3:
		dmg = 2.5
	elif d < 1.9:
		dmg = 1.0
	if dmg <= 0.0:
		return
	bee.sting_ready_at = Game.clock + 0.8
	var away := bee.global_position - center
	away.y = 0.0
	bee.knock(away.normalized() * 6.0, 0.25)
	_hit(dmg, true)


func _update_helpers(delta: float) -> void:
	var center := _bear.global_position + Vector3(0, 1.6, 0)
	for h in _helpers:
		var n: Node3D = h["node"]
		var t := Game.clock
		var target: Vector3
		if t - float(h["dart"]) < 0.5:
			target = center  # бросок на медведя
		else:
			var a := t * 1.4 + float(h["phase"])
			target = center + Vector3(cos(a) * 3.2, sin(t * 2.0 + float(h["phase"])) * 0.6 + 0.6, sin(a) * 3.2)
		n.global_position = n.global_position.lerp(target, clampf(3.5 * delta, 0.0, 1.0))
		var dir := target - n.global_position
		if dir.length_squared() > 0.01:
			n.basis = Basis.from_euler(Vector3(0.2, atan2(dir.x, dir.z), 0.0)) * Basis.from_scale(Vector3.ONE * 0.55)
		if t >= float(h["next"]):
			h["next"] = t + randf_range(2.5, 4.0)
			h["dart"] = t
			_hit(0.5, false)


func _hit(dmg: float, by_player: bool) -> void:
	hp = maxf(0.0, hp - dmg)
	if by_player:
		damage_by_player += dmg
		_game.toast("Ужалила! −%s" % ("%.1f" % dmg).trim_suffix(".0"))
		Game.vibrate(30)
	if hp <= 0.0 and not _fleeing:
		_fleeing = true
		_game.say("Убегает! Вот это я понимаю — оборона!", 3.0)


func _update_hud() -> void:
	(_ui["hp"] as Panel).anchor_right = maxf(0.0, hp / HP)
	var d := _bear.global_position.distance_to(_world.hive_position)
	(_ui["dist"] as Label).text = "Ест мёд!" if _eating > 0.0 else "До улья %d м" % roundi(d)
	if is_instance_valid(bee):
		var to := _bear.global_position - bee.global_position
		(_ui["tag"] as Label).text = "Медведь · %d м" % roundi(Vector2(to.x, to.z).length())
		_game.ui.point_arrow(_ui["arrow"], to)


func give_up() -> void:
	_finish(false, true)


func _finish(won: bool, gave_up := false) -> void:
	if _ended:
		return
	_ended = true
	var p := Profile.current()
	p.bear_games += 1
	var honey := 0
	if won:
		p.bear_wins += 1
		honey = 60
	elif not gave_up:
		honey = -mini(30, p.honey)
	var body := "Медведь: %s\nТвоих укусов: %d урона\nВремя: %d с" % [
		"убежал" if won else "наелся мёда", roundi(damage_by_player), roundi(_elapsed)]
	if not won and not gave_up:
		_game.say("Утащил мёд... Ничего, отобьёмся в следующий раз.", 3.0)
	_game.end_mode({
		"title": "Медведь убежал!" if won else ("Сдался" if gave_up else "Медведь наелся"),
		"big": "+%d мёда" % honey if honey >= 0 else "%d мёда" % honey,
		"color": UiKit.DEEP_HONEY if won else UiKit.DANGER_BG,
		"body": body,
		"record": "",
		"honey": honey,
		"footer": "Побед над медведем: %d из %d" % [p.bear_wins, p.bear_games],
	})
	if is_instance_valid(bee):
		bee.queue_free()
