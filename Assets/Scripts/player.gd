extends CharacterBody2D
@onready var animated_sprite_2d = $AnimatedSprite2D
@onready var coyote_timer = $CoyoteTimer
@onready var double_jump_effect = $DoubleJumpEffect
@onready var punch_hitbox = $PunchHitbox
@onready var tnt_marker = $Marker2D
@onready var tnt_sprite = $Marker2D/AnimatedSprite2D


const SPEED = 280.0
const JUMP_VELOCITY = -600.0 # h = v²/(2g) → ~72px with gravity 2500
const JUMP_CUT_MULTIPLIER = 0.35 # Lower = shorter tap jump, higher = closer to full jump
const MAX_JUMPS = 1

var jumps_remaining = MAX_JUMPS
var is_punching: bool = false
var punch_force: float = 800.0 # Knockback force
var is_tag: bool = false # Ebe mi?


func _ready() -> void:
	double_jump_effect.visible = false
	tnt_marker.visible = false
	double_jump_effect.animation_finished.connect(_on_double_jump_animation_finished)
	animated_sprite_2d.animation_finished.connect(_on_player_animation_finished)
	punch_hitbox.monitoring = false # Hitbox is off by default


func _on_double_jump_animation_finished() -> void:
	double_jump_effect.visible = false


func _on_player_animation_finished() -> void:
	# When punch animation ends, stop punching
	if animated_sprite_2d.animation == "punch":
		is_punching = false
		punch_hitbox.monitoring = false


func perform_punch() -> void:
	is_punching = true
	animated_sprite_2d.play("punch")
	punch_hitbox.monitoring = true

	# Flip the hitbox to face the same direction as the player
	punch_hitbox.scale.x = -1 if animated_sprite_2d.flip_h else 1

	# Apply knockback to any player already overlapping the hitbox
	for body in punch_hitbox.get_overlapping_bodies():
		if body == self:
			continue
		if body.has_method("receive_knockback"):
			var direction = sign(body.global_position.x - global_position.x)
			body.receive_knockback(Vector2(direction * punch_force, -200.0))


func receive_knockback(force: Vector2) -> void:
	velocity = force


func _physics_process(delta: float) -> void:
	var action_left = "Left"
	var action_right = "Right"
	var action_jump = "Jump"
	var action_punch = "Punch"

	# Store floor state BEFORE move_and_slide
	var was_on_floor = is_on_floor()

	# Reset jumps when on floor
	if is_on_floor():
		jumps_remaining = MAX_JUMPS

	# Animations (punch takes priority, locks other animations)
	if is_punching:
		pass # Animation already set by perform_punch(), don't override it
	elif not is_on_floor() and coyote_timer.is_stopped():
		$AnimatedSprite2D.play("jump")
	elif velocity.x > 1 or velocity.x < -1:
		$AnimatedSprite2D.play("tagrun" if is_tag else "run")
	else:
		$AnimatedSprite2D.play("tagidle" if is_tag else "idle")

	# Flip sprite (only when not punching so the punch doesn't flip mid-animation)
	if not is_punching:
		if velocity.x > 0:
			$AnimatedSprite2D.flip_h = false
		elif velocity.x < 0:
			$AnimatedSprite2D.flip_h = true

	# Add gravity (not during coyote window so player doesn't fall immediately)
	if not is_on_floor() and coyote_timer.is_stopped():
		velocity += get_gravity() * delta

	# Handle punch input
	if Input.is_action_just_pressed(action_punch) and not is_punching:
		perform_punch()

	# Handle jump — allow jump on floor, coyote window, or if double jump available
	if Input.is_action_just_pressed(action_jump):
		var coyote_available = not coyote_timer.is_stopped()

		if is_on_floor() or coyote_available:
			# Normal / coyote jump — doesn't cost an extra jump
			velocity.y = JUMP_VELOCITY
			coyote_timer.stop()
		elif jumps_remaining > 0:
			# Double jump (in the air)
			velocity.y = JUMP_VELOCITY
			jumps_remaining -= 1
			# Show the double jump effect at player's position
			double_jump_effect.global_position = self.global_position
			double_jump_effect.visible = true
			double_jump_effect.play("puff")

	# Cut jump short when button released early (variable height jump)
	if Input.is_action_just_released(action_jump) and velocity.y < 0:
		velocity.y *= JUMP_CUT_MULTIPLIER

	# Get the input direction and handle the movement/deceleration.
	# Yumruk atarken yerinde kal
	if is_punching:
		velocity.x = move_toward(velocity.x, 0, SPEED)
	else:
		var direction := Input.get_axis(action_left, action_right)
		if direction:
			velocity.x = direction * SPEED
		else:
			velocity.x = move_toward(velocity.x, 0, SPEED)

	move_and_slide()

	# Start coyote timer when player walks off an edge (uses a jump slot while falling)
	if was_on_floor and not is_on_floor() and velocity.y >= 0:
		coyote_timer.start()
		jumps_remaining -= 1 # Reserve one jump for the coyote/air state


func become_tag() -> void:
	is_tag = true
	tnt_marker.visible = true
	tnt_sprite.play("TNT")


func _on_punch_hitbox_body_entered(body: Node2D) -> void:
	if body == self:
		return

	var direction = sign(body.global_position.x - global_position.x)

	# Knockback her zaman uygulanır
	if body.has_method("receive_knockback"):
		body.receive_knockback(Vector2(direction * punch_force, -200.0))

	# Ebelik transferi — sadece ebe yumruk atarsa
	if is_tag and body.has_method("become_tag"):
		body.become_tag()
		is_tag = false
		tnt_marker.visible = false
		tnt_sprite.stop()
