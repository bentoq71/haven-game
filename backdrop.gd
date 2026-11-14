class_name Backdrop
extends Node2D
## Draws the walls and decorations of all four areas. Pure placeholder art.
## `anomaly[i]` counts how many times area i has "changed" behind the player; it drives
## the environmental horror (chairs move, paintings change, doors vanish).

const PAINT_COLORS := [Color("7a8a6a"), Color("8a7a6a"), Color("6a7a8a"), Color("8a6a7a")]

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
		match i:
			0:
				_ballroom(x0, x1, t)
			1:
				_gallery(x0, x1, t)
			2:
				_corridor(x0, x1, t)
			3:
				_forgotten(x0, x1, t)
		if i > 0:
			_seam(x0, Palette.GALLERY_ACCENT if i == 1 else Palette.CORRIDOR_ACCENT if i == 2 else Palette.FORGOTTEN_ACCENT)


# --- helpers ---------------------------------------------------------------

func _band_wall(x0: float, x1: float, top: Color, bottom: Color) -> void:
	var bands := 8
	var y0 := -100.0
	var h := (Util.FLOOR_Y - y0) / bands
	for i in bands:
		draw_rect(Rect2(x0, y0 + h * i, x1 - x0, h + 1.0), top.lerp(bottom, float(i) / (bands - 1)))


func _seam(x: float, col: Color) -> void:
	var pts := PackedVector2Array()
	var y := -100.0
	while y <= Util.FLOOR_Y:
		pts.append(Vector2(x + sin(y * 0.37) * 8.0, y))
		y += 40.0
	draw_polyline(pts, Color(col, 0.7), 3.0)


func _window(cx: float, top_y: float, w: float, h: float, col: Color, a: float) -> void:
	var r := w * 0.5
	draw_rect(Rect2(cx - r, top_y + r, w, h - r), Color(col, a))
	draw_circle(Vector2(cx, top_y + r), r, Color(col, a))
	var frame := Color(col.darkened(0.5), 0.9)
	draw_arc(Vector2(cx, top_y + r), r, PI, TAU, 16, frame, 4.0)
	draw_line(Vector2(cx - r, top_y + r), Vector2(cx - r, top_y + h), frame, 4.0)
	draw_line(Vector2(cx + r, top_y + r), Vector2(cx + r, top_y + h), frame, 4.0)
	draw_line(Vector2(cx, top_y), Vector2(cx, top_y + h), frame, 3.0)
	draw_line(Vector2(cx - r, top_y + h * 0.5), Vector2(cx + r, top_y + h * 0.5), frame, 3.0)


func _chair(p: Vector2, col: Color, flip: float = 1.0, tipped: bool = false) -> void:
	if tipped:
		draw_set_transform(p + Vector2(0, -14), -PI / 2.0, Vector2(flip, 1.0))
	else:
		draw_set_transform(p, 0.0, Vector2(flip, 1.0))
	draw_rect(Rect2(-14, -24, 28, 6), col)
	draw_rect(Rect2(-14, -56, 6, 36), col)
	draw_rect(Rect2(-14, -18, 5, 18), col.darkened(0.2))
	draw_rect(Rect2(9, -18, 5, 18), col.darkened(0.2))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _chandelier(x: float, y: float, t: float) -> void:
	draw_line(Vector2(x, -100), Vector2(x, y), Palette.BALLROOM_ACCENT.darkened(0.5), 2.0)
	draw_rect(Rect2(x - 30, y, 60, 6), Palette.BALLROOM_ACCENT)
	for k in 5:
		var cx := x - 28.0 + k * 14.0
		draw_rect(Rect2(cx - 2, y - 10, 4, 10), Color("f0e6d0"))
		draw_circle(Vector2(cx, y - 14), 3.0, Color(1.0, 0.8, 0.4, 0.8 + 0.2 * sin(t * 8.0 + k)))


# --- Area I: Ballroom ------------------------------------------------------

func _ballroom(x0: float, x1: float, t: float) -> void:
	_band_wall(x0, x1, Palette.BALLROOM_WALL.darkened(0.35), Palette.BALLROOM_WALL)
	draw_rect(Rect2(x0, 470, x1 - x0, 90), Palette.BALLROOM_WALL.darkened(0.2))
	var x := x0 + 160.0
	while x < x1 - 100.0:
		_window(x, 110.0, 70.0, 240.0, Palette.BALLROOM_ACCENT, 0.35 + 0.05 * sin(t * 1.3 + x))
		x += 280.0
	x = x0 + 30.0
	while x < x1:
		draw_rect(Rect2(x, 40, 34, 520), Palette.BALLROOM_WALL.lightened(0.12))
		draw_rect(Rect2(x - 6, 40, 46, 10), Palette.BALLROOM_ACCENT.darkened(0.3))
		x += 560.0
	_chandelier(x0 + 400.0, 130.0, t)
	_chandelier(x0 + 950.0, 130.0, t)
	# Chairs: they move and vanish as the player comes and goes.
	var v: int = anomaly[0]
	var col := Palette.BALLROOM_ACCENT.darkened(0.45)
	var base_x := [320.0, 470.0, 880.0, 1030.0]
	for i in 4:
		var px: float = base_x[i]
		var flip := 1.0
		var tipped := false
		if v >= 1 and i == 1:
			px += 60.0
			flip = -1.0
		if v >= 2 and i == 2:
			continue
		if v >= 3 and i == 0:
			tipped = true
		_chair(Vector2(px, Util.FLOOR_Y), col, flip, tipped)


