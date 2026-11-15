class_name Interactable
extends Node2D
## Anything the player can press E on. The node origin is the object's feet.
## kind: "orb_echo", "orb_recollect", "fragment", "door", "exit", "object"

var kind := "object"
var prompt := "interact"
var hidden_until_echo := false
var used := false
var opened := false
var locked := false
var odd := false                # the one "different" door in the corridor (red handle)
var active := true
var shape := ""                 # for kind "object": chair / clock / musicbox
var symbol_count := 0           # dots shown above an object while Echo is active
var color := Palette.MEMORY
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


func _glow(p: Vector2, r: float, c: Color) -> void:
	for i in 4:
		draw_circle(p, r - i * (r / 5.0), Color(c, 0.06 + i * 0.07))


func _draw_orb() -> void:
	Util.draw_px(self, Util.tex("pedestal"), Vector2.ZERO)
	if used:
		return
	var p := Vector2(0, -50 + sin(_t * 2.0) * 4.0)
	_glow(p, 30.0, color)
	var o := Util.tex("orb_echo" if kind == "orb_echo" else "orb_amber")
	draw_texture_rect(o, Rect2(p - Vector2(8, 8), Vector2(16, 16)), false)


func _draw_fragment() -> void:
	Util.draw_px(self, Util.tex("table_musicbox"), Vector2.ZERO)
	if used:
		return
	var p := Vector2(0, -74 + sin(_t * 2.0) * 4.0)
	_glow(p, 24.0, Palette.MEMORY)
	var s := Util.tex("shard")
	draw_texture_rect(s, Rect2(p - Vector2(8, 10), Vector2(16, 20)), false)


func _draw_door() -> void:
	var t: Texture2D
	if kind == "exit":
		t = Util.tex("exit")
	elif odd:
		t = Util.tex("door_odd")
	else:
		t = Util.tex("door")
	var a := 1.0
	var r := Rect2(-28, -100, 56, 100)
	if opened:
		Util.draw_px(self, Util.tex("door_open"), Vector2.ZERO)
		return
	if hidden_until_echo:
		a = clampf(visible_time / 0.4, 0.0, 1.0)
		if a <= 0.0:
			# a faint seam in the wall, only if you're looking for it
			var f := 0.06 + 0.04 * sin(_t * 3.0)
			draw_rect(r, Color(Palette.ECHO, f), false, 2.0)
			return
	Util.draw_px(self, t, Vector2.ZERO, Color(1, 1, 1, a))
	if kind == "exit":
		_glow(Vector2(0, -50), 70.0, Color(1, 1, 1))
	if locked:
		draw_rect(Rect2(8, -60, 12, 10), Color(Palette.PLAYER_SCARF, a))
		draw_rect(Rect2(10, -66, 8, 6), Color(0.1, 0.07, 0.1, a), false, 2.0)


func _draw_object() -> void:
	var t := Util.tex(shape)
	if lit_time > 0.0:
		_glow(Vector2(0, -40), 56.0, Palette.MEMORY * Color(1, 1, 1, lit_time))
	Util.draw_px(self, t, Vector2.ZERO)
	if symbol_time > 0.0:
		var a := clampf(symbol_time / 0.4, 0.0, 1.0)
		var top := -t.get_height() * Util.PX - 18.0
		for i in symbol_count:
			var x := (i - (symbol_count - 1) * 0.5) * 16.0
			draw_circle(Vector2(x, top), 6.0, Color(Palette.ECHO, 0.35 * a))
			draw_circle(Vector2(x, top), 3.5, Color(Palette.ECHO.lightened(0.5), a))
