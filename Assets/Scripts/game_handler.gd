extends Node

# --- AYARLAR ---
@export var countdown_duration: float = 3.0 # Oyun başlamadan önceki geri sayım

# --- İÇ DEĞİŞKENLER ---
var players: Array = []
var current_tag_player = null
var game_started: bool = false


func _ready() -> void:
	# Sahnedeki tüm oyuncuları bul
	# Oyuncuların "players" grubunda olması gerekiyor!
	players = get_tree().get_nodes_in_group("players")

	if players.is_empty():
		push_error("GameHandler: Sahnede 'players' grubunda hiç oyuncu bulunamadı!")
		return

	print("GameHandler: %d oyuncu bulundu." % players.size())

	# Kısa bir gecikme sonrası rastgele ebe seç ve oyunu başlat
	await get_tree().create_timer(countdown_duration).timeout
	start_game()


func start_game() -> void:
	game_started = true
	print("Oyun başladı! J tuşuyla ebeliği test edebilirsin.")


func assign_random_tag() -> void:
	# Önce herkesi ebe olmaktan çıkar
	for player in players:
		player.is_tag = false

	# Rastgele bir oyuncuyu ebe yap
	var new_tag = players.pick_random()
	new_tag.become_tag()
	current_tag_player = new_tag

	print("Ebe: %s" % new_tag.name)


func get_current_tag() -> Node:
	return current_tag_player


func _input(event: InputEvent) -> void:
	# TEST: J tuşuna basınca ilk oyuncuya ebelik ver/al
	if event is InputEventKey and event.pressed and event.keycode == KEY_J:
		if players.is_empty():
			return
		var player = players[0]
		if player.is_tag:
			player.is_tag = false
			player.tnt_marker.visible = false
			player.tnt_sprite.stop()
			print("Ebelik alındı.")
		else:
			player.become_tag()
			print("Ebelik verildi.")


# Her frame'de güncel ebeyi takip et (isteğe bağlı, UI için kullanılabilir)
func _process(_delta: float) -> void:
	if not game_started:
		return

	# Ebeyi bul ve güncelle
	for player in players:
		if player.is_tag:
			current_tag_player = player
			return

	current_tag_player = null
