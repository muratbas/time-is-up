extends Node

const PORT = 8080
const SERVER_IP = "localhost"

func become_host():
	print("host oldum")

	var server_peer = ENetMultiplayerPeer.new()
	server_peer.create_server(PORT)
	
	multiplayer.multiplayer_peer = server_peer

	multiplayer.peer_connected.connect(_add_player_to_game)
	multiplayer.peer_disconnected.connect(_remove_player)
	

func join_game():
	print("oyuna katıldım")

	var client_peer = ENetMultiplayerPeer.new()
	client_peer.create_client(SERVER_IP, PORT)

	multiplayer.multiplayer_peer = client_peer


func _add_player_to_game(id: int):
	print("oyuncu %s katıldı" % id)


func _remove_player(id: int):
	print("oyuncu %s ayrıldı" % id)