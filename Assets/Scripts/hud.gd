extends CanvasLayer

var _game_manager: Node = null

# ── Node Referansları (dinamik; path bağımsız) ────────────────────────────────
var waiting_panel: Control
var waiting_label: Label
var hud_panel: Control
var timer_label: Label
var tag_label: Label
var max_time_label: Label
var game_over_panel: Control
var result_label: Label
var ping_label: Label



# ══════════════════════════════════════════════════════════════════════════════
# Başlangıç
# ══════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	# Node referanslarını isimle bul — path'e bağımlı değil
	waiting_panel   = find_child("WaitingPanel", true, false) as Control
	waiting_label   = find_child("CountLabel", true, false) as Label
	hud_panel       = find_child("HUDPanel", true, false) as Control
	timer_label     = find_child("TimerLabel", true, false) as Label
	tag_label       = find_child("TagLabel", true, false) as Label
	max_time_label  = find_child("MaxTimeLabel", true, false) as Label
	game_over_panel = find_child("GameOverPanel", true, false) as Control
	result_label    = find_child("ResultLabel", true, false) as Label
	ping_label      = find_child("PingLabel", true, false) as Label


	await get_tree().process_frame
	_game_manager = get_tree().get_first_node_in_group("game_manager")
	print("HUD: game_manager bulundu mu? ", _game_manager != null)

	if _game_manager:
		_game_manager.game_started.connect(_on_game_started)
		_game_manager.game_ended.connect(_on_game_ended)
		_game_manager.player_count_changed.connect(_on_player_count_changed)
		_game_manager.bomb_transferred.connect(_on_bomb_transferred)
		_game_manager.pressure_increased.connect(_on_pressure_increased)
		_game_manager.player_eliminated.connect(_on_player_eliminated)


		# Sinyaller bağlanmadan önce oyun başlamış olabilir, mevcut duruma göre arayüzü ayarla
		if _game_manager.game_state == 1: # GameState.PLAYING
			_on_game_started()
			if _game_manager.current_tag_id != -1:
				_on_bomb_transferred(_game_manager.current_tag_id, _game_manager.bomb_timer, _game_manager.current_bomb_time)
		elif _game_manager.game_state == 2: # GameState.GAME_OVER
			_show_game_over()
		else:
			_show_waiting_screen()
	else:
		_show_waiting_screen()



# ══════════════════════════════════════════════════════════════════════════════
# Frame Döngüsü — Bomba Sayacı
# ══════════════════════════════════════════════════════════════════════════════

func _process(_delta: float) -> void:
	# Ping gösterimi (Her 30 karede bir güncellenir ki yormasın)
	if ping_label and Engine.get_frames_drawn() % 30 == 0:
		var enet_peer = multiplayer.multiplayer_peer as ENetMultiplayerPeer
		if enet_peer:
			if multiplayer.is_server():
				ping_label.text = "Ping: 0 ms (Host)"
			else:
				var server_peer = enet_peer.get_peer(1)
				if server_peer:
					var ping = server_peer.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME)
					ping_label.text = "Ping: %d ms" % ping

	if _game_manager == null:
		return

	if _game_manager.game_state != _game_manager.GameState.PLAYING:
		return
	# Bomba sayacını her frame güncelle; tüm peerlarda aynı değer (set_process=true)
	var t: float = maxf(_game_manager.bomb_timer, 0.0)
	timer_label.text = "%.1f" % t


# ══════════════════════════════════════════════════════════════════════════════
# Ekran Geçişleri
# ══════════════════════════════════════════════════════════════════════════════

func _show_waiting_screen() -> void:
	if waiting_panel: waiting_panel.visible   = true
	if hud_panel:     hud_panel.visible       = false
	if game_over_panel: game_over_panel.visible = false


func _show_hud() -> void:
	if waiting_panel: waiting_panel.visible   = false
	if hud_panel:     hud_panel.visible       = true
	if game_over_panel: game_over_panel.visible = false


func _show_game_over() -> void:
	if waiting_panel: waiting_panel.visible   = false
	if hud_panel:     hud_panel.visible       = false
	if game_over_panel: game_over_panel.visible = true



# ══════════════════════════════════════════════════════════════════════════════
# Sinyal Callback'leri
# ══════════════════════════════════════════════════════════════════════════════

func _on_player_count_changed(current: int, required: int) -> void:
	waiting_label.text = "%d / %d oyuncu" % [current, required]


func _on_game_started() -> void:
	_show_hud()
	if tag_label: tag_label.text = ""
	if max_time_label: max_time_label.text = "Maks: %.0fs" % _game_manager.current_bomb_time



func _on_bomb_transferred(holder_id: int, _new_timer: float, max_timer: float) -> void:
	# Bomba kime geçti, etiket güncelle
	var nick: String = NetworkHandler.connected_players.get(holder_id, "Oyuncu %d" % holder_id)
	if tag_label:
		if holder_id == multiplayer.get_unique_id():
			tag_label.text = "💣 BOMBA SENDE!"
		else:
			tag_label.text = "💣 Bomba: %s" % nick
	if max_time_label: max_time_label.text = "Maks: %.0fs" % max_timer



func _on_pressure_increased(new_max_time: float) -> void:
	# Baskı arttı — etiket geçici olarak vurgula
	if max_time_label: max_time_label.text = "⚡ Maks: %.0fs" % new_max_time



func _on_player_eliminated(eliminated_id: int) -> void:
	var nick: String = NetworkHandler.connected_players.get(eliminated_id, "Oyuncu %d" % eliminated_id)
	if tag_label:
		if eliminated_id == multiplayer.get_unique_id():
			tag_label.text = "💥 PATLADIN! İzleyici modundasın."
		else:
			tag_label.text = "💥 %s PATLADI!" % nick


func _on_game_ended(winner_id: int) -> void:
	_show_game_over()
	var winner_nick: String = NetworkHandler.connected_players.get(winner_id, "Oyuncu %d" % winner_id)
	if result_label:
		if winner_id == multiplayer.get_unique_id():
			result_label.text = "🏆 OYUNU KAZANDIN!"
		elif winner_id == -1:
			result_label.text = "Herkes patladı, kazanan yok."
		else:
			result_label.text = "🏆 %s oyunu kazandı!" % winner_nick



func _on_menu_button_pressed() -> void:
	var gm: Node = get_tree().get_first_node_in_group("game_manager")
	if gm:
		gm.return_to_menu()
