extends CharacterBody2D

# ── Sinyaller ─────────────────────────────────────────────────────────────────
## Ebelik başka oyuncuya geçtiğinde bildirilir
signal tag_transferred(from_player: Node, to_player: Node)
## Yumruk başarılı bir şekilde hedefe ulaştığında bildirilir
signal hit_landed(target: Node2D)
## Duvardan zıplama yapıldığında bildirilir
signal wall_jumped

# ── Node Referansları ────────────────────────────────────────────────────────
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var coyote_timer: Timer = $CoyoteTimer
@onready var double_jump_effect: AnimatedSprite2D = $DoubleJumpEffect
@onready var punch_hitbox: Area2D = $PunchHitbox
@onready var tnt_marker: Marker2D = $Marker2D
@onready var tnt_sprite: AnimatedSprite2D = $Marker2D/AnimatedSprite2D
@onready var input_sync: MultiplayerSynchronizer = %InputSynchronizer
@onready var nickname_label: Label = $NicknameLabel
@onready var camera: Camera2D = $Camera2D
@onready var jump_sound: AudioStreamPlayer2D = $JumpSound
@onready var dash_sound: AudioStreamPlayer2D = $DashSound
@onready var hurt_sound: AudioStreamPlayer2D = $HurtSound
@onready var explosion_sound: AudioStreamPlayer2D = $ExplosionSound

# ── Multiplayer Kimliği ───────────────────────────────────────────────────────
@export var player_id: int = 1:
	set(id):
		player_id = id
		%InputSynchronizer.set_multiplayer_authority(id)

# ── Baş Üstü Takma Ad ────────────────────────────────────────────────────────
const DISPLAY_MAX_LENGTH: int = 8

var nickname: String = "":
	set(value):
		nickname = value
		if is_node_ready() and nickname_label:
			nickname_label.text = value.left(DISPLAY_MAX_LENGTH) + ("..." if value.length() > DISPLAY_MAX_LENGTH else "")

# ── Brawlhalla Fizik ve Hareket Sabitleri ──────────────────────────────────────
const SPEED: float = 330.0               # Çevik ve seri yatay hareket hızı
const JUMP_VELOCITY: float = -640.0       # Zıplama yüksekliği
const JUMP_CUT_MULTIPLIER: float = 0.35   # Tuştan el çekilince zıplamayı kesme
const MAX_JUMPS: int = 3                  # Toplam zıplama: 1 zemin + 2 hava zıplaması
const JUMP_GRAVITY_MULT: float = 0.92     # Zıplarken havada hafif süzülme (floaty hissi)
const FALL_GRAVITY_MULT: float = 1.38     # Düşerken hızlı iniş (fast-fall hissi)
const MAX_FALL_SPEED: float = 900.0       # Maksimum düşüş hızı limiti

# ── Duvar Mekaniği (Wall Slide & Wall Jump) ───────────────────────────────────
const WALL_SLIDE_SPEED: float = 120.0     # Duvarda aşağı kayma hızı sınırı
const WALL_JUMP_HORIZONTAL: float = 420.0 # Duvardan dışarı itme kuvveti
const WALL_JUMP_VERTICAL: float = -600.0  # Duvardan yukarı fırlama gücü

# ── Dash Mekaniği (Yerde ve Havada) ───────────────────────────────────────────
const DASH_SPEED: float = 720.0           # Hızlı atılma hızı
const DASH_DURATION: float = 0.16         # Dash süresi
const DASH_COOLDOWN: float = 0.65         # Dash tekrar bekleme süresi

# ── Çarpışma ve Vuruş Sabitleri (Knockback & Hitpause) ────────────────────────
const PUNCH_FORCE: float = 680.0          # Yatay savurma kuvveti
const PUNCH_VERTICAL: float = -220.0      # Dikey savurma kuvveti
const STUN_DURATION: float = 0.28         # Sersemleme süresi
const HITPAUSE_DURATION: float = 0.07     # Vuruş duraksama süresi (freeze-frame)

const PLAYER_COLORS: Array[Color] = [
	Color("#FF2D00"), # Kırmızı
	Color("#0055FF"), # Mavi
	Color("#00FF2A"), # Yeşil
	Color("#FFEA00"), # Sarı
	Color("#9D00FF"), # Mor
	Color("#FF8800"), # Turuncu
	Color("#00FFFF"), # Camgöbeği (Cyan)
	Color("#FF00D4"), # Pembe/Magenta
	Color("#FFFFFF"), # Beyaz
	Color("#8B4513")  # Kahverengi
]

