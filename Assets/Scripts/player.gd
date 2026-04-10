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
const JUMP_CUT_MULTIPLIER: float = 0.35 # Düşük = kısa dokunuş, yüksek = tam zıplama
const MAX_JUMPS: int = 1
const PUNCH_FORCE: float = 800.0
const PUNCH_VERTICAL: float = -200.0

# ── Sinyaller ────────────────────────────────────────────────────────────────
## Ebelik başka oyuncuya geçtiğinde üst sistemi bilgilendirmek için
signal tag_transferred(from_player: Node, to_player: Node)

# ── Durum Değişkenleri ───────────────────────────────────────────────────────
var jumps_remaining: int = MAX_JUMPS
var is_punching: bool = false
var is_tag: bool = false


# ══════════════════════════════════════════════════════════════════════════════
# Başlangıç
# ══════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	double_jump_effect.visible = false
	tnt_marker.visible = false
	punch_hitbox.monitoring = false # Performans için varsayılan olarak kapalı

	double_jump_effect.animation_finished.connect(_on_double_jump_animation_finished)
	animated_sprite.animation_finished.connect(_on_player_animation_finished)
	# Editor bağlantısına güvenmek yerine kod ile bağlanır; kopuk sinyal riskini ortadan kaldırır
	punch_hitbox.body_entered.connect(_on_punch_hitbox_body_entered)


# ══════════════════════════════════════════════════════════════════════════════
# Ana Döngü
# ══════════════════════════════════════════════════════════════════════════════

func _physics_process(delta: float) -> void:
	# Sadece bu peer'ın sahibi olan oyuncu girdi işlemeli
	if not is_multiplayer_authority():
		return

	# move_and_slide öncesi zemin durumu saklanır, coyote tespiti için
	var was_on_floor: bool = is_on_floor()

	_reset_jumps_if_grounded()
	_apply_gravity(delta)
	_handle_punch_input()
	_handle_jump_input()
	_handle_jump_cut()
	_handle_movement()
	_update_animation()
	_update_sprite_direction()

	move_and_slide()

	_start_coyote_if_walked_off(was_on_floor)


# ══════════════════════════════════════════════════════════════════════════════
# Fizik Alt Fonksiyonları
# ══════════════════════════════════════════════════════════════════════════════

func _reset_jumps_if_grounded() -> void:
	if is_on_floor():
		jumps_remaining = MAX_JUMPS


func _apply_gravity(delta: float) -> void:
	# Coyote penceresi aktifken yerçekimi uygulanmaz; aksi hâlde oyuncu anında düşer
	if not is_on_floor() and coyote_timer.is_stopped():
		velocity += get_gravity() * delta


func _handle_punch_input() -> void:
	if Input.is_action_just_pressed("Punch") and not is_punching:
		perform_punch()


func _handle_jump_input() -> void:
	if not Input.is_action_just_pressed("Jump"):
		return

	var coyote_available: bool = not coyote_timer.is_stopped()

	if is_on_floor() or coyote_available:
		_execute_jump()
		coyote_timer.stop()
	elif jumps_remaining > 0:
		_execute_double_jump()


func _execute_jump() -> void:
	velocity.y = JUMP_VELOCITY


func _execute_double_jump() -> void:
	velocity.y = JUMP_VELOCITY
	jumps_remaining -= 1

	# Çift zıplama efekti oyuncunun mevcut konumuna taşınır
	double_jump_effect.global_position = global_position
	double_jump_effect.visible = true
	double_jump_effect.play("puff")


func _handle_jump_cut() -> void:
	# Düğme erken bırakılırsa zıplama kesilerek değişken yükseklik sağlanır
	if Input.is_action_just_released("Jump") and velocity.y < 0:
		velocity.y *= JUMP_CUT_MULTIPLIER


func _handle_movement() -> void:
	if is_punching:
		# Yumruk animasyonu sırasında kayma hissi vermemek için hız sıfırlanır
		velocity.x = move_toward(velocity.x, 0.0, SPEED)
		return

	var direction: float = Input.get_axis("Left", "Right")
	if direction != 0.0:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0.0, SPEED)


func _start_coyote_if_walked_off(was_on_floor: bool) -> void:
	# Oyuncu zıplamadan kenara yürüdüğünde coyote süresi başlatılır
	if was_on_floor and not is_on_floor() and velocity.y >= 0.0:
		coyote_timer.start()
		# jumps_remaining düşürülmez; coyote zıplaması zemin zıplaması sayılır,
		# bu sayede coyote sonrası double jump hakkı kaybolmaz


# ══════════════════════════════════════════════════════════════════════════════
# Animasyon ve Görsel
# ══════════════════════════════════════════════════════════════════════════════

func _update_animation() -> void:
	# Yumruk animasyonu bitmeden diğer animasyonların üzerine yazılmasını engeller
	if is_punching:
		return

	if not is_on_floor() and coyote_timer.is_stopped():
		animated_sprite.play("jump")
	elif absf(velocity.x) > 1.0:
		animated_sprite.play("tagrun" if is_tag else "run")
	else:
		animated_sprite.play("tagidle" if is_tag else "idle")


func _update_sprite_direction() -> void:
	# Yumruk animasyonu ortasında sprite'ın dönmesi görsel bozulma yaratır
	if is_punching:
		return

	if velocity.x > 0.0:
		animated_sprite.flip_h = false
	elif velocity.x < 0.0:
		animated_sprite.flip_h = true


# ══════════════════════════════════════════════════════════════════════════════
# Yumruk Sistemi
# ══════════════════════════════════════════════════════════════════════════════

func perform_punch() -> void:
	is_punching = true
	# Ebe olduğunda görsel olarak farklı bir yumruk animasyonu oynatılır
	animated_sprite.play("tagpunch" if is_tag else "punch")
	punch_hitbox.monitoring = true

	# Hitbox, oyuncunun baktığı yönle hizalanır
	punch_hitbox.scale.x = -1.0 if animated_sprite.flip_h else 1.0
	# Anlık overlap kontrolü kaldırıldı: monitoring yeni açıldığında Godot aynı
	# frame'de çakışma hesaplamaz, bu yüzden body_entered sinyaline güvenilir



func _apply_knockback_to(body: Node2D) -> void:
	if body == self:
		return
	if not body.has_method("receive_knockback"):
		return

	var direction: float = sign(body.global_position.x - global_position.x)
	body.receive_knockback(Vector2(direction * PUNCH_FORCE, PUNCH_VERTICAL))


func receive_knockback(force: Vector2) -> void:
	velocity = force


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
	# Yumruk animasyonu bittiğinde hitbox'ı hemen kapatmak gerekir; aksi hâlde
	# bir frame gecikmeli kapanma çakışma hatalarına yol açabilir
	var current: String = animated_sprite.animation
	if current == "punch" or current == "tagpunch":
		is_punching = false
		punch_hitbox.monitoring = false


func _on_punch_hitbox_body_entered(body: Node2D) -> void:
	if body == self:
		return

	_apply_knockback_to(body)

	# Ebelik transferi yalnızca ebe olan oyuncu yumruk attığında gerçekleşir
	if is_tag and body.has_method("become_tag"):
		body.become_tag()
		emit_signal("tag_transferred", self , body)
		_lose_tag()
