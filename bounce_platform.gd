class_name BouncePlatform
extends StaticBody2D

@export var bounce_strength: float = 750.0

func _init() -> void:
	add_to_group("bounce_surfaces")


func _ready() -> void:
	# Collision shape
	var collision := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(100, 16)
	collision.shape = rectangle
	add_child(collision)

	# Visible platform
	var visual := Polygon2D.new()
	visual.polygon = PackedVector2Array([
		Vector2(-50, -8),
		Vector2(50, -8),
		Vector2(50, 8),
		Vector2(-50, 8)
	])
	visual.color = Color("e5b96d")
	add_child(visual)

	# Decorative glow
	var light := PointLight2D.new()
	light.texture = Util.radial_texture()
	light.color = Color("ffcc77")
	light.energy = 0.5
	light.texture_scale = 1.5
	add_child(light)