# ── State Machine ─────────────────────────────────────────────────────────────
enum State {
	IDLE,
	RUNNING,
	JUMPING,
	FALLING,
	WALL_SLIDING,
	PUNCHING,
	STUNNED,
	ELIMINATED,
	DASHING,
}

var state: State = State.IDLE

# ── Durum Değişkenleri ────────────────────────────────────────────────────────
var jumps_remaining: int = MAX_JUMPS
var is_tag: bool = false
var is_eliminated: bool = false
var stun_timer: float = 0.0
var dash_timer: float = 0.0
var dash_cooldown_timer: float = 0.0
var dash_ghost_timer: float = 0.0
var dash_direction: float = 1.0
var hitpause_timer: float = 0.0
var is_fast_falling: bool = false
var original_modulate: Color = Color.WHITE

# ── Debug ────────────────────────────────────────────────────────────────────
@export var is_dummy: bool = false


# ══════════════════════════════════════════════════════════════════════════════
# Başlangıç
# ══════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	add_to_group("players")

	# Eğer sahnede bağımsız bir MultiTargetCamera varsa bireysel kamera devre dışı bırakılır
	var multi_cam: Node = get_tree().get_first_node_in_group("multi_target_camera")
	if multi_cam:
		$Camera2D.enabled = false
	elif multiplayer.get_unique_id() == player_id:
		$Camera2D.make_current()
	else:
		$Camera2D.enabled = false

	if is_dummy:
		nickname = "DUMMY"
		set_player_color(8) # Nötr beyaz renk
	else:
		# Ağdan güncel takma adı çöz
		var resolved_nick: String = NetworkHandler.connected_players.get(player_id, PlayerData.DEFAULT_NICKNAME)
		nickname = resolved_nick

		# Oyuncu kimliğine göre renk paletini ata
		var keys: Array = NetworkHandler.connected_players.keys()
		keys.sort()
		var color_index: int = keys.find(player_id)
		if color_index == -1:
			color_index = 0
		set_player_color(color_index)

	double_jump_effect.visible = false
	punch_hitbox.monitoring = false
	camera.zoom = Vector2(0.7, 0.7)

	# Ebelik görsel durumu kontrolü
	var gm: Node = get_tree().get_first_node_in_group("game_manager")
	if gm and gm.get("current_tag_id") == player_id:
		become_tag()
	else:
		tnt_marker.visible = false

	# Sinyal bağlantıları
	double_jump_effect.animation_finished.connect(_on_double_jump_animation_finished)
	animated_sprite.animation_finished.connect(_on_player_animation_finished)
	punch_hitbox.body_entered.connect(_on_punch_hitbox_body_entered)


func set_player_color(index: int) -> void:
	# Dışarıdan veya ağdan gelen renk atamasını uygular ve orijinal rengi saklar
	var col: Color = PLAYER_COLORS[index % PLAYER_COLORS.size()]
	original_modulate = col
	animated_sprite.modulate = col


# ══════════════════════════════════════════════════════════════════════════════
# Ana Fizik Döngüsü
# ══════════════════════════════════════════════════════════════════════════════

func _physics_process(delta: float) -> void:
	# Vuruş duraksaması (hitpause) aktifken tüm hareketi mikro dondur
	if hitpause_timer > 0.0:
		hitpause_timer -= delta
		return

	# Test için dummy modu
	if is_dummy:
		_apply_gravity(delta)
		velocity.x = move_toward(velocity.x, 0.0, SPEED * 4.0 * delta)
		move_and_slide()
		_update_animation()
		return

	var was_on_floor: bool = is_on_floor()

	if dash_cooldown_timer > 0.0:
		dash_cooldown_timer -= delta

	# Dash ve duvarda kayma esnasında standart yerçekimi uygulanmaz
	if state != State.DASHING and state != State.WALL_SLIDING:
		_apply_gravity(delta)

	_process_state(delta)
	move_and_slide()
	_post_move(was_on_floor)
	_update_animation()
	_update_sprite_direction()
	_update_bomb_visuals()


# ══════════════════════════════════════════════════════════════════════════════
# State Machine Yönetimi
# ══════════════════════════════════════════════════════════════════════════════

