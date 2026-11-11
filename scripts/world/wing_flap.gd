class_name WingFlap
extends Node3D
## Машет крыльями (для пчёл роя, ботов и ос).

var speed := 50.0
var _wings: Array[Node3D] = []


func _ready() -> void:
	_wings = BeeVisual.find_wings(self)


func _process(_delta: float) -> void:
	BeeVisual.flap_wings(_wings, speed, Game.clock)
