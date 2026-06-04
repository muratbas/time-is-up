extends Node

# ── Sabitler ──────────────────────────────────────────────────────────────────
const PORT: int = 8080

# ── Sinyaller ─────────────────────────────────────────────────────────────────
## Waiting area'nın oyuncu listesini yenilemesi için
signal player_list_changed

# ── Durum ─────────────────────────────────────────────────────────────────────
var is_host: bool = false

## peer_id → nickname eşlemesi; tüm peerlarda senkronize tutulur
var connected_players: Dictionary = {}

var _player_scene = preload("res://Assets/Scenes/Char/player.tscn")
var _players_spawn_node: Node = null
var _notify_game_manager: bool = false



func reset() -> void:
	# Menüye dönünce tüm ağ durumu sıfırlanır
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	connected_players.clear()
	_players_spawn_node = null
	is_host = false
	PlayerData.server_ip = ""



# ══════════════════════════════════════════════════════════════════════════════
# Kurulum
# ══════════════════════════════════════════════════════════════════════════════

func setup_multiplayer() -> void:
	if is_host:
		_become_host()
	else:
		_join_game()


func _become_host() -> void:
	print("Host olunuyor, IP: %s" % PlayerData.server_ip)

	var server_peer := ENetMultiplayerPeer.new()
	server_peer.create_server(PORT)
	multiplayer.multiplayer_peer = server_peer

	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

	# Host'un kendisini listeye ekle
	_register_player(1, PlayerData.nickname)


func _join_game() -> void:
	print("Bağlanılıyor: %s" % PlayerData.server_ip)

	var client_peer := ENetMultiplayerPeer.new()
	client_peer.create_client(PlayerData.server_ip, PORT)
	multiplayer.multiplayer_peer = client_peer

	# Client bağlandığında nick'ini server'a gönder
	multiplayer.connected_to_server.connect(_on_connected_to_server)


# ══════════════════════════════════════════════════════════════════════════════
# Bağlantı Olayları
# ══════════════════════════════════════════════════════════════════════════════

func _on_peer_connected(id: int) -> void:
	print("Peer bağlandı: %s" % id)
	# Yeni gelen peer'a mevcut listeyi gönder
	_rpc_sync_player_list.rpc_id(id, connected_players)


func _on_peer_disconnected(id: int) -> void:
	print("Peer ayrıldı: %s" % id)
	connected_players.erase(id)
	_rpc_player_left.rpc(id)


func _on_connected_to_server() -> void:
	# Client server'a bağlandığında kendi nick'ini kaydettir
	_rpc_register_me.rpc_id(1, multiplayer.get_unique_id(), PlayerData.nickname)


# ══════════════════════════════════════════════════════════════════════════════
# Yardımcılar
# ══════════════════════════════════════════════════════════════════════════════

func _register_player(id: int, nick: String) -> void:
	connected_players[id] = nick
	player_list_changed.emit()


# ══════════════════════════════════════════════════════════════════════════════
# RPC'ler
# ══════════════════════════════════════════════════════════════════════════════

## Client → Server: "Benim nick'im bu"
@rpc("any_peer", "reliable")
func _rpc_register_me(id: int, nick: String) -> void:
	if not multiplayer.is_server():
		return
	_register_player(id, nick)
	# Yeni oyuncuyu herkese duyur
	_rpc_player_joined.rpc(id, nick)


## Server → Herkes: "Bu oyuncu katıldı"
@rpc("authority", "call_local", "reliable")
func _rpc_player_joined(id: int, nick: String) -> void:
	connected_players[id] = nick
	player_list_changed.emit()


## Server → Herkes: "Bu oyuncu ayrıldı"
@rpc("authority", "call_local", "reliable")
func _rpc_player_left(id: int) -> void:
	connected_players.erase(id)
	player_list_changed.emit()


## Server → YeniClient: Mevcut oyuncu listesini gönder
@rpc("authority", "reliable")
func _rpc_sync_player_list(player_dict: Dictionary) -> void:
	connected_players = player_dict
	player_list_changed.emit()


# ══════════════════════════════════════════════════════════════════════════════
# Oyuncu Spawn / Despawn
# ══════════════════════════════════════════════════════════════════════════════

## GameManager'ı bilgilendirmeden (lobi için) oyuncuları spawn et
func spawn_players_in_lobby(spawn_node: Node) -> void:
	_do_spawn(spawn_node, false)


## GameManager'ı bilgilendirerek (oyun sahnesi için) oyuncuları spawn et
func spawn_players_in_game(spawn_node: Node) -> void:
	# Önceki tek-oyunculu Player node'unu temizle
	var solo := get_tree().current_scene.get_node_or_null("Player")
	if solo:
		solo.queue_free()
	_do_spawn(spawn_node, true)


func _do_spawn(spawn_node: Node, notify_game_manager: bool) -> void:
	_players_spawn_node = spawn_node
	_notify_game_manager = notify_game_manager

	# Çift sinyal bağlantısını önle
	if not multiplayer.peer_connected.is_connected(_spawn_player):
		multiplayer.peer_connected.connect(_spawn_player)
	if not multiplayer.peer_disconnected.is_connected(_despawn_player):
		multiplayer.peer_disconnected.connect(_despawn_player)

	# Mevcut bağlı oyuncuları spawn et (sadece server; Spawner clientlara yayar)
	if multiplayer.is_server():
		for id: int in connected_players.keys():
			_spawn_player(id)


func _spawn_player(id: int) -> void:
	# Spawner kullanıldığı için sadece server manuel spawn yapar; clientlara otomatik yayılır
	if not multiplayer.is_server():
		return
	if not is_instance_valid(_players_spawn_node):
		return
	var player: Node2D = _player_scene.instantiate()
	player.player_id = id
	player.name = str(id)
	_players_spawn_node.add_child(player, true)

	if _notify_game_manager:
		var gm: Node = get_tree().get_first_node_in_group("game_manager")
		if gm:
			gm.on_player_joined()


func _despawn_player(id: int) -> void:
	# Spawner kullanıldığı için sadece server manuel despawn yapar
	if not multiplayer.is_server():
		return
	if not is_instance_valid(_players_spawn_node):
		return
	if not _players_spawn_node.has_node(str(id)):
		return
	_players_spawn_node.get_node(str(id)).queue_free()

	if _notify_game_manager:
		var gm: Node = get_tree().get_first_node_in_group("game_manager")
		if gm:
			gm.on_player_left()

