class_name PauseMenu
extends CanvasLayer

# Menü açıkken karakter kontrollerini engellemek için statik bayrak
static var is_active: bool = false

# ══════════════════════════════════════════════════════════════════════════════
# Başlangıç
# ══════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	# Başlangıçta gizli; ESC ile açılır
	is_active = false
	hide()


func _exit_tree() -> void:
	is_active = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("menu"):
		toggle()


# ══════════════════════════════════════════════════════════════════════════════
# Görünürlük
# ══════════════════════════════════════════════════════════════════════════════

func toggle() -> void:
	if is_visible():
		close_menu()
	else:
		open_menu()


func open_menu() -> void:
	is_active = true
	show()


func close_menu() -> void:
	is_active = false
	hide()



# ══════════════════════════════════════════════════════════════════════════════
# Buton Callbackleri
# ══════════════════════════════════════════════════════════════════════════════

func _on_resume_pressed() -> void:
	# Menüyü kapat, oyun kaldığı yerden devam eder
	close_menu()


func _on_options_pressed() -> void:
	pass # İleride ayarlar eklenecek


func _on_main_menu_pressed() -> void:
	# Bağlantıyı temizle ve ana menüye dön
	NetworkHandler.reset()
	get_tree().change_scene_to_file("res://Assets/Scenes/Menu/main_menu2.tscn")