func _process_state(delta: float) -> void:
	match state:
		State.IDLE:
			_state_idle()
		State.RUNNING:
			_state_running()
		State.JUMPING:
			_state_jumping(delta)
		State.FALLING:
			_state_falling(delta)
		State.WALL_SLIDING:
			_state_wall_sliding(delta)
		State.PUNCHING:
			_state_punching()
		State.STUNNED:
			_state_stunned(delta)
		State.ELIMINATED:
			_transition(State.IDLE)
		State.DASHING:
			_state_dashing(delta)


func _transition(new_state: State) -> void:
	state = new_state


# ══════════════════════════════════════════════════════════════════════════════
# Durum Davranışları (States)
# ══════════════════════════════════════════════════════════════════════════════

func _state_idle() -> void:
	# Brawlhalla keskinliği: Kayma ve momentum drifti yok, doğrudan 0
	velocity.x = 0.0

	var direction: float = input_sync.input_direction
	if direction != 0.0:
		_transition(State.RUNNING)
	elif not is_on_floor():
		_transition(State.FALLING)


func _state_running() -> void:
	var direction: float = input_sync.input_direction
	velocity.x = direction * SPEED

	# Tuş bırakıldığı anda kaymadan hemen IDLE durumuna geçilir
	if direction == 0.0:
		velocity.x = 0.0
		_transition(State.IDLE)
	elif not is_on_floor():
		_transition(State.FALLING)


func _state_jumping(_delta: float) -> void:
	# Havada yüksek ve keskin yönlendirme kabiliyeti (Air Control)
	var direction: float = input_sync.input_direction
	velocity.x = direction * SPEED

	# Duvara tutunma kontrolü
	if _check_wall_slide():
		return

	if velocity.y >= 0.0:
		_transition(State.FALLING)


func _state_falling(_delta: float) -> void:
	# Düşüş esnasında da hava kontrolü tam aktiftir
	var direction: float = input_sync.input_direction
	velocity.x = direction * SPEED

	# Duvara tutunma kontrolü (aşağı düşerken duvara yapışabilme)
	if _check_wall_slide():
		return

	if is_on_floor():
		is_fast_falling = false
		jumps_remaining = MAX_JUMPS
		velocity.x = direction * SPEED if direction != 0.0 else 0.0
		_transition(State.RUNNING if direction != 0.0 else State.IDLE)


func _state_wall_sliding(delta: float) -> void:
	# Karakter duvarda yavaşça aşağı kayar
	velocity.y = move_toward(velocity.y, WALL_SLIDE_SPEED, get_gravity().y * 0.5 * delta)
	velocity.x = 0.0

	# Duvara tutunulduğunda oyuncunun geri dönebilmesi için hava zıplama hakkı yenilenir
	if jumps_remaining < MAX_JUMPS - 1:
		jumps_remaining = MAX_JUMPS - 1

	# Eğer zemine ulaşıldıysa veya duvardan ayrıldıysa durumdan çık
	if is_on_floor():
		jumps_remaining = MAX_JUMPS
		_transition(State.IDLE)
	elif not is_on_wall_only():
		_transition(State.FALLING)


func _state_punching() -> void:
	# Yumruk esnasında hava veya yer kontrolü korunur
	var direction: float = input_sync.input_direction
	velocity.x = direction * SPEED


func _state_stunned(delta: float) -> void:
	# Sersemletme sırasında savrulma hızı kademeli olarak durdurulur
	const STUN_FRICTION: float = 1600.0
	velocity.x = move_toward(velocity.x, 0.0, STUN_FRICTION * delta)
	stun_timer -= delta
	if stun_timer <= 0.0:
		if is_on_floor():
			_transition(State.IDLE)
		else:
			_transition(State.FALLING)


func _state_dashing(delta: float) -> void:
	# Dash sırasında yatayda yüksek hız verilir, dikey hız yerçekimine karşı sabitlenir
	velocity.x = dash_direction * DASH_SPEED
	velocity.y = 0.0
	dash_timer -= delta

	# İllüzyon izi (ghost trail)
	dash_ghost_timer -= delta
	if dash_ghost_timer <= 0.0:
		dash_ghost_timer = 0.03
		_create_ghost_trail()

	if dash_timer <= 0.0:
		if is_on_floor():
			_transition(State.RUNNING if input_sync.input_direction != 0.0 else State.IDLE)
		else:
			_transition(State.FALLING)


