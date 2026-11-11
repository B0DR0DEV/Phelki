class_name Profile
extends RefCounted
## Профиль игрока: сторона, мёд, рекорды, настройки, пройденное обучение.
## Хранится на телефоне (user://profile.json).

enum Side { NONE, BEE, HUMAN }

const CHANGE_WINDOW := 600  # секунд, чтобы один раз передумать
const SAVED := [
	"side", "answered_at", "changed_once", "honey", "best_sortie_honey", "sorties",
	"escape_attempts", "escape_wins", "best_escape_time", "survival_best", "hunt_games", "hunt_wins",
	"race_wins", "race_best", "flappy_best", "bear_games", "bear_wins", "team_wins",
	"fpv", "vibration", "map_id", "tutorials", "player_name",
]

static var path := "user://profile.json"
static var _current: Profile

var side: int = Side.NONE
var answered_at := 0
var changed_once := false
var honey := 0
var best_sortie_honey := 0
var sorties := 0
var escape_attempts := 0
var escape_wins := 0
var best_escape_time := 0.0
var survival_best := 0.0
var hunt_games := 0
var hunt_wins := 0
var team_wins := 0
var race_wins := 0
var race_best := {}  # карта → лучшее время
var flappy_best := 0
var bear_games := 0
var bear_wins := 0

# Настройки
var fpv := false
var vibration := true
var map_id := "dacha"
var tutorials := {}  # режим → пройдено
var player_name := ""


static func current() -> Profile:
	if _current == null:
		_current = _load()
	return _current


static func now() -> int:
	return int(Time.get_unix_time_from_system())


## Для автотеста: отдельный файл и чистый профиль.
static func use_test_storage() -> void:
	path = "user://profile_test.json"
	reset()


static func reset() -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	_current = null


func seconds_to_change() -> int:
	return maxi(0, CHANGE_WINDOW - (now() - answered_at))


func can_change() -> bool:
	return answered_at > 0 and not changed_once and seconds_to_change() > 0


func answer(chosen: int) -> void:
	if side == Side.NONE:
		side = chosen
		answered_at = now()
	elif can_change() and chosen != side:
		side = chosen
		changed_once = true
	save()


func display_name() -> String:
	if player_name != "":
		return player_name
	return "Пасечник" if side == Side.BEE else "Дачник"


func save() -> void:
	if Game.server_mode:
		return
	var data := {}
	for key in SAVED:
		data[key] = get(key)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_warning("Не удалось сохранить профиль: %s" % error_string(FileAccess.get_open_error()))
		return
	f.store_string(JSON.stringify(data))


static func _load() -> Profile:
	var p := Profile.new()
	if not FileAccess.file_exists(path):
		return p
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(data) != TYPE_DICTIONARY:
		return p
	for key in SAVED:
		if not data.has(key):
			continue
		var cur = p.get(key)
		match typeof(cur):
			TYPE_INT:
				p.set(key, int(data[key]))
			TYPE_FLOAT:
				p.set(key, float(data[key]))
			TYPE_BOOL:
				p.set(key, bool(data[key]))
			TYPE_DICTIONARY:
				if typeof(data[key]) == TYPE_DICTIONARY:
					p.set(key, data[key])
			_:
				p.set(key, str(data[key]))
	return p
