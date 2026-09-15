class_name TestArena
extends Node2D

# ── Dışa Aktarılan Parametreler ──────────────────────────────────────────────
@export var auto_spawn_offline_player: bool = true

# ══════════════════════════════════════════════════════════════════════════════
# Başlangıç
# ══════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	# Eğer multiplayer eşi yoksa (menüden doğrudan antrenman açıldıysa)
	# test edebilmek için anında yerel bir oyuncu spawn et
	var peer: MultiplayerPeer = multiplayer.multiplayer_peer
	var is_offline: bool = (peer == null or peer is OfflineMultiplayerPeer)
	if auto_spawn_offline_player and is_offline:
		_spawn_local_test_player()


func _spawn_local_test_player() -> void:
	var player_scene: PackedScene = preload("res://Assets/Scenes/Char/player.tscn")
	var player_instance: Node2D = player_scene.instantiate()
	player_instance.set("player_id", 1)
	player_instance.name = "1"

	var spawn_node: Node = get_node_or_null("SpawnPoints/SpawnPoint1")
	if spawn_node and spawn_node is Marker2D:
		player_instance.position = (spawn_node as Marker2D).position
	else:
		player_instance.position = Vector2(-120.0, -165.0)

	add_child(player_instance)
	player_instance.set("nickname", PlayerData.nickname)
