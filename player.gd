class_name Player
extends CharacterBody2D
## Platformer controller + Echo / Recollection abilities. Origin is the player's feet.
## Animated from res://art/player.png (see _build_sprite).

signal echo_cast(origin: Vector2)
signal recollect_cast(origin: Vector2)
signal footstep
signal landed

const SPEED := 230.0
const ACCEL := 1600.0
const FRICTION := 1800.0
const GRAVITY := 1200.0
const JUMP_VELOCITY := -450.0
const MAX_FALL := 700.0
const COYOTE := 0.1
const BUFFER := 0.12

const ECHO_RADIUS := 420.0
const ECHO_DURATION := 6.0
const RECOLLECT_RADIUS := 480.0
const RECOLLECT_DURATION := 8.0
const ABILITY_COOLDOWN := 1.2

var controls_enabled := true
var has_echo := false
var has_recollection := false
var facing := 1.0
var glow: PointLight2D

var _coyote := 0.0
var _buffer := 0.0
var _cooldown := 0.0
var _step_timer := 0.0
var _squash := Vector2.ONE
var sprite: AnimatedSprite2D


func _ready() -> void:
	var shape := RectangleShape2D.new()
	shape.size = Vector2(16, 44)
	var col := CollisionShape2D.new()
	col.shape = shape
	col.position = Vector2(0, -22)
	add_child(col)

	_build_sprite()

	glow = PointLight2D.new()
	glow.texture = Util.radial_texture()
	glow.color = Color("ffd9a0")
	glow.energy = 0.4
	glow.texture_scale = 3.0
	glow.position = Vector2(0, -30)
	add_child(glow)


func _physics_process(delta: float) -> void:
	var dir := 0.0
	if controls_enabled:
		dir = Input.get_axis("move_left", "move_right")
	if dir != 0.0:
		velocity.x = move_toward(velocity.x, dir * SPEED, ACCEL * delta)
		facing = signf(dir)
	else:
		velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)

	velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL)

	if is_on_floor():
		_coyote = COYOTE
	else:
		_coyote -= delta
	_buffer -= delta
	if controls_enabled and Input.is_action_just_pressed("jump"):
		_buffer = BUFFER

	if _buffer > 0.0 and _coyote > 0.0:
		velocity.y = JUMP_VELOCITY
		_buffer = 0.0
		_coyote = 0.0
		_squash = Vector2(0.75, 1.3)
	if Input.is_action_just_released("jump") and velocity.y < -150.0:
		velocity.y *= 0.5   # variable jump height

	var was_on_floor := is_on_floor()
	move_and_slide()
	if not was_on_floor and is_on_floor():
		_squash = Vector2(1.3, 0.7)
		landed.emit()

	if is_on_floor() and absf(velocity.x) > 60.0:
		_step_timer -= delta
		if _step_timer <= 0.0:
			_step_timer = 0.3
			footstep.emit()
	else:
		_step_timer = 0.1


func _process(delta: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)
	_squash = _squash.lerp(Vector2.ONE, clampf(delta * 12.0, 0.0, 1.0))
	if controls_enabled and _cooldown <= 0.0:
		var origin := global_position + Vector2(0, -24)
		if has_echo and Input.is_action_just_pressed("echo"):
			_cooldown = ABILITY_COOLDOWN
			get_tree().call_group("echoable", "on_echo", origin, ECHO_RADIUS, ECHO_DURATION)
			echo_cast.emit(origin)
			_squash = Vector2(1.2, 0.85)
		elif has_recollection and Input.is_action_just_pressed("recollect"):
			_cooldown = ABILITY_COOLDOWN
			get_tree().call_group("restorable", "on_recollect", origin, RECOLLECT_RADIUS, RECOLLECT_DURATION)
			recollect_cast.emit(origin)
			_squash = Vector2(1.2, 0.85)
	_update_animation()


## Closest usable Interactable within reach, or null.
func get_nearest_interactable() -> Interactable:
	var best: Interactable = null
	var best_d := 70.0
	for n in get_tree().get_nodes_in_group("interactables"):
		var it := n as Interactable
		if it == null or not it.can_interact():
			continue
		var dx := absf(it.global_position.x - global_position.x)
		var dy := absf(it.global_position.y - global_position.y)
		if dx < best_d and dy < 120.0:
			best = it
			best_d = dx
	return best


# --- Sprite ------------------------------------------------------------------
# res://art/player.png is a strip of 20x27 frames:
#   0-1 idle   2-5 walk   6 jump (rising)   7 fall

const FRAME := Vector2i(20, 27)


func _build_sprite() -> void:
	var sheet := Util.tex("player")
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	_add_anim(frames, sheet, "idle", [0, 1], 2.0)
	_add_anim(frames, sheet, "walk", [2, 3, 4, 5], 9.0)
	_add_anim(frames, sheet, "jump", [6], 1.0)
	_add_anim(frames, sheet, "fall", [7], 1.0)
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = frames
	sprite.centered = false
	# frame is 20 wide; the feet sit on row 25, so the last two rows hang just below the origin
	sprite.offset = Vector2(-FRAME.x / 2.0, -(FRAME.y - 1.0))
	sprite.scale = Vector2(Util.PX, Util.PX)
	add_child(sprite)
	sprite.play("idle")


func _add_anim(frames: SpriteFrames, sheet: Texture2D, anim: String, idx: Array, fps: float) -> void:
	frames.add_animation(anim)
	frames.set_animation_speed(anim, fps)
	frames.set_animation_loop(anim, true)
	for i in idx:
		var at := AtlasTexture.new()
		at.atlas = sheet
		at.region = Rect2(i * FRAME.x, 0, FRAME.x, FRAME.y)
		frames.add_frame(anim, at)


func _update_animation() -> void:
	var want := "idle"
	if not is_on_floor():
		want = "jump" if velocity.y < 0.0 else "fall"
	elif absf(velocity.x) > 20.0:
		want = "walk"
	if sprite.animation != want:
		sprite.play(want)
	sprite.flip_h = facing < 0.0
	sprite.scale = Vector2(Util.PX, Util.PX) * _squash
