extends Node

const IP_ADRESS: String = "localhost"
const PORT: int = 42069
const MAIN_SCENE: String = "res://Assets/Scenes/main.tscn"

var peer: ENetMultiplayerPeer

func start_server() -> void:
	peer = ENetMultiplayerPeer.new()
	var err: int = peer.create_server(PORT)
	print("[SERVER] create_server hatası: ", err, " (0 = OK)")
	multiplayer.multiplayer_peer = peer
	print("[SERVER] Bağlantı bekleniyor, port: ", PORT)
	multiplayer.peer_connected.connect(_on_peer_connected, CONNECT_ONE_SHOT)

func start_client() -> void:
	peer = ENetMultiplayerPeer.new()
	var err: int = peer.create_client(IP_ADRESS, PORT)
	print("[CLIENT] create_client hatası: ", err, " (0 = OK)")
	multiplayer.multiplayer_peer = peer
	print("[CLIENT] Sunucuya bağlanılıyor: ", IP_ADRESS, ":", PORT)
	multiplayer.connected_to_server.connect(_on_connected_to_server, CONNECT_ONE_SHOT)
	multiplayer.connection_failed.connect(_on_connection_failed, CONNECT_ONE_SHOT)

func _on_peer_connected(id: int) -> void:
	print("[SERVER] Peer bağlandı, ID: ", id, " → sahne geçiliyor")
	get_tree().change_scene_to_file(MAIN_SCENE)

func _on_connected_to_server() -> void:
	print("[CLIENT] Sunucuya bağlandı → sahne geçiliyor")
	get_tree().change_scene_to_file(MAIN_SCENE)

func _on_connection_failed() -> void:
	print("[CLIENT] BAĞLANTI BAŞARISIZ! IP veya port kontrol et.")

