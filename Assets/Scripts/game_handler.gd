extends Node


func become_host():
	print("host tusuna basildi")
	_save_nickname()
	NetworkHandler.is_host = true
	get_tree().change_scene_to_file("res://Assets/Scenes/main.tscn")

func join_game():
	print("katıl butonuna basıldı")
	_save_nickname()
	NetworkHandler.is_host = false
	get_tree().change_scene_to_file("res://Assets/Scenes/main.tscn")


func _save_nickname() -> void:
	# Scene geçişinden önce girilen nick PlayerData'ya kaydedilir
	var input: LineEdit = get_tree().current_scene.get_node_or_null("UsernameInput")
	if not input:
		return
	var entered: String = input.text.strip_edges()
	PlayerData.nickname = entered if entered.length() > 0 else PlayerData.DEFAULT_NICKNAME

