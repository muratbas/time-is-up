extends Node

const PORT = 8080
const SERVER_IP = "localhost"

var player_scene = preload("res://Assets/Scenes/Char/player.tscn")

var _players_spawn_node: Node2D

func become_host():
	print("host oldum")
	
	_players_spawn_node = get_tree().get_root().get_node("Players")

	var server_peer = ENetMultiplayerPeer.new()
	server_peer.create_server(PORT)
	
	multiplayer.multiplayer_peer = server_peer

	multiplayer.peer_connected.connect(_add_player_to_game)
	multiplayer.peer_disconnected.connect(_remove_player)

	_remove_single_player()

	_add_player_to_game(1)


func join_game():
	print("oyuna katıldım")

	var client_peer = ENetMultiplayerPeer.new()
	client_peer.create_client(SERVER_IP, PORT)

	multiplayer.multiplayer_peer = client_peer

	_remove_single_player()


func _add_player_to_game(id: int):
	print("oyuncu %s katıldı" % id)

	var player_to_add = player_scene.instantiate()
	player_to_add.player_id = id
	player_to_add.name = str(id)

	_players_spawn_node.add_child(player_to_add, true)


func _remove_player(id: int):
	print("oyuncu %s ayrıldı" % id)
	if not _players_spawn_node.has_node(str(id)):
		return
	_players_spawn_node.get_node(str(id)).queue_free()


func _remove_single_player():
	print("Remove single player")
	var player_to_remove = get_tree().get_current_scene().get_node("Player")
	player_to_remove.queue_free()
