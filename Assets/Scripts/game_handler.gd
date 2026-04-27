extends Node


func become_host():
	print("host tusuna basildi")
	NetworkHandler.is_host = true
	get_tree().change_scene_to_file("res://Assets/Scenes/main.tscn")

func join_game():
	print("katıl butonuna basıldı")
	NetworkHandler.is_host = false
	get_tree().change_scene_to_file("res://Assets/Scenes/main.tscn")
