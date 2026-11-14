class_name Util
extends RefCounted
## Shared constants and helpers.

const FLOOR_Y := 560.0
## Left/right x-bounds of the four areas: Ballroom, Gallery, Corridor, Forgotten Room.
const AREA_X := [0.0, 1400.0, 3000.0, 4600.0, 6000.0]

static var _radial: GradientTexture2D


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
