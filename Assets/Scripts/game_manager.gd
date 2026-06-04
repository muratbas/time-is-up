extends Node

# ── Sinyaller ─────────────────────────────────────────────────────────────────
signal game_started
signal game_ended(loser_id: int)
signal player_count_changed(current: int, required: int)
signal bomb_transferred(holder_id: int, new_timer: float, max_timer: float)
signal pressure_increased(new_max_time: float)
signal player_eliminated(eliminated_id: int)


# ── Sabitler ──────────────────────────────────────────────────────────────────
const MIN_PLAYERS: int = 2

## Bombanın maksimum tutulma süresinin geçirdiği aşamalar
const TIME_STEPS: Array[float] = [20.0, 10.0, 5.0]

## Kaç başarılı transferde bir süre aşaması azalır
const TRANSFERS_PER_STEP: int = 3

# ── State Machine ─────────────────────────────────────────────────────────────
enum GameState { WAITING, PLAYING, GAME_OVER }

var game_state: GameState = GameState.WAITING
var bomb_timer: float     = 0.0
var current_bomb_time: float = TIME_STEPS[0]
var transfer_count: int   = 0
var current_tag_id: int   = -1
var alive_players: Array[int] = []


# ══════════════════════════════════════════════════════════════════════════════
# Başlangıç
# ══════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	add_to_group("game_manager")
	set_process(true)


func _process(delta: float) -> void:
	if game_state != GameState.PLAYING:
		return
	bomb_timer -= delta
	# Sadece server patlamayı tetikler; clientlar sadece görüntüler
	if bomb_timer <= 0.0 and multiplayer.is_server():
		_explode()


# ══════════════════════════════════════════════════════════════════════════════
# Oyuncu Sayısı Takibi
# ══════════════════════════════════════════════════════════════════════════════

func on_player_joined() -> void:
	if not multiplayer.is_server():
		return
	var count: int = _get_player_count()
	_rpc_player_count_changed.rpc(count)
	if game_state == GameState.WAITING and count >= MIN_PLAYERS:
		_start_game()


func on_player_left() -> void:
	if not multiplayer.is_server():
		return
	var count: int = _get_player_count()
	_rpc_player_count_changed.rpc(count)
	if game_state == GameState.PLAYING and count < MIN_PLAYERS:
		_abort_game()


func _get_player_count() -> int:
	return get_tree().get_nodes_in_group("players").size()


# ══════════════════════════════════════════════════════════════════════════════
# Oyun Başlatma
# ══════════════════════════════════════════════════════════════════════════════

func _start_game() -> void:
	transfer_count    = 0
	current_bomb_time = TIME_STEPS[0]
	alive_players.clear()
	
	# Güvenilir kaynak olarak doğrudan ağdaki bağlı oyuncuların listesini kullanıyoruz.
	# get_nodes_in_group("players") kullanıldığında sahne geçişi sırasında eski oyuncular
	# (silinmek üzere olanlar) gruba dahil kalabiliyor ve listeyi şişirip bug yaratıyordu.
	for id: int in NetworkHandler.connected_players.keys():
		alive_players.append(id)

	_rpc_game_started.rpc()

	# Rastgele bir oyuncuya bomba ver
	_assign_random_tag()



func _assign_random_tag() -> void:
	if alive_players.is_empty():
		return
	var lucky_id: int = alive_players[randi() % alive_players.size()]
	_do_transfer(lucky_id)



# ══════════════════════════════════════════════════════════════════════════════
# Bomba Transferi (Dışarıdan çağrılabilir)
# ══════════════════════════════════════════════════════════════════════════════

## Client tarafından çağrılır; server doğrular
@rpc("any_peer", "reliable")
func rpc_request_transfer(from_id: int, to_id: int) -> void:
	request_bomb_transfer(from_id, to_id)


func request_bomb_transfer(from_id: int, to_id: int) -> void:

	# Sadece server işler; client player.gd'den rpc_id(1,...) ile çağırır
	if not multiplayer.is_server():
		return
	if game_state != GameState.PLAYING:
		return
	if current_tag_id != from_id:
		return  # Bomba bu oyuncuda değil, geçersiz istek

	transfer_count += 1
	_update_pressure()
	_do_transfer(to_id)


