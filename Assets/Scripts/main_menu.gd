extends Control

@onready var username_input: LineEdit = $UsernameInput

func _ready() -> void:
	# Daha önce girilmiş bir nick varsa alanı doldur
	username_input.text = PlayerData.nickname
	username_input.max_length = PlayerData.MAX_NICKNAME_LENGTH


func _save_nickname() -> void:
	# Boş bırakılırsa varsayılan isim kullanılır
	var entered: String = username_input.text.strip_edges()
	PlayerData.nickname = entered if entered.length() > 0 else PlayerData.DEFAULT_NICKNAME


func _on_host_pressed() -> void:
	_save_nickname()


func _on_join_pressed() -> void:
	_save_nickname()


func _on_quit_pressed() -> void:
	# ÇIKIŞ butonuna basılınca çalışır
	print("Oyundan çıkılıyor...")
	get_tree().quit()
