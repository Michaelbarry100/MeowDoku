class_name GridCell
extends Button

signal cell_requested(row: int, column: int)

var row: int
var column: int
var region_color := Color.WHITE
var state: int = PuzzleRules.CellState.EMPTY
var invalid := false
var selected := false
var region_id := 0
var region_edges := Vector4.ONE
var board_size := 5
var cat_scale := 1.0
var pop_tween: Tween
var mark_scale := 1.0
var selection_amount := 0.0
var last_selected := false
var selection_tween: Tween
var mark_tween: Tween

func _ready() -> void:
	for style_name in ["normal", "hover", "pressed", "focus", "disabled"]:
		add_theme_stylebox_override(style_name, StyleBoxEmpty.new())
	pressed.connect(func() -> void: cell_requested.emit(row, column))
	resized.connect(queue_redraw)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

func configure(r: int, c: int, color: Color) -> void:
	row = r
	column = c
	region_color = color
	refresh(PuzzleRules.CellState.EMPTY, false)

func refresh(new_state: int, has_conflict: bool) -> void:
	if selected != last_selected:
		last_selected = selected
		if selection_tween:
			selection_tween.kill()
		if PlayerPreferences.reduced_motion:
			selection_amount = 1.0 if selected else 0.0
		else:
			selection_tween = create_tween()
			selection_tween.tween_method(func(value: float) -> void:
				selection_amount = value
				queue_redraw(), selection_amount, 1.0 if selected else 0.0, 0.16)
	var placing := new_state == PuzzleRules.CellState.CAT and state != new_state
	var marking := new_state == PuzzleRules.CellState.EXCLUDED and state != new_state
	state = new_state
	invalid = has_conflict
	var description: String = ["empty", "cat: no current conflict", "excluded"][state]
	if invalid:
		description = "cat: rule conflict"
	tooltip_text = "Row %d, column %d: %s" % [row + 1, column + 1, description]
	queue_redraw()
	if placing and not PlayerPreferences.reduced_motion and is_inside_tree():
		if pop_tween:
			pop_tween.kill()
		cat_scale = 0.76
		pop_tween = create_tween()
		pop_tween.tween_method(func(value: float) -> void:
			cat_scale = value
			queue_redraw(), 0.76, 1.0, 0.20).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		cat_scale = 1.0
	if mark_tween:
		mark_tween.kill()
	if marking and not PlayerPreferences.reduced_motion and is_inside_tree():
		mark_scale = 0.65
		mark_tween = create_tween()
		mark_tween.tween_method(func(value: float) -> void:
			mark_scale = value
			queue_redraw(), 0.65, 1.0, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		mark_scale = 1.0

func _draw() -> void:
	var box := Rect2(Vector2(2, 2), size - Vector2(4, 4))
	var background := PurrTheme.rounded(region_color, 9)
	background.shadow_color = Color(0.35, 0.26, 0.32, 0.11)
	background.shadow_size = 2
	background.shadow_offset = Vector2(0, 2)
	background.bg_color = region_color.lightened(0.12 * selection_amount)
	if selection_amount > 0:
		background.shadow_color = Color(0.58, 0.43, 0.68, 0.12 * selection_amount)
		background.shadow_size = 4
	background.content_margin_left = 0
	if state == PuzzleRules.CellState.CAT:
		background.border_color = Color("bb3855") if invalid else Color("327d65")
		background.set_border_width_all(3)
	draw_style_box(background, box)
	var highlight := PurrTheme.rounded(Color(1, 1, 1, 0.14), 7)
	draw_style_box(highlight, Rect2(box.position + Vector2(2, 2), Vector2(box.size.x - 4, box.size.y * 0.42)))
	# Dark edge strokes and IDs identify regions independently of their colors.
	var edge_color := Color("b0a1b4")
	if column == 0:
		draw_line(Vector2(1, 1), Vector2(1, size.y + 1), edge_color, 1.25, true)
	if row == 0:
		draw_line(Vector2(1, 1), Vector2(size.x + 1, 1), edge_color, 1.25, true)
	if region_edges.z > 0:
		var edge_x := size.x - 1 if column == board_size - 1 else size.x + 1
		draw_line(Vector2(edge_x, 1), Vector2(edge_x, size.y + 1), edge_color, 1.25, true)
	if region_edges.w > 0:
		var edge_y := size.y - 1 if row == board_size - 1 else size.y + 1
		draw_line(Vector2(1, edge_y), Vector2(size.x + 1, edge_y), edge_color, 1.25, true)
	draw_string(ThemeDB.fallback_font, Vector2(7, 14), str(region_id + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, PurrTheme.INK)
	var center := size * 0.5
	var unit := minf(size.x, size.y)
	var ink := PurrTheme.INK
	if state == PuzzleRules.CellState.CAT:
		var art_size := unit * 0.97 * cat_scale
		CatArtwork.paint(self, Rect2(center - Vector2.ONE * art_size * 0.5, Vector2.ONE * art_size), region_id)
		# An extra symbol distinguishes conflicts without relying on color.
		if invalid:
			var mark := Vector2(size.x * 0.83, size.y * 0.23)
			draw_line(mark, mark + Vector2(0, unit * 0.12), Color("bb3855"), 3, true)
			draw_circle(mark + Vector2(0, unit * 0.18), 1.7, Color("bb3855"))
		else:
			var mark := Vector2(size.x * 0.72, size.y * 0.79)
			draw_polyline(PackedVector2Array([mark, mark + Vector2(unit * 0.05, unit * 0.05), mark + Vector2(unit * 0.15, -unit * 0.06)]), Color("327d65"), 2, true)
	elif state == PuzzleRules.CellState.EXCLUDED:
		var offset := Vector2.ONE * unit * 0.13 * mark_scale
		draw_line(center - offset, center + offset, ink, 3, true)
		draw_line(center + Vector2(-offset.x, offset.y), center + Vector2(offset.x, -offset.y), ink, 3, true)
	else:
		draw_circle(center, unit * 0.035, Color(ink, 0.3))
	if has_focus():
		draw_rect(box.grow(-5), ink, false, 2)
	if selected:
		var selection := PurrTheme.rounded(Color.TRANSPARENT, 9)
		selection.border_color = Color("65527e")
		selection.set_border_width_all(2)
		draw_style_box(selection, box.grow(-4))

