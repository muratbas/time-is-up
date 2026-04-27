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
	var new_dir: float = Input.get_axis("Left", "Right")
	if new_dir != input_direction:
		input_direction = new_dir
		_sync_direction.rpc(input_direction)


# ── Anlık Input ───────────────────────────────────────────────────────────────

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("Jump"):
		_send_jump.rpc()
	if Input.is_action_just_released("Jump"):
		_send_jump_cut.rpc()
	if Input.is_action_just_pressed("Punch"):
		_send_punch.rpc()


# ── RPC Fonksiyonları ─────────────────────────────────────────────────────────

@rpc("authority", "call_local", "unreliable_ordered")
func _sync_direction(direction: float) -> void:
	input_direction = direction


@rpc("authority", "call_local", "reliable")
func _send_jump() -> void:
	var coyote_available: bool = not player.coyote_timer.is_stopped()
	if player.is_on_floor() or coyote_available:
		player.velocity.y = player.JUMP_VELOCITY
		player.coyote_timer.stop()
		player._transition(player.State.JUMPING)
	elif player.jumps_remaining > 0:
		player._execute_double_jump()


@rpc("authority", "call_local", "reliable")
func _send_jump_cut() -> void:
	if player.velocity.y < 0.0:
		player.velocity.y *= player.JUMP_CUT_MULTIPLIER


@rpc("authority", "call_local", "reliable")
func _send_punch() -> void:
	if player.state != player.State.PUNCHING:
		player._perform_punch()
