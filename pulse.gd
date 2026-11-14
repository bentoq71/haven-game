class_name Pulse
extends Node2D
## The expanding ring (plus coloured light) that appears when you cast Echo or Recollection.

var color := Palette.ECHO
var max_radius := 420.0
var duration := 0.9

var _t := 0.0
var _light: PointLight2D


func setup(col: Color, radius: float) -> Pulse:
	color = col
	max_radius = radius
	return self


func _ready() -> void:
	_light = PointLight2D.new()
	_light.texture = Util.radial_texture()
	_light.color = color
	_light.energy = 1.2
	add_child(_light)


func _radius(k: float) -> float:
	return max_radius * (1.0 - pow(1.0 - k, 3.0))


func _process(delta: float) -> void:
	_t += delta
	var k := _t / duration
	if k >= 1.0:
		queue_free()
		return
	_light.texture_scale = maxf(0.01, _radius(k) / 256.0)
	_light.energy = 1.4 * (1.0 - k)
	queue_redraw()


func _draw() -> void:
	var k := clampf(_t / duration, 0.0, 1.0)
	var r := _radius(k)
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 96, Color(color, 1.0 - k), 3.0)
	draw_arc(Vector2.ZERO, r * 0.8, 0.0, TAU, 96, Color(color, (1.0 - k) * 0.4), 2.0)