# --- Area II: Gallery ------------------------------------------------------

func _gallery(x0: float, x1: float, t: float) -> void:
	_band_wall(x0, x1, Palette.GALLERY_WALL.darkened(0.4), Palette.GALLERY_WALL)
	# leaning, wrong-looking columns
	var k := 0
	var x := x0 + 50.0
	while x < x1 - 40.0:
		var lean := 40.0 if k % 2 == 0 else -30.0
		draw_colored_polygon(PackedVector2Array([
			Vector2(x, -60), Vector2(x + 34, -60),
			Vector2(x + 34 + lean, Util.FLOOR_Y), Vector2(x + lean, Util.FLOOR_Y)
		]), Palette.GALLERY_WALL.lightened(0.06))
		x += 220.0
		k += 1
	# the abyss under the missing floor
	draw_rect(Rect2(2000, Util.FLOOR_Y, 500, 140), Color("07060b"))
	var px := [1580.0, 1830.0, 2640.0, 2790.0]
	for i in 4:
		_painting(px[i], 250.0, i, t)


func _painting(cx: float, cy: float, idx: int, t: float) -> void:
	var tilt := 0.04 * sin(t * 0.5 + idx * 1.7)
	draw_set_transform(Vector2(cx, cy), tilt, Vector2.ONE)
	draw_rect(Rect2(-42, -54, 84, 108), Color("6e5b3a"))
	draw_rect(Rect2(-36, -48, 72, 96), PAINT_COLORS[idx % 4])
	var v: int = anomaly[1] % 4
	draw_circle(Vector2(0, -4), 18.0, Color("cfc6b4"))
	var ex := 3.0 if v == 1 else 0.0
	draw_rect(Rect2(-8 + ex, -10, 4, 4), Palette.INK)
	draw_rect(Rect2(5 + ex, -10, 4, 4), Palette.INK)
	if v == 2:
		draw_rect(Rect2(-2, -18, 4, 4), Palette.INK)   # a third eye
	if v == 3:
		draw_rect(Rect2(-10, 4, 20, 3), Palette.INK)   # mouth stretched wide
	else:
		draw_rect(Rect2(-5, 6, 10, 2), Palette.INK)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# --- Area III: Corridor ----------------------------------------------------

func _corridor(x0: float, x1: float, t: float) -> void:
	_band_wall(x0, x1, Palette.CORRIDOR_WALL.darkened(0.4), Palette.CORRIDOR_WALL)
	var v: int = anomaly[2]
	var idx := 0
	var x := x0 + 80.0
	while x < x1 - 120.0:
		var flick := 0.55 + 0.45 * sin(t * 2.6 + idx * 1.3)
		if v >= 2 and fmod(t + idx, 3.0) < 0.15:
			flick = 0.0
		draw_rect(Rect2(x - 2, 0, 4, 100), Palette.CORRIDOR_ACCENT.darkened(0.5))
		if idx != 7:
			for g in 3:
				draw_circle(Vector2(x, 106), 22.0 - g * 6.0, Color(Palette.MEMORY, (0.05 + g * 0.05) * flick))
			draw_circle(Vector2(x, 106), 5.0, Color(Palette.MEMORY, flick))
		var skip := v >= 1 and idx == 4
		if not skip:
			draw_rect(Rect2(x - 26, 460, 52, 100), Color("2a2036"))
			draw_rect(Rect2(x - 21, 465, 42, 95), Color("4a3a5c"))
			draw_circle(Vector2(x + 14, 512), 3.0, Palette.MEMORY)
		x += 160.0
		idx += 1


# --- Area IV: Forgotten Room -----------------------------------------------

func _forgotten(x0: float, x1: float, t: float) -> void:
	_band_wall(x0, x1, Color("07050b"), Palette.FORGOTTEN_WALL)
	for k in 14:
		var bx := x0 + 120.0 + k * 95.0
		var pts := PackedVector2Array()
		for j in 5:
			pts.append(Vector2(bx + sin(k * 3.1 + j * 1.7) * 18.0, 40.0 + j * 60.0 + (k % 4) * 20.0))
		draw_polyline(pts, Color(Palette.FORGOTTEN_ACCENT, 0.5), 2.0)
	draw_rect(Rect2(x0 + 260, 100, 120, 220), Color("050408"))
	draw_rect(Rect2(x0 + 260, 100, 120, 220), Color(Palette.FORGOTTEN_ACCENT, 0.7), false, 3.0)
	for k in 36:
		var px := x0 + fmod(k * 137.0 + t * (6.0 + (k % 5) * 3.0), x1 - x0)
		var py := 60.0 + fmod(k * 71.0 - t * (4.0 + (k % 3) * 2.0) + 2000.0, 480.0)
		draw_rect(Rect2(px, py, 2, 2), Color(0.8, 0.75, 0.9, 0.12 + 0.1 * sin(t + k)))
