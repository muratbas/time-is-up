extends CanvasLayer

# ══════════════════════════════════════════════════════════════════════════════
# Başlangıç
# ══════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	# Başlangıçta gizli; ESC ile açılır
	# CanvasLayer'da visible yerine hide/show kullanılır
	hide()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("menu"):
		toggle()


# ══════════════════════════════════════════════════════════════════════════════
# Görünürlük
# ══════════════════════════════════════════════════════════════════════════════

func toggle() -> void:
	if is_visible():
		hide()
	else:
		show()



# ══════════════════════════════════════════════════════════════════════════════
# Buton Callbackleri
# ══════════════════════════════════════════════════════════════════════════════

func _on_resume_pressed() -> void:
	# Menüyü kapat, oyun kaldığı yerden devam eder
	visible = false


func _on_options_pressed() -> void:
	pass # İleride ayarlar eklenecek


func _on_main_menu_pressed() -> void:
	# Bağlantıyı temizle ve ana menüye dön
	NetworkHandler.reset()
	get_tree().change_scene_to_file("res://Assets/Scenes/Menu/main_menu2.tscn")
