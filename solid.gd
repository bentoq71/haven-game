class_name Solid
extends StaticBody2D
## A rectangle of collision with three behaviours:
##   NORMAL - always solid (floors, walls)
##   HIDDEN - invisible and intangible until revealed by ECHO
##   BROKEN - scattered fragments until restored by RECOLLECTION
##
## `theme` picks the tile art: "ballroom" / "gallery" / "corridor" / "forgotten" (floors,
## chosen automatically from position), "plank" / "stairs" (broken pieces), "slab" (hidden
## platforms) or "wall" (invisible collision).

enum Mode { NORMAL, HIDDEN, BROKEN }

const TILE := 16.0 * Util.PX

var size := Vector2(100, 20)
var mode: int = Mode.NORMAL
var theme := ""
var enabled := true            # lets doors switch walls off
var visible_time := 0.0        # echo timer
var restore_time := 0.0        # recollection timer
var restore_amount := 0.0      # 0 = scattered, 1 = whole (visual only)

var _shape: CollisionShape2D
var _seeds: Array = []
var _last_solid := true


## rect.position is the top-left corner of the block.
func setup(rect: Rect2, m: int = Mode.NORMAL, theme_name: String = "") -> Solid:
	position = rect.position
	size = rect.size
	mode = m
	theme = theme_name if theme_name != "" else Util.AREA_THEMES[Util.area_for_x(position.x)]
	var shape := RectangleShape2D.new()
	shape.size = size
	_shape = CollisionShape2D.new()
	_shape.shape = shape
	_shape.position = size / 2.0
	add_child(_shape)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(position.x * 7.0 + position.y * 13.0)
	for i in 8:
		_seeds.append(Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)))
	if mode == Mode.HIDDEN:
		add_to_group("echoable")
	elif mode == Mode.BROKEN:
		add_to_group("restorable")
	_update_collision()
	return self


func set_enabled(v: bool) -> void:
	enabled = v
	_update_collision()


func _is_solid() -> bool:
	if not enabled:
		return false
	match mode:
		Mode.HIDDEN:
			return visible_time > 0.0
		Mode.BROKEN:
			return restore_time > 0.0
	return true


func _update_collision() -> void:
	var s := _is_solid()
	if s != _last_solid:
		_last_solid = s
		_shape.set_deferred("disabled", not s)


# --- Ability hooks (called through groups by the player) -------------------

func on_echo(origin: Vector2, radius: float, duration: float) -> void:
	if mode == Mode.HIDDEN and (global_position + size / 2.0).distance_to(origin) <= radius:
		visible_time = duration


func on_recollect(origin: Vector2, radius: float, duration: float) -> void:
	if mode == Mode.BROKEN and (global_position + size / 2.0).distance_to(origin) <= radius:
		restore_time = duration


func _process(delta: float) -> void:
	if mode == Mode.NORMAL:
		return
	visible_time = maxf(0.0, visible_time - delta)
	restore_time = maxf(0.0, restore_time - delta)
	var target := 1.0 if restore_time > 0.0 else 0.0
	restore_amount = move_toward(restore_amount, target, delta * 2.5)
	_update_collision()
	queue_redraw()


# --- Drawing ---------------------------------------------------------------

## Tiles `t` across r at PX scale, clipping the last row/column so any size works.
func _tile(t: Texture2D, r: Rect2, mod: Color = Color.WHITE) -> void:
	var tw := t.get_width() * Util.PX
	var th := t.get_height() * Util.PX
	var y := 0.0
	while y < r.size.y - 0.01:
		var h := minf(th, r.size.y - y)
		var x := 0.0
		while x < r.size.x - 0.01:
			var w := minf(tw, r.size.x - x)
			draw_texture_rect_region(t, Rect2(r.position + Vector2(x, y), Vector2(w, h)),
					Rect2(0, 0, w / Util.PX, h / Util.PX), mod)
			x += tw
		y += th


func _draw() -> void:
	match mode:
		Mode.NORMAL:
			_draw_normal()
		Mode.HIDDEN:
			_draw_hidden()
		Mode.BROKEN:
			_draw_broken()


func _draw_normal() -> void:
	if theme == "wall":
		return
	var top := Util.tex("floor_%s_top" % theme)
	var fill := Util.tex("floor_%s_fill" % theme)
	_tile(top, Rect2(0, 0, size.x, minf(TILE, size.y)))
	if size.y > TILE:
		_tile(fill, Rect2(0, TILE, size.x, size.y - TILE))


func _draw_hidden() -> void:
	var a := 0.0
	if visible_time > 0.0:
		a = clampf(visible_time / 0.4, 0.0, 1.0)
		if visible_time < 1.5:
			a *= 0.6 + 0.4 * sin(visible_time * 22.0)
	var faint := 0.10 + 0.05 * sin(Time.get_ticks_msec() / 400.0 + position.x)
	var r := Rect2(Vector2.ZERO, size)
	# a faint dotted hint of where something used to be
	var x := 0.0
	while x < size.x:
		draw_rect(Rect2(x, 0, 4, 4), Color(Palette.ECHO, faint))
		x += 16.0
	if a > 0.0:
		_tile(Util.tex("tile_" + theme), r, Color(0.65, 0.92, 1.0, a))
		draw_rect(r, Color(Palette.ECHO, 0.25 * a))


func _draw_broken() -> void:
	var amt := restore_amount
	var t := Util.tex("tile_" + theme)
	var pieces := maxi(3, int(size.x / 15.0))
	var pw := size.x / pieces
	var alpha := lerpf(0.5, 1.0, amt)
	var col := Color(1, 1, 1, alpha)
	for i in pieces:
		var sv: Vector3 = _seeds[i % _seeds.size()]
		var off := Vector2(sv.x * 26.0, sv.y * 34.0 - 8.0) * (1.0 - amt)
		var rot := sv.z * 0.7 * (1.0 - amt)
		draw_set_transform(Vector2((i + 0.5) * pw, size.y * 0.5) + off, rot, Vector2.ONE)
		_tile(t, Rect2(-pw * 0.5, -size.y * 0.5, pw, size.y), col)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if restore_time > 0.0 and restore_time < 1.5:
		var blink := 0.5 + 0.5 * sin(restore_time * 22.0)
		draw_rect(Rect2(Vector2.ZERO, size), Color(Palette.RECOLLECT, 0.5 * blink), false, 2.0)
