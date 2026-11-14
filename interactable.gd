class_name Interactable
extends Node2D
## Anything the player can press E on. The node origin is the object's feet.
## kind: "orb_echo", "orb_recollect", "fragment", "door", "exit", "object"

var kind := "object"
var prompt := "Interact"
var hidden_until_echo := false
var used := false
var opened := false
var locked := false
var active := true
var shape := ""                 # for kind "object": chair / clock / musicbox
var symbol_count := 0           # dots shown above an object while Echo is active
var color := Palette.MEMORY
var knob := Palette.MEMORY
var on_use: Callable = Callable()

var visible_time := 0.0
var symbol_time := 0.0
var lit_time := 0.0
var _t := 0.0


func setup(k: String, pos: Vector2, p: String, start_hidden: bool = false) -> Interactable:
	kind = k
	position = pos
	prompt = p
	hidden_until_echo = start_hidden
	add_to_group("interactables")
	add_to_group("echoable")
	return self


func can_interact() -> bool:
	if not active or opened:
		return false
	if used and kind != "object":
		return false
	if hidden_until_echo and visible_time <= 0.0:
		return false
	return true


func on_echo(origin: Vector2, radius: float, duration: float) -> void:
	if global_position.distance_to(origin) > radius:
		return
	if hidden_until_echo:
		visible_time = duration
	if symbol_count > 0:
		symbol_time = duration


func _process(delta: float) -> void:
	_t += delta
	visible_time = maxf(0.0, visible_time - delta)
	symbol_time = maxf(0.0, symbol_time - delta)
	lit_time = maxf(0.0, lit_time - delta)
	queue_redraw()


func _draw() -> void:
	match kind:
		"orb_echo", "orb_recollect":
			_draw_orb()
		"fragment":
			_draw_fragment()
		"door", "exit":
			_draw_door()
		"object":
			_draw_object()


func _draw_orb() -> void:
	draw_rect(Rect2(-16, -28, 32, 28), Color("3a3048"))
	draw_rect(Rect2(-20, -34, 40, 8), Color("5a4a6a"))
	if used:
		return
	var p := Vector2(0, -62 + sin(_t * 2.0) * 4.0)
	for i in 4:
		draw_circle(p, 26.0 - i * 5.0, Color(color, 0.08 + i * 0.1))
	draw_circle(p, 8.0, color.lightened(0.5))


func _draw_fragment() -> void:
	draw_rect(Rect2(-26, -34, 52, 6), Color("5a3d2e"))
	draw_rect(Rect2(-22, -28, 5, 28), Color("4a3225"))
	draw_rect(Rect2(17, -28, 5, 28), Color("4a3225"))
	draw_rect(Rect2(-14, -48, 28, 14), Color("8a5a3a"))
	draw_rect(Rect2(-14, -52, 28, 5), Color("a8714a"))
	if used:
		return
	var p := Vector2(0, -78 + sin(_t * 2.0) * 4.0)
	for i in 4:
		draw_circle(p, 22.0 - i * 5.0, Color(Palette.MEMORY, 0.07 + i * 0.07))
	draw_colored_polygon(PackedVector2Array([
		p + Vector2(0, -9), p + Vector2(7, 0), p + Vector2(0, 9), p + Vector2(-7, 0)
	]), Palette.MEMORY)


func _draw_door() -> void:
	var col := Color("6b4a3a") if kind == "door" else Color("f2efe6")
	var a := 1.0
	var r := Rect2(-28, -100, 56, 100)
	if hidden_until_echo and not opened:
		a = clampf(visible_time / 0.4, 0.0, 1.0)
		col = Palette.ECHO if kind == "door" else Color("f2efe6")
		if a <= 0.0:
			draw_rect(r, Color(Palette.ECHO, 0.05 + 0.03 * sin(_t * 3.0)), false, 2.0)
			return
	if opened:
		draw_rect(r, Color("07050a"))
		draw_rect(r, Color(Palette.MEMORY, 0.5), false, 2.0)
		return
	draw_rect(r, Color(col, a))
	draw_rect(Rect2(-22, -94, 44, 88), Color(col.darkened(0.25), a))
	draw_circle(Vector2(16, -50), 4.0, Color(knob, a))
	if kind == "exit":
		for i in 3:
			draw_rect(Rect2(-28 - i * 4, -100 - i * 4, 56 + i * 8, 100 + i * 4), Color(1, 1, 1, 0.06 * a), false, 2.0)
	if locked:
		draw_rect(Rect2(-6, -66, 12, 10), Color(Palette.PLAYER_SCARF, a))


func _draw_object() -> void:
	var col := Palette.BALLROOM_ACCENT.darkened(0.35)
	if lit_time > 0.0:
		for i in 3:
			draw_circle(Vector2(0, -40), 50.0 - i * 12.0, Color(Palette.MEMORY, 0.08 * lit_time))
	match shape:
		"chair":
			draw_rect(Rect2(-14, -24, 28, 6), col)
			draw_rect(Rect2(-14, -56, 6, 36), col)
			draw_rect(Rect2(-14, -18, 5, 18), col.darkened(0.2))
			draw_rect(Rect2(9, -18, 5, 18), col.darkened(0.2))
		"clock":
			draw_rect(Rect2(-16, -92, 32, 92), col)
			draw_rect(Rect2(-12, -88, 24, 40), col.darkened(0.3))
			draw_circle(Vector2(0, -68), 9.0, Color("d8cdb8"))
			draw_line(Vector2(0, -68), Vector2(0, -75), Palette.INK, 2.0)
			draw_line(Vector2(0, -68), Vector2(5, -66), Palette.INK, 2.0)
			draw_rect(Rect2(-8, -40, 16, 34), col.darkened(0.45))
		"musicbox":
			draw_rect(Rect2(-18, -24, 36, 24), Color("8a5a3a"))
			draw_rect(Rect2(-20, -32, 40, 8), Color("a8714a"))
			draw_line(Vector2(18, -14), Vector2(26, -20), Color("d8cdb8"), 2.0)
	if symbol_time > 0.0:
		var a := clampf(symbol_time / 0.4, 0.0, 1.0)
		for i in symbol_count:
			var x := (i - (symbol_count - 1) * 0.5) * 16.0
			draw_circle(Vector2(x, -112), 6.0, Color(Palette.ECHO, 0.35 * a))
			draw_circle(Vector2(x, -112), 3.5, Color(Palette.ECHO.lightened(0.5), a))
