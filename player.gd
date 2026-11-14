class_name Player
extends CharacterBody2D
## Platformer controller + Echo / Recollection abilities. Origin is the player's feet.
## Drawn with placeholder shapes; replace _draw() with an AnimatedSprite2D when art is ready.

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
var _anim := 0.0
var _squash := Vector2.ONE


func _ready() -> void:
	var shape := RectangleShape2D.new()
	shape.size = Vector2(18, 38)
	var col := CollisionShape2D.new()
	col.shape = shape
	col.position = Vector2(0, -19)
	add_child(col)

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
	_anim += delta
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
	queue_redraw()


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


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, _squash)
	var moving := is_on_floor() and absf(velocity.x) > 20.0
	var bob := absf(sin(_anim * 14.0)) * 2.0 if moving else 0.0
	var leg := sin(_anim * 14.0) * 4.0 if moving else 0.0
	var leg_col := Palette.PLAYER_BODY.darkened(0.35)
	draw_rect(Rect2(-7 + leg, -12, 6, 12), leg_col)
	draw_rect(Rect2(1 - leg, -12, 6, 12), leg_col)
	draw_rect(Rect2(-8, -34 - bob, 16, 24), Palette.PLAYER_BODY)
	draw_circle(Vector2(0, -41 - bob), 8.0, Palette.PLAYER_BODY)
	# scarf: neck band plus a tail that trails behind
	draw_rect(Rect2(-8, -36 - bob, 16, 4), Palette.PLAYER_SCARF)
	var tail_x := -18.0 if facing > 0.0 else 8.0
	draw_rect(Rect2(tail_x, -36 - bob + sin(_anim * 8.0) * 2.0, 10, 5), Palette.PLAYER_SCARF)
	draw_rect(Rect2(facing * 3.0 - 1.0, -43 - bob, 2, 3), Palette.INK)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
