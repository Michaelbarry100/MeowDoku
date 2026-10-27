class_name PurrUI
extends RefCounted

static func label(text: String, font_size: int = 17, centered: bool = false) -> Label:
	var node := Label.new()
	node.text = text
	node.add_theme_font_size_override("font_size", font_size)
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if centered:
		node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return node

static func button(text: String, node_name: String, callback: Callable, tint: Color = Color.TRANSPARENT) -> Button:
	var node := Button.new()
	node.name = node_name
	node.text = text
	node.custom_minimum_size.y = 52
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var color := tint if tint.a > 0 else Color("e8dff3")
	for state_name in ["normal", "hover", "pressed"]:
		var style := PurrTheme.rounded(color.lightened(0.06) if state_name == "hover" else color, 26)
		style.shadow_color = Color(0.30, 0.24, 0.35, 0.08)
		style.shadow_size = 1 if state_name == "pressed" else 5
		style.shadow_offset = Vector2(0, 1 if state_name == "pressed" else 3)
		style.border_color = Color(1, 1, 1, 0.45)
		style.border_width_top = 1
		node.add_theme_stylebox_override(state_name, style)
	node.pressed.connect(callback)
	return node

static func card(parent: Node, tint: Color = Color("fffdf9")) -> VBoxContainer:
	var panel := PanelContainer.new()
	var style := PurrTheme.rounded(tint, 22)
	style.shadow_color = Color(0.2, 0.15, 0.3, 0.06)
	style.shadow_size = 6
	style.shadow_offset = Vector2(0, 3)
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	return box

static func scroll_content(parent: Control) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(scroll)
	var content := VBoxContainer.new()
	content.name = "Content"
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 14)
	scroll.add_child(content)
	return content

static func portrait(parent: Node, height: float = 150, expression: String = "happy") -> CatPortrait:
	var cat := preload("res://scenes/components/cat_portrait.tscn").instantiate() as CatPortrait
	cat.custom_minimum_size.y = height
	cat.expression = expression
	parent.add_child(cat)
	return cat

static func fade_in(control: Control) -> void:
	if PlayerPreferences.reduced_motion:
		return
	control.modulate.a = 0.0
	control.create_tween().tween_property(control, "modulate:a", 1.0, 0.18)

static func focus_loop(container: Control) -> void:
	var buttons: Array[Node] = container.find_children("*", "BaseButton", true, false)
	if buttons.is_empty():
		return
	for i in range(buttons.size()):
		var button := buttons[i] as BaseButton
		var next: NodePath = button.get_path_to(buttons[(i + 1) % buttons.size()])
		var previous: NodePath = button.get_path_to(buttons[(i - 1 + buttons.size()) % buttons.size()])
		button.focus_next = next
		button.focus_previous = previous
		button.focus_neighbor_bottom = next
		button.focus_neighbor_top = previous
	if buttons[0].is_inside_tree():
		buttons[0].grab_focus()