# ══════════════════════════════════════════════════════════════════════════════
# Eylemler (Zıplama, Duvar Zıplaması, Dash, Yumruk)
# ══════════════════════════════════════════════════════════════════════════════

func _execute_ground_jump() -> void:
	velocity.y = JUMP_VELOCITY
	coyote_timer.stop()
	jumps_remaining = MAX_JUMPS - 1
	_transition(State.JUMPING)
	if jump_sound:
		jump_sound.play()


func _execute_double_jump() -> void:
	velocity.y = JUMP_VELOCITY
	jumps_remaining -= 1
	_transition(State.JUMPING)

	if jump_sound:
		jump_sound.play()

	# Çoklu zıplama puff duman efekti
	double_jump_effect.global_position = global_position
	double_jump_effect.visible = true
	double_jump_effect.play("puff")


func _execute_wall_jump() -> void:
	# Duvardan dışarı ve yukarı fırlama açısı
	var wall_normal: Vector2 = get_wall_normal()
	velocity.x = wall_normal.x * WALL_JUMP_HORIZONTAL
	velocity.y = WALL_JUMP_VERTICAL
	jumps_remaining = MAX_JUMPS - 2 # Duvardan sonra 1 hava zıplaması daha kalsın
	_transition(State.JUMPING)

	if jump_sound:
		jump_sound.play()
	wall_jumped.emit()


func _perform_dash() -> void:
	if is_eliminated:
		return
	_transition(State.DASHING)
	dash_timer = DASH_DURATION
	dash_cooldown_timer = DASH_COOLDOWN
	dash_ghost_timer = 0.0

	var input_dir: float = input_sync.input_direction
	if input_dir != 0.0:
		dash_direction = input_dir
	else:
		dash_direction = -1.0 if animated_sprite.flip_h else 1.0

	animated_sprite.play("tagdash" if is_tag else "dash")
	if dash_sound:
		dash_sound.play()


func _perform_punch() -> void:
	if is_eliminated:
		return
	_transition(State.PUNCHING)
	animated_sprite.play("tagpunch" if is_tag else "punch")
	punch_hitbox.monitoring = true
	punch_hitbox.scale.x = -1.0 if animated_sprite.flip_h else 1.0


# ══════════════════════════════════════════════════════════════════════════════
# Fizik ve Duvar Kontrol Yardımcıları
# ══════════════════════════════════════════════════════════════════════════════

func trigger_fast_fall() -> void:
	# Yerdeyken veya duvardayken fast fall yapılmaz
	if is_on_floor() or state == State.WALL_SLIDING or state == State.DASHING or is_eliminated:
		return
	is_fast_falling = true
	# Karakter yukarı çıkıyorsa dikey hızını anında aşağı çevir, düşüyorsa ekstra ivme ver
	if velocity.y < 350.0:
		velocity.y = 450.0
	else:
		velocity.y += 250.0


func _apply_gravity(delta: float) -> void:
	# Zemin haricinde asimetrik yerçekimi (Floaty yukarı, Fast-Fall aşağı)
	if not is_on_floor() and coyote_timer.is_stopped():
		var grav_y: float = get_gravity().y
		if is_fast_falling:
			# Fast-fall: Hızlı çakılma esnasında çok daha yüksek yerçekimi ve hız limiti
			velocity.y += grav_y * FALL_GRAVITY_MULT * 1.6 * delta
			velocity.y = minf(velocity.y, MAX_FALL_SPEED * 1.35)
		elif velocity.y < 0.0:
			velocity.y += grav_y * JUMP_GRAVITY_MULT * delta
		else:
			velocity.y += grav_y * FALL_GRAVITY_MULT * delta
			velocity.y = minf(velocity.y, MAX_FALL_SPEED)


func _check_wall_slide() -> bool:
	# Havada duvara yaslanıldığında Wall Slide'a geçişi doğrular
	if is_on_wall_only() and not is_on_floor() and velocity.y > 0.0:
		is_fast_falling = false
		_transition(State.WALL_SLIDING)
		return true
	return false


func _post_move(was_on_floor: bool) -> void:
	# Kenardan yürüyerek düşüldüğünde coyote penceresi açılır
	if was_on_floor and not is_on_floor() and velocity.y >= 0.0:
		coyote_timer.start()


# ══════════════════════════════════════════════════════════════════════════════
# Vuruş Hissiyatı (Hitpause, Hitsplat, Screen Shake)
# ══════════════════════════════════════════════════════════════════════════════

