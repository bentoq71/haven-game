class_name Watcher
extends Node2D
## The dark silhouette. Origin is its feet.
## mode "ambient": fades away when the player gets close.
## mode "scripted": stays until the game script tells it to vanish.

var player: Node2D
var mode := "ambient"
var alpha := 0.0
var target_alpha := 0.0
var fade_speed := 1.2
var facing := -1.0
var approach_dist := 240.0
var life := 0.0                 # seconds until it leaves on its own (0 = no limit)

var _glow: PointLight2D


func _ready() -> void:
	visible = false
	_glow = PointLight2D.new()
	_glow.texture = Util.radial_texture()
	_glow.color = Color(0.75, 0.8, 1.0)
	_glow.energy = 0.0
	_glow.texture_scale = 1.3
	_glow.position = Vector2(0, -70)
	add_child(_glow)


func is_active() -> bool:
	return target_alpha > 0.0 or alpha > 0.0


func appear(x: float, y: float, face: float, lifetime: float = 0.0) -> void:
	position = Vector2(x, y)
	facing = face
	life = lifetime
	alpha = 0.0
	target_alpha = 1.0
	fade_speed = 1.2


func vanish(fast: bool = false) -> void:
	target_alpha = 0.0
	fade_speed = 4.0 if fast else 1.5


func _process(delta: float) -> void:
	if target_alpha > 0.0 and player != null:
		var dx := player.global_position.x - global_position.x
		facing = 1.0 if dx >= 0.0 else -1.0
		if mode == "ambient" and absf(dx) < approach_dist:
			vanish(true)
	if life > 0.0 and target_alpha > 0.0:
		life -= delta
		if life <= 0.0:
			vanish()
	alpha = move_toward(alpha, target_alpha, delta * fade_speed)
	_glow.energy = alpha * 0.6
	visible = alpha > 0.0
	queue_redraw()


func _draw() -> void:
	if alpha <= 0.0:
		return
	var c := Color(Palette.WATCHER, alpha)
	var body := PackedVector2Array([
		Vector2(-13, -104), Vector2(13, -104), Vector2(19, -40),
		Vector2(11, 0), Vector2(-11, 0), Vector2(-19, -40)
	])
	draw_colored_polygon(body, c)
	draw_circle(Vector2(0, -118), 12.0, c)
	draw_rect(Rect2(-26, -100, 7, 74), c)   # long arms
	draw_rect(Rect2(19, -100, 7, 74), c)
	var outline := body.duplicate()
	outline.append(body[0])
	draw_polyline(outline, Color(0.7, 0.72, 0.85, alpha * 0.35), 1.5)
	var ex := facing * 3.0
	draw_rect(Rect2(-6 + ex, -121, 3, 2), Color(1, 1, 1, alpha))
	draw_rect(Rect2(3 + ex, -121, 3, 2), Color(1, 1, 1, alpha))
