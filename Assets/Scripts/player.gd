extends CharacterBody2D

# ── Node Referansları ────────────────────────────────────────────────────────
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var coyote_timer: Timer = $CoyoteTimer
@onready var double_jump_effect: AnimatedSprite2D = $DoubleJumpEffect
@onready var punch_hitbox: Area2D = $PunchHitbox
@onready var tnt_marker: Marker2D = $Marker2D
@onready var tnt_sprite: AnimatedSprite2D = $Marker2D/AnimatedSprite2D

# ── Sabitler ─────────────────────────────────────────────────────────────────
const SPEED: float = 280.0
const JUMP_VELOCITY: float = -600.0 # h = v²/(2g) → ~72px, yerçekimi 2500 ile
const JUMP_CUT_MULTIPLIER: float = 0.35
const MAX_JUMPS: int = 1
const PUNCH_FORCE: float = 800.0
const PUNCH_VERTICAL: float = -200.0

# ── Sinyal ───────────────────────────────────────────────────────────────────
## Ebelik başka oyuncuya geçtiğinde üst sistemi bilgilendirmek için
signal tag_transferred(from_player: Node, to_player: Node)

# ── State Machine ─────────────────────────────────────────────────────────────
enum State {
	IDLE,
	RUNNING,
	JUMPING,
	FALLING,
	PUNCHING,
}

var state: State = State.IDLE

# ── Durum Değişkenleri ────────────────────────────────────────────────────────
var jumps_remaining: int = MAX_JUMPS
var is_tag: bool = false


# ══════════════════════════════════════════════════════════════════════════════
# Başlangıç
# ══════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	double_jump_effect.visible = false
	tnt_marker.visible = false
	punch_hitbox.monitoring = false

	double_jump_effect.animation_finished.connect(_on_double_jump_animation_finished)
	animated_sprite.animation_finished.connect(_on_player_animation_finished)
	# Kod ile bağlanarak kopuk sinyal riskini ortadan kaldırır
	punch_hitbox.body_entered.connect(_on_punch_hitbox_body_entered)


# ══════════════════════════════════════════════════════════════════════════════
# Ana Döngü
# ══════════════════════════════════════════════════════════════════════════════

func _physics_process(delta: float) -> void:
	var was_on_floor: bool = is_on_floor()

	_apply_gravity(delta)
	_process_state(delta)
	move_and_slide()
	_post_move(was_on_floor)
	_update_animation()
	_update_sprite_direction()


# ══════════════════════════════════════════════════════════════════════════════
# State Machine — Dispatch
# ══════════════════════════════════════════════════════════════════════════════

func _process_state(_delta: float) -> void:
	match state:
		State.IDLE:
			_state_idle()
		State.RUNNING:
			_state_running()
		State.JUMPING:
			_state_jumping()
		State.FALLING:
			_state_falling()
		State.PUNCHING:
			_state_punching()


func _transition(new_state: State) -> void:
	state = new_state


# ══════════════════════════════════════════════════════════════════════════════
# State Machine — State'ler
# ══════════════════════════════════════════════════════════════════════════════

func _state_idle() -> void:
	velocity.x = move_toward(velocity.x, 0.0, SPEED)

	_check_punch()
	_check_jump()

	var direction: float = Input.get_axis("Left", "Right")
	if direction != 0.0:
		_transition(State.RUNNING)
	elif not is_on_floor():
		_transition(State.FALLING)


func _state_running() -> void:
	var direction: float = Input.get_axis("Left", "Right")
	velocity.x = direction * SPEED

	_check_punch()
	_check_jump()

	if direction == 0.0:
		_transition(State.IDLE)
	elif not is_on_floor():
		_transition(State.FALLING)


func _state_jumping() -> void:
	var direction: float = Input.get_axis("Left", "Right")
	velocity.x = direction * SPEED if direction != 0.0 else move_toward(velocity.x, 0.0, SPEED)

	_check_punch()
	_check_jump()
	_check_jump_cut()

	# Zıplama doruk noktasını geçince düşme state'ine geç
	if velocity.y >= 0.0:
		_transition(State.FALLING)


func _state_falling() -> void:
	var direction: float = Input.get_axis("Left", "Right")
	velocity.x = direction * SPEED if direction != 0.0 else move_toward(velocity.x, 0.0, SPEED)

	_check_punch()
	_check_jump()

	if is_on_floor():
		jumps_remaining = MAX_JUMPS
		var move_dir: float = Input.get_axis("Left", "Right")
		_transition(State.RUNNING if move_dir != 0.0 else State.IDLE)


func _state_punching() -> void:
	# Yumruk süresince yatay hareketi durdur; state _on_player_animation_finished'da biter
	velocity.x = move_toward(velocity.x, 0.0, SPEED)


# ══════════════════════════════════════════════════════════════════════════════
# Ortak Eylemler (Birden fazla state'te kullanılır)
# ══════════════════════════════════════════════════════════════════════════════

func _check_punch() -> void:
	if Input.is_action_just_pressed("Punch"):
		_perform_punch()


