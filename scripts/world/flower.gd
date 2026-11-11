class_name Flower
extends Node3D
## Цветок с пыльцой. Пыльца понемногу отрастает, пустой цветок сникает.
## Редкий (бабкин) цветок — золотой, крутится и даёт пыльцу быстрее.

var rare := false
var blooming := true
var grandmas_bed := false

var _head: Node3D
var _head_scale := Vector3.ONE
var _petals: Array[MeshInstance3D] = []
var _petal_materials: Array[Material] = []
var _pollen := 0.0
var _max := 6.0
var _rare_said := false


func init(head: Node3D, petals: Array[MeshInstance3D], grandmas: bool) -> void:
	_head = head
	_head_scale = head.scale
	grandmas_bed = grandmas
	for p in petals:
		_petals.append(p)
		_petal_materials.append(p.material_override)


func head_pos() -> Vector3:
	return _head.global_position if _head else global_position + Vector3.UP * 0.75


func has_pollen() -> bool:
	return blooming and _pollen >= 1.0


func prepare(is_blooming: bool, is_rare: bool) -> void:
	rare = is_rare
	blooming = is_blooming
	_max = 20.0 if rare else 6.0
	_pollen = _max if blooming else 0.0
	_rare_said = false
	for i in _petals.size():
		_petals[i].material_override = Shape.mat(Palette.GOLD, 0.3) if rare else _petal_materials[i]


func take(amount: int) -> int:
	var got := mini(amount, floori(_pollen))
	if got <= 0:
		return 0
	_pollen -= got
	if rare and not _rare_said:
		_rare_said = true
		Game.I.say(Lines.pick(Lines.RARE))
	return got


func _process(delta: float) -> void:
	if blooming and _pollen < _max:
		_pollen = minf(_max, _pollen + (0.6 if rare else 0.35) * delta)
	if _head == null:
		return
	var fill := lerpf(0.5, 1.0, _pollen / maxf(1.0, _max)) if blooming else 0.4
	if rare:
		fill *= 1.35
		if blooming:
			_head.rotate_y(deg_to_rad(45.0) * delta)
	_head.scale = _head.scale.lerp(_head_scale * fill, clampf(4.0 * delta, 0.0, 1.0))
