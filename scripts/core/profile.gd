class_name Profile
extends RefCounted
## Профиль игрока. Пока хранится на телефоне (user://profile.json);
## когда появится сервер, ответ деду и мёд будут храниться там.

enum Side { NONE, BEE, HUMAN }

const CHANGE_WINDOW := 600  # секунд, чтобы один раз передумать

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


func save() -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_warning("Не удалось сохранить профиль: %s" % error_string(FileAccess.get_open_error()))
		return
	f.store_string(JSON.stringify({
		"side": side, "answered_at": answered_at, "changed_once": changed_once,
		"honey": honey, "best_sortie_honey": best_sortie_honey, "sorties": sorties,
		"escape_attempts": escape_attempts, "escape_wins": escape_wins,
		"best_escape_time": best_escape_time,
	}))


static func _load() -> Profile:
	var p := Profile.new()
	if not FileAccess.file_exists(path):
		return p
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(data) != TYPE_DICTIONARY:
		return p
	p.side = int(data.get("side", 0))
	p.answered_at = int(data.get("answered_at", 0))
	p.changed_once = bool(data.get("changed_once", false))
	p.honey = int(data.get("honey", 0))
	p.best_sortie_honey = int(data.get("best_sortie_honey", 0))
	p.sorties = int(data.get("sorties", 0))
	p.escape_attempts = int(data.get("escape_attempts", 0))
	p.escape_wins = int(data.get("escape_wins", 0))
	p.best_escape_time = float(data.get("best_escape_time", 0.0))
	return p