func trigger_hitpause(duration: float = HITPAUSE_DURATION) -> void:
	hitpause_timer = duration


func play_hitsplat_effect() -> void:
	# Hitsplat: Vurulan karakterin anlık parlak beyaz parlaması
	animated_sprite.modulate = Color(3.5, 3.5, 3.5, 1.0)
	var tween: Tween = create_tween()
	tween.tween_property(animated_sprite, "modulate", original_modulate, 0.09)


func trigger_screen_shake(intensity: float = 4.0) -> void:
	# Sadece bu oyuncunun yerel kamerasında vuruş darbesi sarsıntısı oluştur
	if camera and camera.is_current():
		var tween: Tween = create_tween()
		tween.tween_property(camera, "offset", Vector2(randf_range(-intensity, intensity), randf_range(-intensity, intensity)), 0.03)
		tween.tween_property(camera, "offset", Vector2(randf_range(-intensity * 0.5, intensity * 0.5), randf_range(-intensity * 0.5, intensity * 0.5)), 0.04)
		tween.tween_property(camera, "offset", Vector2.ZERO, 0.04)


func receive_knockback(force: Vector2) -> void:
	if is_eliminated:
		return
	velocity = force
	stun_timer = STUN_DURATION
	_transition(State.STUNNED)

	# Vurulan karakterde hitsplat, hitpause ve kamera sarsıntısı tetikle
	play_hitsplat_effect()
	trigger_hitpause(HITPAUSE_DURATION)
	trigger_screen_shake(5.0)

	if hurt_sound:
		hurt_sound.play()


func _apply_knockback_to(body: Node2D) -> void:
	if body == self:
		return
	if not body.has_method("receive_knockback"):
		return

	# Vuran oyuncuda mikro freeze-frame ve kamera darbesi oluştur
	trigger_hitpause(HITPAUSE_DURATION)
	trigger_screen_shake(3.0)
	hit_landed.emit(body)

	var direction: float = sign(body.global_position.x - global_position.x)
	if direction == 0.0:
		direction = -1.0 if animated_sprite.flip_h else 1.0
	body.call("receive_knockback", Vector2(direction * PUNCH_FORCE, PUNCH_VERTICAL))


# ══════════════════════════════════════════════════════════════════════════════
# Animasyon ve Görsel Güncellemeler
# ══════════════════════════════════════════════════════════════════════════════

func _update_animation() -> void:
	if animated_sprite.animation == "explode" and animated_sprite.is_playing():
		return

	match state:
		State.IDLE:
			animated_sprite.play("tagidle" if is_tag else "idle")
		State.RUNNING:
			animated_sprite.play("tagrun" if is_tag else "run")
		State.JUMPING:
			animated_sprite.play("jump")
		State.FALLING:
			animated_sprite.play("fall")
		State.WALL_SLIDING:
			animated_sprite.play("taginwall" if is_tag else "inwall")
		State.STUNNED:
			animated_sprite.play("tagidle" if is_tag else "idle")
		State.PUNCHING:
			pass # _perform_punch() içinde başlatılır


func _update_sprite_direction() -> void:
	if state == State.PUNCHING or state == State.DASHING:
		return

	# Duvarda kayarken yüzü duvara dönük olsun
	if state == State.WALL_SLIDING:
		var wall_norm: Vector2 = get_wall_normal()
		animated_sprite.flip_h = (wall_norm.x > 0.0) # Duvar soldaysa sola döner
		return

	if velocity.x > 0.0:
		animated_sprite.flip_h = false
	elif velocity.x < 0.0:
		animated_sprite.flip_h = true


func _create_ghost_trail() -> void:
	var ghost: Sprite2D = Sprite2D.new()
	var tex: Texture2D = animated_sprite.sprite_frames.get_frame_texture(animated_sprite.animation, animated_sprite.frame)
	ghost.texture = tex
	ghost.global_position = animated_sprite.global_position
	ghost.scale = animated_sprite.scale
	ghost.flip_h = animated_sprite.flip_h
	ghost.modulate = original_modulate
	ghost.modulate.a = 0.75
	ghost.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	ghost.z_index = animated_sprite.z_index

	var root: Node = get_tree().current_scene
	if root:
		root.add_child(ghost)
	else:
		get_parent().add_child(ghost)

	var tween: Tween = create_tween()
	tween.tween_property(ghost, "modulate:a", 0.0, 0.35)
	tween.tween_callback(ghost.queue_free)


