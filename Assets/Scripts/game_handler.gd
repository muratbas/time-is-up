extends Node


func become_host():
	print("host tusuna basildi")
	NetworkHandler.become_host()
	get_tree().change_scene_to_file("res://Assets/Scenes/main.tscn")


func join_game():
	print("katıl butonuna basıldı")
	NetworkHandler.join_game()
	get_tree().change_scene_to_file("res://Assets/Scenes/main.tscn")