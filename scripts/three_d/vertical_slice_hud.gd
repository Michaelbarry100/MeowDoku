class_name Meow3DHUD
extends CanvasLayer

signal undo_requested
signal restart_requested
signal quality_requested
signal motion_requested

var safe: MobileSafeArea
var header: VBoxContainer
var footer: VBoxContainer
var stats: Label
var status: Label
var quality_button: Button
var motion_button: Button
var undo_button: Button
var profile_label: Label

func _ready() -> void:
	var root := Control.new()
	root.name = "OverlayOnly"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = PurrTheme.create()
	add_child(root)
	safe = MobileSafeArea.new()
	safe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	safe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(safe)
	var frame := Control.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	safe.add_child(frame)
	header = VBoxContainer.new()
	header.name = "Header"
	header.add_theme_constant_override("separation", 6)
	header.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	frame.add_child(header)
	var top := HBoxContainer.new()
	header.add_child(top)
	var brand := PurrUI.label("MeowDoku", 26)
	brand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(brand)
	quality_button = PurrUI.button("Balanced", "QualityButton", func() -> void: quality_requested.emit(), Color("dcece4"))
	quality_button.size_flags_horizontal = Control.SIZE_FILL
	quality_button.add_theme_font_size_override("font_size", 15)
	top.add_child(quality_button)
	header.add_child(PurrUI.label("Cream Courtyard  ·  4 × 4", 16, true))
	stats = PurrUI.label("", 14, true)
	header.add_child(stats)
	footer = VBoxContainer.new()
	footer.name = "Footer"
	footer.add_theme_constant_override("separation", 8)
	footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	footer.grow_vertical = Control.GROW_DIRECTION_BEGIN
	frame.add_child(footer)
	status = PurrUI.label("", 15, true)
	status.custom_minimum_size.y = 48
	status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	footer.add_child(status)
	footer.add_child(PurrUI.label("Tap: cat → X → empty\nOne per row, column & color. Cats cannot touch.", 13, true))
	var actions := HBoxContainer.new()
	footer.add_child(actions)
	undo_button = PurrUI.button("Undo", "Undo3DButton", func() -> void: undo_requested.emit())
	actions.add_child(undo_button)
	actions.add_child(PurrUI.button("Restart", "Restart3DButton", func() -> void: restart_requested.emit(), Color("f6dce5")))
	motion_button = PurrUI.button("Motion", "Motion3DButton", func() -> void: motion_requested.emit(), Color("dbe9f6"))
	actions.add_child(motion_button)
	for button in actions.get_children():
		button.custom_minimum_size.y = 48
		button.add_theme_font_size_override("font_size", 15)
	profile_label = PurrUI.label("", 11, true)
	profile_label.visible = "--profile" in OS.get_cmdline_user_args()
	footer.add_child(profile_label)

func refresh(session: PuzzleSession, result: Dictionary, balanced: bool, reduced: bool) -> void:
	stats.text = "Moves: %d  ·  Cats: %d/%d  ·  Mistakes: %d" % [session.moves, result.cat_count, int(session.puzzle.size), session.mistakes]
	quality_button.text = "Balanced" if balanced else "Low power"
	motion_button.text = "Still" if reduced else "Motion"
	undo_button.disabled = session.history.is_empty() or result.complete
	if result.complete:
		status.text = "Every cat is home! Courtyard complete."
		status.add_theme_color_override("font_color", Color("327d65"))
	elif result.status == "invalid":
		status.text = "! " + str(result.messages[0])
		status.add_theme_color_override("font_color", Color("a32c49"))
	else:
		status.text = "Find a little home for each of the four cats."
		status.add_theme_color_override("font_color", PurrTheme.INK)
	status.tooltip_text = "\n".join(result.messages)

func board_rect() -> Rect2:
	var viewport_size := get_viewport().get_visible_rect().size
	var top := header.get_global_rect().end.y + 12
	var bottom := footer.get_global_rect().position.y - 12
	return Rect2(Vector2(safe.get_theme_constant("margin_left"), top), Vector2(maxf(0, viewport_size.x - safe.get_theme_constant("margin_left") - safe.get_theme_constant("margin_right")), maxf(0, bottom - top)))