# ══════════════════════════════════════════════════════════════════════════════
# Ebelik ve Eleme Sistemi
# ══════════════════════════════════════════════════════════════════════════════

func become_tag() -> void:
	is_tag = true
	tnt_marker.visible = true
	tnt_sprite.play("TNT")


func lose_tag() -> void:
	is_tag = false
	tnt_marker.visible = false
	tnt_sprite.stop()
	tnt_sprite.speed_scale = 1.0
	tnt_sprite.modulate = Color.WHITE
	tnt_sprite.scale = Vector2(0.83, 0.87)


func _update_bomb_visuals() -> void:
	if not is_tag or is_eliminated:
		return
	var gm: Node = get_tree().get_first_node_in_group("game_manager")
	if gm and gm.get("game_state") == 1: # GameState.PLAYING
		var timer_val: float = float(gm.get("bomb_timer"))
		if timer_val <= 6.0 and timer_val > 0.0:
			var urgency: float = 1.0 - (timer_val / 6.0)
			# Animasyon oynatma hızı 1.0'dan 3.0'a kadar hızlanır
			tnt_sprite.speed_scale = 1.0 + (urgency * 2.0)
			# Nabız gibi büyüme ve kırmızı-beyaz parıltı efekti
			var pulse: float = (sin(float(Time.get_ticks_msec()) * (0.016 + urgency * 0.024)) + 1.0) * 0.5
			tnt_sprite.scale = Vector2.ONE * (0.83 + pulse * 0.35)
			tnt_sprite.modulate = Color(1.0, 1.0 - (pulse * 0.8), 1.0 - (pulse * 0.8), 1.0)
		else:
			tnt_sprite.speed_scale = 1.0
			tnt_sprite.scale = Vector2(0.83, 0.87)
			tnt_sprite.modulate = Color.WHITE


func eliminate() -> void:
	is_eliminated = true
	_transition(State.IDLE)
	modulate.a = 0.4
	animated_sprite.play("explode")
	if explosion_sound:
		explosion_sound.play()

	# Diğer canlı oyuncuların içinden geçebilmesi için Player katmanını kapat
	set_collision_layer_value(2, false)
	punch_hitbox.monitoring = false
	nickname_label.text += " (ELENDİ)"


# ══════════════════════════════════════════════════════════════════════════════
# Sinyal Geri Çağrıları (Callbacks)
# ══════════════════════════════════════════════════════════════════════════════

func _on_double_jump_animation_finished() -> void:
	double_jump_effect.visible = false


func _on_player_animation_finished() -> void:
	var current: String = animated_sprite.animation

	if current == "explode":
		_transition(State.IDLE)
		update_visibility_for_all()

	if current == "punch" or current == "tagpunch":
		punch_hitbox.monitoring = false
		if is_on_floor():
			var dir: float = input_sync.input_direction
			_transition(State.RUNNING if dir != 0.0 else State.IDLE)
		else:
			_transition(State.FALLING)


func update_visibility_for_all() -> void:
	var local_id: int = multiplayer.get_unique_id()
	var is_local_eliminated: bool = false

	for p: Node in get_tree().get_nodes_in_group("players"):
		if p.get("player_id") == local_id and p.get("is_eliminated"):
			is_local_eliminated = true
			break

	for p: Node in get_tree().get_nodes_in_group("players"):
		if p.get("is_eliminated"):
			p.set("visible", is_local_eliminated)
		else:
			p.set("visible", true)


func _on_punch_hitbox_body_entered(body: Node2D) -> void:
	if state != State.PUNCHING:
		return
	if body == self:
		return
	if body.get("is_eliminated"):
		return

	_apply_knockback_to(body)

	# Ebelik transferi: Sadece ebe olan oyuncu diğerine vurursa
	if not is_tag:
		return
	if not body.has_method("become_tag"):
		return
	if player_id != multiplayer.get_unique_id():
		return

	tag_transferred.emit(self, body)
	var gm: Node = get_tree().get_first_node_in_group("game_manager")
	if not gm:
		return
	if multiplayer.is_server():
		gm.call("request_bomb_transfer", player_id, body.get("player_id"))
	else:
		var rpc_req: Variant = gm.get("rpc_request_transfer")
		if rpc_req:
			rpc_req.rpc_id(1, player_id, body.get("player_id"))
