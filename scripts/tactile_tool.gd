class_name TactileTool
extends Button
## Circular action medallion with a separate readable label and accessible Button text.
var tool_kind := "undo"
var compact := false

func prepare(kind: String) -> void:
	tool_kind = kind
	for state_name in ["normal", "hover", "pressed", "disabled", "focus"]:
		add_theme_stylebox_override(state_name, StyleBoxEmpty.new())
	for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]:
		add_theme_color_override(color_name, Color.TRANSPARENT)
	resized.connect(queue_redraw)
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)

func _draw() -> void:
	var radius := 15.0 if compact else 23.0
	var middle := Vector2(size.x * 0.5, radius + 3)
	var tint := Color("e5def2") if tool_kind == "undo" else (Color("f9dfb7") if tool_kind == "hint" else Color("d8eade"))
	if disabled:
		tint = Color("ebe7e8")
	elif is_pressed():
		tint = tint.darkened(0.06)
	elif is_hovered():
		tint = tint.lightened(0.10)
	draw_circle(middle + Vector2(0, 3), radius + 1, Color(0.35, 0.28, 0.36, 0.08), true, -1, true)
	draw_circle(middle, radius, tint, true, -1, true)
	draw_arc(middle, radius - 2, PI * 1.12, PI * 1.88, 24, Color(1, 1, 1, 0.6), 1.5, true)
	if tool_kind == "undo":
		draw_arc(middle, radius * 0.43, -PI * 0.75, PI * 0.70, 20, PurrTheme.INK, 2, true)
		var arrow := middle + Vector2(-radius * 0.30, -radius * 0.30)
		draw_polyline(PackedVector2Array([arrow + Vector2(0, -5), arrow + Vector2(-3, 2), arrow + Vector2(4, 3)]), PurrTheme.INK, 2, true)
	else:
		var extent := radius * 1.80
		CatArtwork.paint(self, Rect2(middle - Vector2.ONE * extent * 0.5, Vector2.ONE * extent), 1 if tool_kind == "hint" else 4)
		if tool_kind == "earn":
			CatArtwork.star(self, middle + Vector2(radius * 0.55, -radius * 0.30), radius * 0.30, Color("b38a39"))
	if has_focus():
		draw_arc(middle, radius + 2, 0, TAU, 48, Color("7b6b97"), 1.5, true)
	var font := get_theme_font("font")
	var font_size := 12 if compact else 13
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(font, Vector2((size.x - width) * 0.5, size.y - 3), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color("938b98") if disabled else PurrTheme.INK)
