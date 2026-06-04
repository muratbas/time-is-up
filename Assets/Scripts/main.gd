extends Node2D

func _ready() -> void:
	# Oyun sahnesine geçince oyuncuları Players node'una spawn et
	var players_node: Node = $Players
	NetworkHandler.spawn_players_in_game(players_node)

func _on_menu_button_pressed() -> void:
	pass # Replace with function body.
