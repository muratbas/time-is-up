extends Control

func _on_quit_pressed() -> void:
	# ÇIKIŞ butonuna basılınca çalışır
	print("Oyundan çıkılıyor...")
	get_tree().quit()
