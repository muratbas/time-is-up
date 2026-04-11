extends MultiplayerSpawner

@export var network_player: PackedScene
@export var spawn_points: Array[Marker2D] = []

func _ready() -> void:
	multiplayer.peer_connected.connect(spawn_player)

	if not multiplayer.is_server():
		return

	# Server kendi oyuncusunu spawn eder
	spawn_player(1)
	# Sahne geç yüklendiğinde kaçırılmış olabilecek client'ları da spawn et
	for id: int in multiplayer.get_peers():
		spawn_player(id)

func spawn_player(id: int) -> void:
	if not multiplayer.is_server():
		return

	var player: Node2D = network_player.instantiate()
	player.name = str(id)
	# _ready() sırasında parent meşgul olabileceğinden bir sonraki frame'e ertelenir
	get_node(spawn_path).add_child.call_deferred(player)
