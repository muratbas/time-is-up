extends MultiplayerSynchronizer

# ── Referans ──────────────────────────────────────────────────────────────────
@onready var player: CharacterBody2D = $".."

# ── Input Değişkenleri ────────────────────────────────────────────────────────
# Tüm input RPC ile gönderilir — editörde ReplicationConfig ayarı gerekmez
var input_direction: float = 0.0


# ── Hazırlık ──────────────────────────────────────────────────────────────────

func _ready() -> void:
	set_physics_process(is_multiplayer_authority())
	set_process(is_multiplayer_authority())


# ── Sürekli Input ─────────────────────────────────────────────────────────────

func _physics_process(_delta: float) -> void:
	# Pause menüsü açıkken hareket girdisini sıfırla
	if PauseMenu.is_active:
		if input_direction != 0.0:
			input_direction = 0.0
			_sync_direction.rpc(input_direction)
		return

	var new_dir: float = Input.get_axis("Left", "Right")
	if new_dir != input_direction:
		input_direction = new_dir
		_sync_direction.rpc(input_direction)


# ── Anlık Input ───────────────────────────────────────────────────────────────

func _process(_delta: float) -> void:
	# Pause menüsü açıkken hiçbir eylemi işleme
	if PauseMenu.is_active:
		return

	if Input.is_action_just_pressed("Jump"):
		_send_jump.rpc()
	if Input.is_action_just_released("Jump"):
		_send_jump_cut.rpc()
	if Input.is_action_just_pressed("Punch"):
		_send_punch.rpc()
	if Input.is_action_just_pressed("Special"):
		_send_dash.rpc()



# ── RPC Fonksiyonları ─────────────────────────────────────────────────────────

@rpc("authority", "call_local", "unreliable_ordered")
func _sync_direction(direction: float) -> void:
	input_direction = direction


@rpc("authority", "call_local", "reliable")
func _send_jump() -> void:
	# Brawlhalla tarzı: Duvara yapışmışken duvardan zıplama
	if player.state == player.State.WALL_SLIDING or (player.is_on_wall_only() and not player.is_on_floor()):
		player._execute_wall_jump()
		return

	# Zemin veya Coyote penceresi
	var coyote_available: bool = not player.coyote_timer.is_stopped()
	if player.is_on_floor() or coyote_available:
		player._execute_ground_jump()
	elif player.jumps_remaining > 0:
		player._execute_double_jump()


@rpc("authority", "call_local", "reliable")
func _send_jump_cut() -> void:
	if player.velocity.y < 0.0:
		player.velocity.y *= player.JUMP_CUT_MULTIPLIER


@rpc("authority", "call_local", "reliable")
func _send_punch() -> void:
	if player.state != player.State.PUNCHING and player.state != player.State.DASHING and player.state != player.State.STUNNED:
		player._perform_punch()


@rpc("authority", "call_local", "reliable")
func _send_dash() -> void:
	if player.dash_cooldown_timer <= 0.0 and player.state != player.State.DASHING and player.state != player.State.STUNNED:
		player._perform_dash()