func _do_transfer(new_id: int) -> void:
	# Süreyi sıfırla ve bomba yeni oyuncuya geç
	_rpc_transfer_bomb.rpc(new_id, current_bomb_time)


func _update_pressure() -> void:
	# Her TRANSFERS_PER_STEP transferde bir sonraki süre aşamasına geç
	var step_index: int = mini(transfer_count / TRANSFERS_PER_STEP, TIME_STEPS.size() - 1)
	var new_time: float = TIME_STEPS[step_index]
	if not is_equal_approx(new_time, current_bomb_time):
		current_bomb_time = new_time
		_rpc_pressure_increased.rpc(new_time)


func _explode() -> void:
	_rpc_player_eliminated.rpc(current_tag_id)



func _abort_game() -> void:
	_rpc_abort_game.rpc()


# ══════════════════════════════════════════════════════════════════════════════
# RPC'ler — Server → Tüm Peerlar
# ══════════════════════════════════════════════════════════════════════════════

@rpc("authority", "call_local", "reliable")
func _rpc_player_count_changed(count: int) -> void:
	player_count_changed.emit(count, MIN_PLAYERS)


@rpc("authority", "call_local", "reliable")
func _rpc_game_started() -> void:
	game_state = GameState.PLAYING
	game_started.emit()


@rpc("authority", "call_local", "reliable")
func _rpc_transfer_bomb(new_holder_id: int, timer: float) -> void:
	current_tag_id = new_holder_id
	bomb_timer     = timer
	# Tüm oyuncuların ebe durumunu güncelle
	for player: Node in get_tree().get_nodes_in_group("players"):
		if player.player_id == new_holder_id:
			player.become_tag()
		else:
			player.lose_tag()
	bomb_transferred.emit(new_holder_id, timer, current_bomb_time)


@rpc("authority", "call_local", "reliable")
func _rpc_pressure_increased(new_max_time: float) -> void:
	current_bomb_time = new_max_time
	pressure_increased.emit(new_max_time)


@rpc("authority", "call_local", "reliable")
func _rpc_abort_game() -> void:
	game_state = GameState.WAITING
	bomb_timer = 0.0
	for player: Node in get_tree().get_nodes_in_group("players"):
		player.lose_tag()


@rpc("authority", "call_local", "reliable")
func _rpc_player_eliminated(eliminated_id: int) -> void:
	alive_players.erase(eliminated_id)
	player_eliminated.emit(eliminated_id)

	for player: Node in get_tree().get_nodes_in_group("players"):
		if player.player_id == eliminated_id:
			player.eliminate()
			player.lose_tag()

	if not multiplayer.is_server():
		return

	# Eğer sadece 1 kişi kaldıysa, oyunu bitir
	if alive_players.size() <= 1:
		var winner_id: int = alive_players[0] if alive_players.size() > 0 else -1
		_rpc_game_ended.rpc(winner_id)
	else:
		# Oyun devam ediyorsa yeni bir ebe seç
		transfer_count = 0
		current_bomb_time = TIME_STEPS[0]
		_assign_random_tag()


@rpc("authority", "call_local", "reliable")
func _rpc_game_ended(winner_id: int) -> void:
	game_state = GameState.GAME_OVER
	game_ended.emit(winner_id)



# ══════════════════════════════════════════════════════════════════════════════
# Menüye Dönüş
# ══════════════════════════════════════════════════════════════════════════════

@rpc("authority", "call_local", "reliable")
func _rpc_return_to_menu() -> void:
	NetworkHandler.reset()
	get_tree().change_scene_to_file("res://Assets/Scenes/Menu/main_menu2.tscn")


func return_to_menu() -> void:
	if multiplayer.is_server():
		_rpc_return_to_menu.rpc()
	else:
		NetworkHandler.reset()
		get_tree().change_scene_to_file("res://Assets/Scenes/Menu/main_menu2.tscn")
