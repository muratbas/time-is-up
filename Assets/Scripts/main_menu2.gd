extends Node2D


# ══════════════════════════════════════════════════════════════════════════════
# Başlangıç
# ══════════════════════════════════════════════════════════════════════════════

@onready var click_sound: AudioStreamPlayer = $ClickSound

func _ready() -> void:
	var nick_input: LineEdit = _find_node("UsernameInput") as LineEdit
	if nick_input:
		nick_input.text = PlayerData.nickname
		nick_input.max_length = PlayerData.MAX_NICKNAME_LENGTH

	var ip_input: LineEdit = _find_node("IpInput") as LineEdit
	if ip_input:
		ip_input.placeholder_text = "IP (Boşsa Firebase)"

	var ip_label: Label = _find_node("IpDisplayLabel") as Label
	if ip_label:
		ip_label.visible = false

	var err_label: Label = _find_node("IpErrorLabel") as Label
	if err_label:
		err_label.visible = false

	var lobby_btn: Button = _find_node("LobbyButton") as Button
	if lobby_btn:
		lobby_btn.visible = false

	# Harita seçim butonu ve antrenman modu bağlantıları
	var map_btn: Button = _find_node("MapSelect") as Button
	if map_btn:
		map_btn.text = "HARITA: %s" % PlayerData.get_selected_map_name()
		map_btn.pressed.connect(_on_map_select_pressed)

	var practice_btn: Button = _find_node("Practice") as Button
	if practice_btn:
		practice_btn.pressed.connect(_on_practice_pressed)

	# Firebase lobi sinyallerine bağlan
	LobbyService.lobby_fetched.connect(_on_firebase_lobby_fetched)
	LobbyService.lobby_fetch_failed.connect(_on_firebase_lobby_failed)
	LobbyService.lobby_registered.connect(_on_firebase_lobby_registered)

	# Başlık için retro arcade hafif nabız/nefes efekti
	var title_lbl: Label = _find_node("TitleLabel") as Label
	if title_lbl:
		title_lbl.pivot_offset = title_lbl.size / 2.0
		var tween: Tween = create_tween().set_loops()
		tween.tween_property(title_lbl, "scale", Vector2(1.04, 1.04), 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(title_lbl, "scale", Vector2(1.0, 1.0), 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


# ══════════════════════════════════════════════════════════════════════════════
# Buton Callbackleri
# ══════════════════════════════════════════════════════════════════════════════

func _on_host_pressed() -> void:
	if click_sound: click_sound.play()
	_save_nickname()

	var local_ip: String = PlayerData.get_local_ip()
	PlayerData.server_ip = local_ip

	var ip_label: Label = _find_node("IpDisplayLabel") as Label
	if ip_label:
		ip_label.text = "IP: %s (Firebase'e kaydediliyor...)" % local_ip
		ip_label.visible = true

	var err_label: Label = _find_node("IpErrorLabel") as Label
	if err_label:
		err_label.visible = false

	# Host IP'sini Firebase Realtime Database'e kaydet
	LobbyService.register_debug_lobby(PlayerData.nickname, local_ip, NetworkHandler.PORT)

	# Lobiye Geç butonu aktif edilir
	var lobby_btn: Button = _find_node("LobbyButton") as Button
	if lobby_btn:
		lobby_btn.visible = true


func _on_lobby_pressed() -> void:
	if click_sound: click_sound.play()
	NetworkHandler.is_host = true
	get_tree().change_scene_to_file("res://Assets/Scenes/Levels/waitin_area.tscn")


func _on_join_pressed() -> void:
	if click_sound: click_sound.play()
	var ip_field: LineEdit = _find_node("IpInput") as LineEdit
	var entered_ip: String = ip_field.text.strip_edges() if ip_field else ""
	var err_label: Label = _find_node("IpErrorLabel") as Label

	_save_nickname()

	# Eğer IP kutusu BOŞ ise otomatik olarak Firebase'den host IP'sini çek
	if entered_ip.is_empty():
		if err_label:
			err_label.text = "Firebase'den lobi araniyor..."
			err_label.visible = true
		LobbyService.fetch_debug_lobby()
		return

	# Eğer kullanıcı manuel bir IP yazmışsa doğrulayıp bağlan
	if not _is_valid_ip(entered_ip):
		if err_label:
			err_label.text = "Gecersiz IP! Ornek: 192.168.1.5"
			err_label.visible = true
		return

	_connect_to_ip(entered_ip)


func _on_map_select_pressed() -> void:
	if click_sound: click_sound.play()
	var new_name: String = PlayerData.cycle_map()
	var map_btn: Button = _find_node("MapSelect") as Button
	if map_btn:
		map_btn.text = "HARITA: %s" % new_name


func _on_practice_pressed() -> void:
	if click_sound: click_sound.play()
	_save_nickname()
	get_tree().change_scene_to_file("res://Assets/Scenes/Levels/test_arena.tscn")


# ══════════════════════════════════════════════════════════════════════════════
# Firebase Lobi Callbackleri
# ══════════════════════════════════════════════════════════════════════════════

func _on_firebase_lobby_registered(success: bool) -> void:
	var ip_label: Label = _find_node("IpDisplayLabel") as Label
	if ip_label and ip_label.visible:
		if success:
			ip_label.text = "IP: %s (Firebase'e yazildi!)" % PlayerData.server_ip
		else:
			ip_label.text = "IP: %s (Firebase yazilamadi!)" % PlayerData.server_ip


func _on_firebase_lobby_fetched(ip: String, host_name: String) -> void:
	var ip_field: LineEdit = _find_node("IpInput") as LineEdit
	if ip_field:
		ip_field.text = ip

	var err_label: Label = _find_node("IpErrorLabel") as Label
	if err_label:
		err_label.text = "%s odasina baglaniliyor..." % host_name
		err_label.visible = true

	_connect_to_ip(ip)


func _on_firebase_lobby_failed(error_message: String) -> void:
	var err_label: Label = _find_node("IpErrorLabel") as Label
	if err_label:
		err_label.text = error_message
		err_label.visible = true


func _connect_to_ip(ip: String) -> void:
	PlayerData.server_ip = ip
	var err_label: Label = _find_node("IpErrorLabel") as Label
	if err_label:
		err_label.visible = false

	NetworkHandler.is_host = false
	get_tree().change_scene_to_file("res://Assets/Scenes/Levels/waitin_area.tscn")



func _on_options_pressed() -> void:
	pass # İleride ayarlar sahnesi eklenecek


func _on_quit_pressed() -> void:
	get_tree().quit()


# ══════════════════════════════════════════════════════════════════════════════
# Yardımcılar
# ══════════════════════════════════════════════════════════════════════════════

func _save_nickname() -> void:
	var nick_input: LineEdit = _find_node("UsernameInput") as LineEdit
	var entered: String = nick_input.text.strip_edges() if nick_input else ""
	PlayerData.nickname = entered if entered.length() > 0 else PlayerData.DEFAULT_NICKNAME


## Sahne ağacında isimle node arar — path'den bağımsız
func _find_node(node_name: String) -> Node:
	return find_child(node_name, true, false)


func _is_valid_ip(ip: String) -> bool:
	# "X.X.X.X" formatı; her oktet 0-255 arasında olmalı
	var parts: PackedStringArray = ip.split(".")
	if parts.size() != 4:
		return false
	for part: String in parts:
		if not part.is_valid_int():
			return false
		var value: int = part.to_int()
		if value < 0 or value > 255:
			return false
	return true
