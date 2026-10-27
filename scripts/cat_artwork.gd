class_name CatArtwork
extends RefCounted
## Shared offline-rendered original 3D artwork; no runtime character viewports.
const CATS := [preload("res://assets/cats/tuxedo.png"), preload("res://assets/cats/cream.png"), preload("res://assets/cats/tabby.png"), preload("res://assets/cats/gray.png"), preload("res://assets/cats/rose.png")]
const NAMES := ["Tuxedo", "Cream", "Orange tabby", "Gray", "Rose fantasy"]

static func paint(canvas: CanvasItem, rect: Rect2, variant: int = 0) -> void:
	var center := rect.position + rect.size * Vector2(0.50, 0.90)
	for layer in range(5, 0, -1):
		var points := PackedVector2Array()
		for point in range(32):
			var angle := float(point) * TAU / 32.0
			points.append(center + Vector2(cos(angle) * rect.size.x * (0.20 + layer * 0.013), sin(angle) * rect.size.y * (0.021 + layer * 0.005)))
		canvas.draw_colored_polygon(points, Color(0.30, 0.24, 0.35, 0.027))
	canvas.draw_texture_rect(CATS[posmod(variant, CATS.size())], rect, false)

static func star(canvas: CanvasItem, center: Vector2, radius: float, color: Color) -> void:
	var points := PackedVector2Array()
	for point in range(10):
		var angle := float(point) * TAU / 10.0 - PI / 2.0
		points.append(center + Vector2(cos(angle), sin(angle)) * radius * (1.0 if point % 2 == 0 else 0.46))
	canvas.draw_colored_polygon(points, color)
