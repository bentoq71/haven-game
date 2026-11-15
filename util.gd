class_name Util
extends RefCounted
## Shared constants and helpers.

const FLOOR_Y := 560.0
## Left/right x-bounds of the four areas: Ballroom, Gallery, Corridor, Forgotten Room.
const AREA_X := [0.0, 1400.0, 3000.0, 4600.0, 6000.0]
const AREA_THEMES := ["ballroom", "gallery", "corridor", "forgotten"]
## One art pixel = PX world pixels. All art is drawn 1x and scaled up with nearest filtering.
const PX := 2.0
const FONT_SMALL := 18
const FONT_LARGE := 54

static var _radial: GradientTexture2D
static var _tex := {}


static func area_for_x(x: float) -> int:
	for i in 4:
		if x < AREA_X[i + 1]:
			return i
	return 3


## Loads (and caches) res://art/<name>.png
static func tex(art_name: String) -> Texture2D:
	if not _tex.has(art_name):
		_tex[art_name] = load("res://art/%s.png" % art_name)
	return _tex[art_name]


## Draws a texture scaled by PX with its bottom-centre at `at`. Call from inside _draw().
static func draw_px(ci: CanvasItem, t: Texture2D, at: Vector2, mod: Color = Color.WHITE) -> void:
	var s := t.get_size() * PX
	ci.draw_texture_rect(t, Rect2(at - Vector2(s.x * 0.5, s.y), s), false, mod)


## Gives a Label the pixel font (res://art/font_s.fnt or font_l.fnt).
static func style_label(l: Label, large: bool = false) -> void:
	var f: Font = load("res://art/font_l.fnt" if large else "res://art/font_s.fnt")
	if f != null:
		l.add_theme_font_override("font", f)
	l.add_theme_font_size_override("font_size", FONT_LARGE if large else FONT_SMALL)


## A soft white radial gradient used for every light in the game.
## 512px wide, so a PointLight2D with texture_scale = 1 has a radius of 256px.
static func radial_texture() -> GradientTexture2D:
	if _radial == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		_radial = GradientTexture2D.new()
		_radial.gradient = g
		_radial.fill = GradientTexture2D.FILL_RADIAL
		_radial.fill_from = Vector2(0.5, 0.5)
		_radial.fill_to = Vector2(1.0, 0.5)
		_radial.width = 512
		_radial.height = 512
	return _radial
