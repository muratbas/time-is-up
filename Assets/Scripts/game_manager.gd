extends Node

# ── Sinyaller ─────────────────────────────────────────────────────────────────
signal game_started
signal game_ended(loser_id: int)
signal player_count_changed(current: int, required: int)
signal tag_assigned(player_id: int)

# ── Sabitler ──────────────────────────────────────────────────────────────────
const MIN_PLAYERS: int = 2
const GAME_DURATION: float = 60.0

# ── State Machine ─────────────────────────────────────────────────────────────
enum GameState {
	WAITING,    # Yeterli oyuncu bekleniyor
	PLAYING,    # Oyun devam ediyor
	GAME_OVER,  # Süre doldu
}

var game_state: GameState = GameState.WAITING
var time_remaining: float = GAME_DURATION
var current_tag_id: int = -1


# ══════════════════════════════════════════════════════════════════════════════
# Başlangıç
# ══════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	add_to_group("game_manager")
	# Sadece server oyun zamanını takip eder; bitince RPC ile herkese haber verir
	set_process(multiplayer.is_server())


func _process(delta: float) -> void:
	if game_state != GameState.PLAYING:
		return
	time_remaining -= delta
	if time_remaining <= 0.0:
		_end_game()


# ══════════════════════════════════════════════════════════════════════════════
# Oyuncu Sayısı Takibi (network_handler tarafından çağrılır)
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
	# Oyun sırasında oyuncu sayısı yetersizleşirse beklemeye al
	if game_state == GameState.PLAYING and count < MIN_PLAYERS:
		_abort_game()


func _get_player_count() -> int:
	return get_tree().get_nodes_in_group("players").size()


# ══════════════════════════════════════════════════════════════════════════════
# Oyun Başlatma / Bitirme
# ══════════════════════════════════════════════════════════════════════════════

func _start_game() -> void:
	_assign_random_tag()
	_rpc_game_started.rpc(GAME_DURATION)


func _assign_random_tag() -> void:
	var players: Array[Node] = get_tree().get_nodes_in_group("players")
	if players.is_empty():
		return
	var lucky: Node = players[randi() % players.size()]
	_rpc_assign_tag.rpc(lucky.player_id)


func _abort_game() -> void:
	# Oyuncu sayısı düşünce oyun sıfırlanır, WAITING'e döner
	_rpc_abort_game.rpc()


func _end_game() -> void:
	_rpc_game_ended.rpc(current_tag_id)


# ══════════════════════════════════════════════════════════════════════════════
# RPC'ler — Server → Tüm Peerlar
# ══════════════════════════════════════════════════════════════════════════════

@rpc("authority", "call_local", "reliable")
func _rpc_player_count_changed(count: int) -> void:
	player_count_changed.emit(count, MIN_PLAYERS)


@rpc("authority", "call_local", "reliable")
func _rpc_game_started(duration: float) -> void:
	game_state = GameState.PLAYING
	time_remaining = duration
	game_started.emit()


@rpc("authority", "call_local", "reliable")
func _rpc_assign_tag(player_id: int) -> void:
	current_tag_id = player_id
	# Tüm oyuncuların ebe durumunu sıfırla, doğru olana ver
	for player: Node in get_tree().get_nodes_in_group("players"):
		if player.player_id == player_id:
			player.become_tag()
		else:
			player.lose_tag()
	tag_assigned.emit(player_id)


@rpc("authority", "call_local", "reliable")
func _rpc_abort_game() -> void:
	game_state = GameState.WAITING
	time_remaining = GAME_DURATION
	for player: Node in get_tree().get_nodes_in_group("players"):
		player.lose_tag()


@rpc("authority", "call_local", "reliable")
func _rpc_game_ended(loser_id: int) -> void:
	game_state = GameState.GAME_OVER
	game_ended.emit(loser_id)
