extends Node2D

func _process(delta: float):
	$karakter.rotate(0.1)
	$karakter.position.x += 0.1
