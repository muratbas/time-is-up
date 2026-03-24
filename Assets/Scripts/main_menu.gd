extends Control

func _ready():
	# Menü açıldığında Play butonuna otomatik odaklan (Gamepad/Klavye ile menüde gezmek için şarttır)
	$menubuttons/Play.grab_focus()

# --- SİNYALLER (BUTON TIKLAMALARI) ---

func _on_play_button_pressed():
	# OYNA butonuna basılınca çalışır
	print("Oyuna Giriliyor...")
	# 'main.tscn' senin asıl oyun sahnendir, buraya kendi sahne adını yazmalısın.
	get_tree().change_scene_to_file("res://main.tscn")

func _on_options_button_pressed():
	# AYARLAR butonuna basılınca çalışır
	print("Ayarlar menüsü henüz yapım aşamasında!")
	# İleride buraya yeni bir ayarlar sahnesi açma kodu ekleyeceğiz.

func _on_quit_button_pressed():
	# ÇIKIŞ butonuna basılınca çalışır
	print("Oyundan çıkılıyor...")
	get_tree().quit()

func _on_play_pressed() -> void:
	pass # Replace with function body.


func _on_options_pressed() -> void:
	pass # Replace with function body.


func _on_quit_pressed() -> void:
	pass # Replace with function body.
