extends Control

func _ready():
	# Menü açıldığında Play butonuna otomatik odaklan
	$menubuttons/Play.grab_focus()

# --- SİNYALLER (BUTON TIKLAMALARI) ---

func _on_play_pressed() -> void:
	# OYNA butonuna basılınca çalışır
	print("Oyuna Giriliyor...")
	# 'main.tscn' senin asıl oyun sahnendir.
	get_tree().change_scene_to_file("res://Assets/Scenes/main.tscn")

func _on_quit_pressed() -> void:
	# ÇIKIŞ butonuna basılınca çalışır
	print("Oyundan çıkılıyor...")
	get_tree().quit()