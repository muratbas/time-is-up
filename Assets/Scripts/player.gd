extends CharacterBody2D
@onready var animated_sprite_2d = $AnimatedSprite2D
@onready var coyote_timer = $CoyoteTimer

const SPEED = 280.0
const JUMP_VELOCITY = -600.0 # h = v²/(2g) → ~72px with gravity 2500
const JUMP_CUT_MULTIPLIER = 0.35 # Lower = shorter tap jump, higher = closer to full jump
const MAX_JUMPS = 2

var jumps_remaining = MAX_JUMPS


func _physics_process(delta: float) -> void:
	# Store floor state BEFORE move_and_slide
	var was_on_floor = is_on_floor()

	# Reset jumps when on floor
	if is_on_floor():
		jumps_remaining = MAX_JUMPS

	# Animations
	if not is_on_floor() and coyote_timer.is_stopped():
		$AnimatedSprite2D.play("jump")
	elif velocity.x > 1 or velocity.x < -1:
		$AnimatedSprite2D.play("run")
	else:
		$AnimatedSprite2D.play("idle")

	# Flip sprite
	if velocity.x > 0:
		$AnimatedSprite2D.flip_h = false
	elif velocity.x < 0:
		$AnimatedSprite2D.flip_h = true

	# Add gravity (not during coyote window so player doesn't fall immediately)
	if not is_on_floor() and coyote_timer.is_stopped():
		velocity += get_gravity() * delta

	# Handle jump — allow jump on floor, coyote window, or if double jump available
	if Input.is_action_just_pressed("jump"):
		var coyote_available = not coyote_timer.is_stopped()

		if is_on_floor() or coyote_available:
			# Normal / coyote jump — doesn't cost an extra jump
			velocity.y = JUMP_VELOCITY
			coyote_timer.stop()
		elif jumps_remaining > 0:
			# Double jump (in the air)
			velocity.y = JUMP_VELOCITY
			jumps_remaining -= 1

	# Cut jump short when button released early (variable height jump)
	if Input.is_action_just_released("jump") and velocity.y < 0:
		velocity.y *= JUMP_CUT_MULTIPLIER

	# Get the input direction and handle the movement/deceleration.
	var direction := Input.get_axis("left", "right")
	if direction:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	move_and_slide()

	# Start coyote timer when player walks off an edge (uses a jump slot while falling)
	if was_on_floor and not is_on_floor() and velocity.y >= 0:
		coyote_timer.start()
		jumps_remaining -= 1 # Reserve one jump for the coyote/air state
