extends Control
## Cream ceramic board tray, independent of cells and puzzle state.
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	var style := PurrTheme.rounded(Color("fffdf8"), 18)
	style.shadow_color = Color(0.30, 0.24, 0.34, 0.10)
	style.shadow_size = 10
	style.shadow_offset = Vector2(0, 5)
	draw_style_box(style, Rect2(Vector2(-6, -6), size + Vector2(12, 12)))
