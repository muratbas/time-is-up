extends CanvasLayer

var _game_manager: Node = null

# ── Node Referansları (dinamik; path bağımsız) ────────────────────────────────
var hud_panel: Control
var timer_label: Label
var tag_label: Label
var game_over_panel: Control
var result_label: Label
var ping_label: Label
var ten_seconds_sound: AudioStreamPlayer
var win_sound: AudioStreamPlayer
var vignette_rect: ColorRect
var tick_sound: AudioStreamPlayer

var _has_played_10s_sound: bool = false
var _tick_timer: float = 0.0

# ══════════════════════════════════════════════════════════════════════════════
# Başlangıç
# ══════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	# Node referanslarını isimle bul — path'e bağımlı değil
	hud_panel = find_child("HUDPanel", true, false) as Control
	timer_label = find_child("TimerLabel", true, false) as Label
	tag_label = find_child("TagLabel", true, false) as Label
	game_over_panel = find_child("GameOverPanel", true, false) as Control
	result_label = find_child("ResultLabel", true, false) as Label
	ping_label = find_child("PingLabel", true, false) as Label
	ten_seconds_sound = find_child("TenSecondsSound", true, false) as AudioStreamPlayer
	win_sound = find_child("WinSound", true, false) as AudioStreamPlayer
	vignette_rect = find_child("VignetteRect", true, false) as ColorRect
	tick_sound = find_child("TickSound", true, false) as AudioStreamPlayer

	if vignette_rect:
		vignette_rect.visible = false

	await get_tree().process_frame
	_game_manager = get_tree().get_first_node_in_group("game_manager")

	if _game_manager:
		_game_manager.game_started.connect(_on_game_started)
		_game_manager.game_ended.connect(_on_game_ended)
		_game_manager.bomb_transferred.connect(_on_bomb_transferred)
		_game_manager.player_eliminated.connect(_on_player_eliminated)

		# Sinyaller bağlanmadan önce oyun başlamış olabilir, mevcut duruma göre arayüzü ayarla
		if _game_manager.game_state == 1: # GameState.PLAYING
			_on_game_started()
			if _game_manager.current_tag_id != -1:
				_on_bomb_transferred(_game_manager.current_tag_id, _game_manager.bomb_timer, _game_manager.current_bomb_time)
		elif _game_manager.game_state == 2: # GameState.GAME_OVER
			_show_game_over()
		else:
			_show_hud()
	else:
		_show_hud()


# ══════════════════════════════════════════════════════════════════════════════
# Frame Döngüsü — Bomba Sayacı
# ══════════════════════════════════════════════════════════════════════════════

func _process(_delta: float) -> void:
	# Ping gösterimi (Her 30 karede bir güncellenir ki yormasın)
	if ping_label and Engine.get_frames_drawn() % 30 == 0:
		var enet_peer = multiplayer.multiplayer_peer as ENetMultiplayerPeer
		if enet_peer:
			if multiplayer.is_server():
				ping_label.text = "PING: 0 MS (HOST)"
			else:
				var server_peer = enet_peer.get_peer(1)
				if server_peer:
					var ping = server_peer.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME)
					ping_label.text = "PING: %d MS" % ping

	if _game_manager == null:
		return

	if _game_manager.game_state != _game_manager.GameState.PLAYING:
		return
	# Bomba sayacını her frame güncelle
	var t: float = maxf(_game_manager.bomb_timer, 0.0)
	timer_label.text = "%.1f" % t

	# Son 6 saniye: Gerilim Efektleri (Nabız atan kırmızı vinyet ve hızlanan tık-tık sesi)
	if t <= 6.0 and t > 0.0:
		timer_label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2, 1.0))
		var urgency: float = 1.0 - (t / 6.0)

		# 1. Kırmızı Vinyet Nabız Efekti
		if vignette_rect:
			vignette_rect.visible = true
			var pulse_speed: float = 0.012 + (urgency * 0.018)
			var pulse: float = (sin(float(Time.get_ticks_msec()) * pulse_speed) + 1.0) * 0.5
			var vignette_intensity: float = (0.3 + 0.5 * urgency) * (0.65 + 0.35 * pulse)
			(vignette_rect.material as ShaderMaterial).set_shader_parameter("intensity", vignette_intensity)

		# 2. Hızlanan Tık-Tık Sesi (Gerilim Ticking)
		_tick_timer -= _delta
		var tick_interval: float = lerpf(0.65, 0.14, urgency)
		if _tick_timer <= 0.0:
			_tick_timer = tick_interval
			if tick_sound:
				tick_sound.pitch_scale = 1.0 + (urgency * 0.8)
				tick_sound.play()
	else:
		if vignette_rect and vignette_rect.visible:
			vignette_rect.visible = false
		if t <= 10.0 and t > 0.0:
			timer_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.2, 1.0))
			if not _has_played_10s_sound:
				if ten_seconds_sound:
					ten_seconds_sound.play()
				_has_played_10s_sound = true
		else:
			timer_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2, 1.0))
			if _has_played_10s_sound:
				_has_played_10s_sound = false
				if ten_seconds_sound:
					ten_seconds_sound.stop()


