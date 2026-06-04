extends Node2D


# ══════════════════════════════════════════════════════════════════════════════
# Başlangıç
# ══════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	var nick_input: LineEdit = _find_node("UsernameInput") as LineEdit
	if nick_input:
		nick_input.text = PlayerData.nickname
		nick_input.max_length = PlayerData.MAX_NICKNAME_LENGTH

	var ip_label: Label = _find_node("IpDisplayLabel") as Label
	if ip_label:
		ip_label.visible = false

	var err_label: Label = _find_node("IpErrorLabel") as Label
	if err_label:
		err_label.visible = false


# ══════════════════════════════════════════════════════════════════════════════
# Buton Callbackleri
# ══════════════════════════════════════════════════════════════════════════════

func _on_host_pressed() -> void:
	_save_nickname()

	var local_ip: String = PlayerData.get_local_ip()
	PlayerData.server_ip = local_ip

	# IP'yi göster; oyuncu bunu arkadaşına iletip sonra Lobiye Geç'e basar
	var ip_label: Label = _find_node("IpDisplayLabel") as Label
	if ip_label:
		ip_label.text = "Sunucu IP: %s" % local_ip
		ip_label.visible = true

	var err_label: Label = _find_node("IpErrorLabel") as Label
	if err_label:
		err_label.visible = false

	# Lobiye Geç butonu aktif edilir; sahne değişimi o butonla yapılır
	var lobby_btn: Button = _find_node("LobbyButton") as Button
	if lobby_btn:
		lobby_btn.visible = true


func _on_lobby_pressed() -> void:
	# Host IP'yi gördükten sonra bu butonla waiting area'ya geçer
	NetworkHandler.is_host = true
	get_tree().change_scene_to_file("res://Assets/Scenes/Levels/waitin_area.tscn")


func _on_join_pressed() -> void:
	var ip_field: LineEdit = _find_node("IpInput") as LineEdit
	var entered_ip: String = ip_field.text.strip_edges() if ip_field else ""

	var err_label: Label = _find_node("IpErrorLabel") as Label

	if not _is_valid_ip(entered_ip):
		if err_label:
			err_label.text = "Geçersiz IP! Örnek: 192.168.1.5"
			err_label.visible = true
		return

	_save_nickname()
	PlayerData.server_ip = entered_ip
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
