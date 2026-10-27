extends Control

signal action_requested(action: String)
@export_enum("pause", "victory", "confirm_restart") var mode := "pause"
var next_available := true
var detail := ""
var panel: PanelContainer
var safe: MobileSafeArea
var content_box: VBoxContainer

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(0.19, 0.16, 0.25, 0.30)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	safe = MobileSafeArea.new()
	safe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(safe)
	var center := CenterContainer.new()
	safe.add_child(center)
	panel = PanelContainer.new()
	center.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.follow_focus = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var box := VBoxContainer.new()
	content_box = box
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 12)
	scroll.add_child(box)
	PurrUI.portrait(box, 110, "celebrate" if mode == "victory" else "sleepy")
	box.add_child(PurrUI.label("FRESH START?" if mode == "confirm_restart" else ("PURRFECTLY DONE" if mode == "victory" else "A MOMENT TO PAWS"), 11, true))
	box.add_child(PurrUI.label("Restart this garden?" if mode == "confirm_restart" else ("Every cat is home!" if mode == "victory" else "Take your time"), 27, true))
	box.add_child(PurrUI.label("Cats, X marks and this attempt's counters will be cleared. Your stars and unlocks stay." if mode == "confirm_restart" else (detail if mode == "victory" else "Your garden is saved on this device."), 16, true))
	if mode == "pause":
		box.add_child(PurrUI.button("Keep playing", "ResumeButton", func() -> void: action_requested.emit("resume"), Color("d5eade")))
		box.add_child(PurrUI.button("How to play", "PauseRulesButton", func() -> void: action_requested.emit("tutorial")))
		box.add_child(PurrUI.button("Settings", "PauseSettingsButton", func() -> void: action_requested.emit("settings"), Color("deeaf5")))
	elif mode == "victory":
		var next := PurrUI.button("Next Level" if next_available else "All gardens complete", "NextButton", func() -> void: action_requested.emit("next"), Color("d5eade"))
		next.disabled = not next_available
		box.add_child(next)
	if mode == "confirm_restart":
		box.add_child(PurrUI.button("Keep my progress", "CancelRestartButton", func() -> void: action_requested.emit("cancel_restart"), Color("d5eade")))
		box.add_child(PurrUI.button("Yes, restart", "ConfirmRestartButton", func() -> void: action_requested.emit("confirm_restart"), Color("f4dce5")))
	else:
		box.add_child(PurrUI.button("Replay" if mode == "victory" else "Restart garden", "ModalRestartButton", func() -> void: action_requested.emit("replay" if mode == "victory" else "restart"), Color("f4dce5")))
		box.add_child(PurrUI.button("Main menu", "ModalMenuButton", func() -> void: action_requested.emit("menu"), Color("f5e9d2")))
	resized.connect(layout_panel)
	box.minimum_size_changed.connect(layout_panel)
	layout_panel()
	call_deferred("layout_panel")
	PurrUI.fade_in(panel)
	PurrUI.focus_loop(panel)

func layout_panel() -> void:
	if not is_instance_valid(panel):
		return
	var horizontal := safe.get_theme_constant("margin_left") + safe.get_theme_constant("margin_right")
	var vertical := safe.get_theme_constant("margin_top") + safe.get_theme_constant("margin_bottom")
	panel.custom_minimum_size.x = minf(380, maxf(0, size.x - horizontal))
	panel.get_child(0).custom_minimum_size.y = minf(content_box.get_combined_minimum_size().y, maxf(0, size.y - vertical - 40))
