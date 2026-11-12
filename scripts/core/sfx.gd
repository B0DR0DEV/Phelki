class_name Sfx
extends Node
## Звук: короткие эффекты (пул из 10 каналов), петли жужжания, музыка, бубнёж деда.
## Все звуки синтезированы tools/make_sounds.py — без чужих сэмплов.

const CHANNELS := 10

static var I: Sfx
static var enabled := true

var _cache := {}
var _pool: Array[AudioStreamPlayer] = []
var _next := 0
var _music: AudioStreamPlayer
var _music_name := ""
var _loops := {}
var _talk_queue: Array = []
var _talk_at := 0.0


static func setup(parent: Node) -> void:
	if I != null or Game.server_mode:
		return
	I = Sfx.new()
	I.name = "Звук"
	parent.add_child(I)
	for i in CHANNELS:
		var p := AudioStreamPlayer.new()
		I.add_child(p)
		I._pool.append(p)
	I._music = AudioStreamPlayer.new()
	I._music.volume_db = -11.0
	I.add_child(I._music)


func _stream(sfx_name: String, loop := false) -> AudioStream:
	var key := sfx_name + ("|loop" if loop else "")
	if _cache.has(key):
		return _cache[key]
	var path := "res://sfx/%s.wav" % sfx_name
	if not ResourceLoader.exists(path):
		_cache[key] = null
		return null
	var s := load(path) as AudioStreamWAV
	if loop and s:
		s = s.duplicate() as AudioStreamWAV
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = int(s.get_length() * s.mix_rate)
	_cache[key] = s
	return s


## Короткий эффект. pitch с небольшим разбросом — чтобы не надоедало.
static func play(sfx_name: String, volume_db := 0.0, pitch := 1.0, spread := 0.06) -> void:
	if I == null or not enabled:
		return
	var s := I._stream(sfx_name)
	if s == null:
		return
	var p := I._pool[I._next]
	I._next = (I._next + 1) % CHANNELS
	p.stream = s
	p.volume_db = volume_db
	p.pitch_scale = pitch * randf_range(1.0 - spread, 1.0 + spread)
	p.play()


## Петля (жужжание). volume 0..1, 0 — тишина.
static func loop(sfx_name: String, volume: float, pitch := 1.0) -> void:
	if I == null:
		return
	var p: AudioStreamPlayer = I._loops.get(sfx_name)
	if p == null:
		p = AudioStreamPlayer.new()
		p.stream = I._stream(sfx_name, true)
		I.add_child(p)
		I._loops[sfx_name] = p
	if volume <= 0.01 or not enabled:
		if p.playing:
			p.stop()
		return
	if not p.playing:
		p.play()
	p.volume_db = linear_to_db(volume) - 6.0
	p.pitch_scale = pitch


static func stop_loops() -> void:
	if I == null:
		return
	for p in I._loops.values():
		(p as AudioStreamPlayer).stop()


## Музыка: «menu» или «game». Плавная смена.
static func music(track: String) -> void:
	if I == null or I._music_name == track:
		return
	I._music_name = track
	var s := I._stream("music_" + track, true)
	var m := I._music
	var tw := I.create_tween()
	tw.tween_property(m, "volume_db", -40.0, 0.4)
	tw.tween_callback(func():
		m.stream = s
		if s and enabled:
			m.play()
		m.volume_db = -40.0)
	tw.tween_property(m, "volume_db", -11.0 if track == "menu" else -14.0, 0.8)


## Дед бубнит: по слогу на каждые ~3 буквы, не дольше 1,5 секунды.
static func mumble(text: String) -> void:
	if I == null or not enabled:
		return
	I._talk_queue.clear()
	var count := clampi(text.length() / 4, 2, 10)
	for i in count:
		I._talk_queue.append(randi() % 8)
	I._talk_at = 0.0


func _process(delta: float) -> void:
	if _talk_queue.is_empty():
		return
	_talk_at -= delta
	if _talk_at > 0.0:
		return
	var syl: int = _talk_queue.pop_front()
	play("ded%d" % syl, -4.0, randf_range(0.92, 1.12), 0.0)
	_talk_at = randf_range(0.11, 0.16)
	if randf() < 0.12:
		_talk_at += 0.12  # пауза между «словами»
