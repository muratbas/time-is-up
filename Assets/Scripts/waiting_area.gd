extends Node2D


# ══════════════════════════════════════════════════════════════════════════════
# Başlangıç
# ══════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	# Ağ kurulumu waiting area'da başlıyor
	NetworkHandler.setup_multiplayer()

	# NetworkHandler'ın oyuncu sinyal güncellemelerine bağlan
	NetworkHandler.player_list_changed.connect(_refresh_player_list)

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

	# Her bağlı oyuncu için bir label ekle
	for nick: String in NetworkHandler.connected_players.values():
		var label: Label = Label.new()
		label.text = "• %s" % nick
		list.add_child(label)

	_update_status()

	# Host bağlantısı kurulduktan sonra butonu göster
	var start_btn: Button = _find_node("StartButton") as Button
	if start_btn:
		start_btn.visible = multiplayer.is_server()


func _update_status() -> void:
	var status_lbl: Label = _find_node("StatusLabel") as Label
	if not status_lbl:
		return
	var count: int = NetworkHandler.connected_players.size()
	if multiplayer.is_server():
		status_lbl.text = "%d oyuncu bağlı — Oyunu başlatmak için butona bas." % count
	else:
		status_lbl.text = "%d oyuncu bağlı — Host oyunu başlatmasını bekle..." % count


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