# ══════════════════════════════════════════════════════════════════════════════
# Ekran Geçişleri
# ══════════════════════════════════════════════════════════════════════════════

func _show_hud() -> void:
	if hud_panel: hud_panel.visible = true
	if game_over_panel: game_over_panel.visible = false


func _show_game_over() -> void:
	if vignette_rect: vignette_rect.visible = false
	if hud_panel: hud_panel.visible = false
	if game_over_panel: game_over_panel.visible = true


# ══════════════════════════════════════════════════════════════════════════════
# Sinyal Callback'leri
# ══════════════════════════════════════════════════════════════════════════════

func _on_game_started() -> void:
	_show_hud()
	if tag_label: tag_label.text = ""


func _on_bomb_transferred(holder_id: int, _new_timer: float, _max_timer: float) -> void:
	var nick: String = NetworkHandler.connected_players.get(holder_id, "Oyuncu %d" % holder_id)
	if tag_label:
		if holder_id == multiplayer.get_unique_id():
			tag_label.text = "BOMBA SENDE! BASKASINA VUR!"
			tag_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		else:
			tag_label.text = "EBE: %s (KAC!)" % nick
			tag_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2))


func _on_player_eliminated(eliminated_id: int) -> void:
	var nick: String = NetworkHandler.connected_players.get(eliminated_id, "Oyuncu %d" % eliminated_id)
	if tag_label:
		if eliminated_id == multiplayer.get_unique_id():
			tag_label.text = "PATLADIN! IZLEYICI MODUNDASIN."
			tag_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		else:
			tag_label.text = "%s ELENDI!" % nick
			tag_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))


func _on_game_ended(winner_id: int) -> void:
	if win_sound: win_sound.play()
	_show_game_over()
	var winner_nick: String = NetworkHandler.connected_players.get(winner_id, "Oyuncu %d" % winner_id)

	if result_label:
		if winner_id == multiplayer.get_unique_id():
			result_label.text = "TEBRIKLER, OYUNU KAZANDIN!"
			result_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.4))
		elif winner_id == -1:
			result_label.text = "HERKES PATLADI! KAZANAN CIKMADI."
			result_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
		else:
			result_label.text = "KAZANAN: %s" % winner_nick
			result_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))


func _on_restart_button_pressed() -> void:
	var gm: Node = get_tree().get_first_node_in_group("game_manager")
	if gm:
		if multiplayer.is_server():
			gm.restart_game()
		else:
			print("Sadece host oyunu yeniden baslatabilir.")


func _on_menu_button_pressed() -> void:
	var gm: Node = get_tree().get_first_node_in_group("game_manager")
	if gm and gm.has_method("return_to_menu"):
		gm.return_to_menu()
	else:
		NetworkHandler.reset()
		get_tree().change_scene_to_file("res://Assets/Scenes/Menu/main_menu2.tscn")