func _check_jump() -> void:
	if not Input.is_action_just_pressed("Jump"):
		return

	var coyote_available: bool = not coyote_timer.is_stopped()

	if is_on_floor() or coyote_available:
		velocity.y = JUMP_VELOCITY
		coyote_timer.stop()
		_transition(State.JUMPING)
	elif jumps_remaining > 0:
		_execute_double_jump()


func _check_jump_cut() -> void:
	# Düğme erken bırakılırsa zıplama kesilerek değişken yükseklik sağlanır
	if Input.is_action_just_released("Jump") and velocity.y < 0.0:
		velocity.y *= JUMP_CUT_MULTIPLIER


func _execute_double_jump() -> void:
	velocity.y = JUMP_VELOCITY
	jumps_remaining -= 1
	_transition(State.JUMPING)

	# Çift zıplama efekti oyuncunun mevcut konumuna taşınır
	double_jump_effect.global_position = global_position
	double_jump_effect.visible = true
	double_jump_effect.play("puff")


# ══════════════════════════════════════════════════════════════════════════════
# Fizik Yardımcıları
# ══════════════════════════════════════════════════════════════════════════════

func _apply_gravity(delta: float) -> void:
	# Coyote penceresi aktifken yerçekimi uygulanmaz; aksi hâlde oyuncu anında düşer
	if not is_on_floor() and coyote_timer.is_stopped():
		velocity += get_gravity() * delta


func _post_move(was_on_floor: bool) -> void:
	# move_and_slide() sonrası, oyuncu kenara yürüyerek düştüyse coyote timer başlar
	if was_on_floor and not is_on_floor() and velocity.y >= 0.0:
		coyote_timer.start()


# ══════════════════════════════════════════════════════════════════════════════
# Animasyon ve Görsel
# ══════════════════════════════════════════════════════════════════════════════

func _update_animation() -> void:
	match state:
		State.IDLE:
			animated_sprite.play("tagidle" if is_tag else "idle")
		State.RUNNING:
			animated_sprite.play("tagrun" if is_tag else "run")
		State.JUMPING:
			animated_sprite.play("jump")
		State.FALLING:
			animated_sprite.play("fall")
		State.PUNCHING:
			pass # Animasyon _perform_punch() içinde başlatılır, bitmesini bekle


func _update_sprite_direction() -> void:
	# Yumruk animasyonu ortasında sprite'ın dönmesi görsel bozulma yaratır
	if state == State.PUNCHING:
		return

	if velocity.x > 0.0:
		animated_sprite.flip_h = false
	elif velocity.x < 0.0:
		animated_sprite.flip_h = true


# ══════════════════════════════════════════════════════════════════════════════
# Yumruk Sistemi
# ══════════════════════════════════════════════════════════════════════════════

func _perform_punch() -> void:
	_transition(State.PUNCHING)
	# Ebe olduğunda görsel olarak farklı bir yumruk animasyonu oynatılır
	animated_sprite.play("tagpunch" if is_tag else "punch")
	punch_hitbox.monitoring = true
	# Hitbox, oyuncunun baktığı yönle hizalanır
	punch_hitbox.scale.x = -1.0 if animated_sprite.flip_h else 1.0


func receive_knockback(force: Vector2) -> void:
	velocity = force


func _apply_knockback_to(body: Node2D) -> void:
	if body == self:
		return
	if not body.has_method("receive_knockback"):
		return
	var direction: float = sign(body.global_position.x - global_position.x)
	body.receive_knockback(Vector2(direction * PUNCH_FORCE, PUNCH_VERTICAL))


# ══════════════════════════════════════════════════════════════════════════════
# Ebelik Sistemi
# ══════════════════════════════════════════════════════════════════════════════

func become_tag() -> void:
	is_tag = true
	tnt_marker.visible = true
	tnt_sprite.play("TNT")


func _lose_tag() -> void:
	is_tag = false
	tnt_marker.visible = false
	tnt_sprite.stop()


# ══════════════════════════════════════════════════════════════════════════════
# Sinyal Callback'leri
# ══════════════════════════════════════════════════════════════════════════════

func _on_double_jump_animation_finished() -> void:
	double_jump_effect.visible = false


func _on_player_animation_finished() -> void:
	# Yumruk animasyonu bittiğinde hitbox kapatılır ve uygun harekete dönülür
	var current: String = animated_sprite.animation
	if current == "punch" or current == "tagpunch":
		punch_hitbox.monitoring = false
		# Yere basıyorsa IDLE/RUNNING'e, havadaysa FALLING'e geç
		if is_on_floor():
			var dir: float = Input.get_axis("Left", "Right")
			_transition(State.RUNNING if dir != 0.0 else State.IDLE)
		else:
			_transition(State.FALLING)


func _on_punch_hitbox_body_entered(body: Node2D) -> void:
	if body == self:
		return

	_apply_knockback_to(body)

	# Ebelik transferi yalnızca ebe olan oyuncu yumruk attığında gerçekleşir
	if is_tag and body.has_method("become_tag"):
		body.become_tag()
		emit_signal("tag_transferred", self , body)
		_lose_tag()
