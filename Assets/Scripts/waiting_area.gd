extends Node2D


# ══════════════════════════════════════════════════════════════════════════════
# Başlangıç
# ══════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	# NetworkHandler'ın oyuncu listesi sinyaline önceden bağlan (ilk register sinyalini kaçırmamak için)
	if not NetworkHandler.player_list_changed.is_connected(_refresh_player_list):
		NetworkHandler.player_list_changed.connect(_refresh_player_list)

	# Ağ kurulumu waiting area'da başlıyor
	NetworkHandler.setup_multiplayer()

	# Oyuncuları lobide spawn et (game_manager bilgilendirilmez)
	var players_node: Node = _find_node("Players")
	if players_node:
		NetworkHandler.spawn_players_in_lobby(players_node)

	# Başlangıçta listeyi ve durumu çiz
	_refresh_player_list()

	# Sadece host "Oyunu Başlat" butonunu görebilir
	var start_btn: Button = _find_node("StartButton") as Button
	if start_btn:
		# is_server() henüz false olabilir; multiplayer bağlantı kurulduktan sonra güncellenir
		start_btn.visible = false


var _font: FontFile = preload("res://Assets/Fonts/The Bomb Sound.ttf")

# ══════════════════════════════════════════════════════════════════════════════
# Oyuncu Listesi
# ══════════════════════════════════════════════════════════════════════════════

func _refresh_player_list() -> void:
	var list: VBoxContainer = _find_node("PlayerListContainer") as VBoxContainer
	if not list:
		return

	# Eski label'ları temizle
	for child in list.get_children():
		child.queue_free()

	# Her bağlı oyuncu için retro arcade etiket ekle
	var player_ids: Array = NetworkHandler.connected_players.keys()
	player_ids.sort()

	for i in range(player_ids.size()):
		var p_id: int = player_ids[i]
		var nick: String = NetworkHandler.connected_players[p_id]
		var label: Label = Label.new()
		
		var is_me: bool = (p_id == multiplayer.get_unique_id())
		var is_host: bool = (p_id == 1)
		
		var tag_str: String = ""
		if is_host:
			tag_str += " [HOST]"
		if is_me:
			tag_str += " (SEN)"

		label.text = "%d. %s%s" % [i + 1, nick, tag_str]
		label.add_theme_font_override("font", _font)
		label.add_theme_font_size_override("font_size", 14)
		label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3) if is_host else Color(1.0, 1.0, 1.0))
		label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
		label.add_theme_constant_override("outline_size", 3)
		list.add_child(label)

	_update_status()

	# Host bağlantısı kurulduktan sonra başlat butonunu göster
	var start_btn: Button = _find_node("StartButton") as Button
	if start_btn:
		start_btn.visible = multiplayer.is_server()


func _update_status() -> void:
	var status_lbl: Label = _find_node("StatusLabel") as Label
	if not status_lbl:
		return
	var count: int = NetworkHandler.connected_players.size()
	if multiplayer.is_server():
		status_lbl.text = "%d OYUNCU BAGLI - BASLATMAK ICIN BUTONA BASIN!" % count
	else:
		status_lbl.text = "%d OYUNCU BAGLI - HOSTUN BASLATMASI BEKLENIYOR..." % count


func _on_leave_button_pressed() -> void:
	NetworkHandler.reset()
	get_tree().change_scene_to_file("res://Assets/Scenes/Menu/main_menu2.tscn")



# ══════════════════════════════════════════════════════════════════════════════
# Buton Callback
# ══════════════════════════════════════════════════════════════════════════════

func _on_start_button_pressed() -> void:
	# Güvenlik kontrolü: sadece host bu butona basabilir
	if not multiplayer.is_server():
		return
	_rpc_start_game.rpc()


@rpc("authority", "call_local", "reliable")
func _rpc_start_game() -> void:
	# Tüm clientlara ve host'a aynı anda sahne değiştir
	get_tree().change_scene_to_file("res://Assets/Scenes/main.tscn")


# ══════════════════════════════════════════════════════════════════════════════
# Yardımcı
# ══════════════════════════════════════════════════════════════════════════════

func _find_node(node_name: String) -> Node:
	return find_child(node_name, true, false)
