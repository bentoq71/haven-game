class_name Backdrop
extends Node2D
## Draws the pre-painted background of each area (res://art/bg_N.png), plus everything that
## needs to change at runtime: chairs, paintings, corridor doors, flickering flames.
##
## `anomaly[i]` counts how many times area i has "changed" behind the player; it drives
## the environmental horror (chairs move, paintings change, doors vanish).

var anomaly: Array = [0, 0, 0, 0]
var view_x := 0.0


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var t := Time.get_ticks_msec() / 1000.0
	for i in 4:
		var x0: float = Util.AREA_X[i]
		var x1: float = Util.AREA_X[i + 1]
		if x1 < view_x - 640.0 or x0 > view_x + 640.0:
			continue
		var bg := Util.tex("bg_%d" % i)
		draw_texture_rect(bg, Rect2(x0, 0, bg.get_width() * Util.PX, bg.get_height() * Util.PX), false)
		match i:
			0:
				_ballroom(x0, t)
			1:
				_gallery(x0, t)
			2:
				_corridor(x0, x1, t)
			3:
				_forgotten(x0, x1, t)
	# the pits: nothing at all down there
	_void(2000.0, 2500.0)
	_void(3500.0, 3950.0)
	for i in range(1, 4):
		_fracture(Util.AREA_X[i], i)


func _void(x0: float, x1: float) -> void:
	if x1 < view_x - 640.0 or x0 > view_x + 640.0:
		return
	draw_rect(Rect2(x0, Util.FLOOR_Y, x1 - x0, 140.0), Color("05040a"))
	# stepped, dithered edge so it doesn't look like a flat rectangle
	var x := x0
	while x < x1:
		draw_rect(Rect2(x, Util.FLOOR_Y - 4.0 + (int(x / 8.0) % 2) * 4.0, 4, 4), Color("05040a"))
		x += 8.0


## The tear in the world between two areas.
func _fracture(x: float, i: int) -> void:
	if absf(x - view_x) > 700.0:
		return
	var edge := Palette.GALLERY_ACCENT if i == 1 else Palette.CORRIDOR_ACCENT if i == 2 else Palette.FORGOTTEN_ACCENT
	var y := 0.0
	while y < Util.FLOOR_Y:
		var jx := x + (int(sin(y * 0.19) * 3.0)) * 4.0
		draw_rect(Rect2(jx - 4, y, 8, 16), Color("07050c"))
		draw_rect(Rect2(jx - 6, y, 2, 16), Color(edge, 0.55))
		draw_rect(Rect2(jx + 4, y, 2, 16), Color(edge, 0.55))
		y += 16.0


# --- Area I: Ballroom ------------------------------------------------------

func _ballroom(x0: float, t: float) -> void:
	# candle flames on the two chandeliers (the rest is painted into the background)
	for cx in [300.0, 860.0]:
		for k in 5:
			var fx: float = x0 + cx - 28.0 + k * 14.0
			var flick := 0.75 + 0.25 * sin(t * 9.0 + k * 1.7 + cx)
			draw_circle(Vector2(fx, 108), 12.0, Color(1.0, 0.8, 0.4, 0.07 * flick))
			draw_rect(Rect2(fx - 2, 108.0 + (1 - flick) * 4.0, 4, 6), Color(1.0, 0.85, 0.45))
			draw_rect(Rect2(fx - 1, 110.0 + (1 - flick) * 4.0, 2, 4), Color(1.0, 0.97, 0.8))
	# chairs: they move and vanish as you come and go
	var v: int = anomaly[0]
	var chair := Util.tex("chair")
	var base_x := [320.0, 470.0, 880.0, 1030.0]
	for i in 4:
		var px: float = x0 + base_x[i]
		var flip := 1.0
		if v >= 1 and i == 1:
			px += 60.0
			flip = -1.0
		if v >= 2 and i == 2:
			continue
		var s := chair.get_size() * Util.PX
		if v >= 3 and i == 0:
			draw_set_transform(Vector2(px, Util.FLOOR_Y - 14.0), -PI / 2.0, Vector2(flip, 1.0))
			draw_texture_rect(chair, Rect2(Vector2(-s.x * 0.5, -s.y), s), false)
		else:
			draw_set_transform(Vector2(px, Util.FLOOR_Y), 0.0, Vector2(flip, 1.0))
			draw_texture_rect(chair, Rect2(Vector2(-s.x * 0.5, -s.y), s), false)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# --- Area II: Gallery ------------------------------------------------------

func _gallery(x0: float, t: float) -> void:
	var px := [180.0, 430.0, 1240.0, 1390.0]
	for i in 4:
		_painting(x0 + px[i], 250.0, i, t)


func _painting(cx: float, cy: float, idx: int, t: float) -> void:
	var tilt := 0.04 * sin(t * 0.5 + idx * 1.7)
	var v: int = anomaly[1] % 4
	draw_set_transform(Vector2(cx, cy), tilt, Vector2.ONE)
	draw_texture_rect_region(Util.tex("paintings"), Rect2(-42, -54, 84, 108), Rect2(v * 42, idx * 54, 42, 54))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# --- Area III: Corridor ----------------------------------------------------

func _corridor(x0: float, x1: float, t: float) -> void:
	var v: int = anomaly[2]
	var door := Util.tex("corridor_door")
	var lamp := Util.tex("hang_lamp")
	for idx in 9:
		var x := x0 + 80.0 + idx * 160.0
		var flick := 0.55 + 0.45 * sin(t * 2.6 + idx * 1.3)
		if v >= 2 and fmod(t + idx, 3.0) < 0.15:
			flick = 0.0
		if idx != 7:
			var ls := lamp.get_size() * Util.PX
			draw_texture_rect(lamp, Rect2(x - ls.x * 0.5, 0, ls.x, ls.y), false, Color(1, 1, 1, 0.55 + 0.45 * flick))
			for g in 3:
				draw_circle(Vector2(x, 96), 40.0 - g * 11.0, Color(Palette.MEMORY, (0.04 + g * 0.04) * flick))
		else:
			# one lamp is just a dead fitting
			draw_rect(Rect2(x - 2, 0, 4, 60), Color("2a2036"))
		if not (v >= 1 and idx == 4):
			Util.draw_px(self, door, Vector2(x, Util.FLOOR_Y))


# --- Area IV: Forgotten Room -----------------------------------------------

func _forgotten(x0: float, x1: float, t: float) -> void:
	for k in 36:
		var px := x0 + fmod(k * 137.0 + t * (6.0 + (k % 5) * 3.0), x1 - x0)
		var py := 60.0 + fmod(k * 71.0 - t * (4.0 + (k % 3) * 2.0) + 2000.0, 480.0)
		draw_rect(Rect2(floorf(px / 2.0) * 2.0, floorf(py / 2.0) * 2.0, 2, 2),
				Color(0.8, 0.75, 0.9, 0.12 + 0.1 * sin(t + k)))
