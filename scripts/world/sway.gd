class_name Sway
extends Node3D
## Покачивание (простыни на верёвке).

var angle := 6.0
var speed := 1.3
var _phase := 0.0
var _base := Basis.IDENTITY


func _ready() -> void:
	_base = basis
	_phase = randf() * 10.0


func _process(_delta: float) -> void:
	basis = _base * Basis(Vector3.RIGHT, deg_to_rad(sin(Game.clock * speed + _phase) * angle))
