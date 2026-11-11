class_name Spinner
extends Node3D
## Крутит узел вокруг своей оси Z (лопасти вентилятора).

var speed_deg := 720.0


func _process(delta: float) -> void:
	rotate_object_local(Vector3.FORWARD, deg_to_rad(speed_deg) * delta)
