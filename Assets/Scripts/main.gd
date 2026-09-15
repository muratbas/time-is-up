extends Node2D

func _ready() -> void:
	# Eğer seçili harita varsayılandan farklıysa haritayı dinamik olarak değiştir
	var selected_path: String = PlayerData.get_selected_map_path()
	var current_map: Node = get_node_or_null("Map")
	if current_map and selected_path != "" and current_map.scene_file_path != selected_path:
		var map_idx: int = current_map.get_index()
		current_map.name = "OldMap"
		current_map.queue_free()
		var new_map_scene: PackedScene = load(selected_path)
		if new_map_scene:
			var new_map: Node = new_map_scene.instantiate()
			new_map.name = "Map"
			add_child(new_map)
			move_child(new_map, map_idx)

	# Oyun sahnesine geçince oyuncuları Players node'una spawn et
	var players_node: Node = $Players
	NetworkHandler.spawn_players_in_game(players_node)


