extends Control
## Lightweight cream gradient with quiet pastel ambient washes.
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	for strip in range(64):
		var t := float(strip) / 63.0
		draw_rect(Rect2(0, size.y * strip / 64.0, size.x, size.y / 64.0 + 1), Color("fffaf1").lerp(Color("f4edf3"), t * 0.55))
	for layer in range(16, 0, -1):
		draw_circle(Vector2(size.x * 0.98, size.y * 0.12), size.x * layer / 28.0, Color(0.91, 0.82, 0.94, 0.014), true, -1, true)
