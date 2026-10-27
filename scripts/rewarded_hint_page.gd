extends Control

signal action_requested(action: String)
var mode := "options"
var puzzle_id := ""
var finished := false
var service: AdService
var message_label: Label
var count_label: Label
var watch_button: Button
var simulation_buttons: VBoxContainer

func _ready() -> void:
	service = GameServices.ads
	var background := ColorRect.new()
	background.color = Color("faf5ef")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var safe := MobileSafeArea.new()
	safe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(safe)
	var content := PurrUI.scroll_content(safe)
	content.add_child(PurrUI.label("LOCAL TEST · NO REAL AD" if mode == "simulation" else "OPTIONAL EXTRA HINTS", 12, true))
	PurrUI.portrait(content, 110)
	content.add_child(PurrUI.label("Ad simulator" if mode == "simulation" else "A little help, your choice", 27, true))
	count_label = PurrUI.label("", 17, true)
	content.add_child(count_label)
	message_label = PurrUI.label("", 16, true)
	content.add_child(message_label)
	if mode == "simulation":
		content.add_child(PurrUI.label("No video, advertiser or tracking is loaded. Complete this local test to simulate an earned-reward callback. Opening or skipping adds nothing.", 16, true))
		simulation_buttons = VBoxContainer.new()
		content.add_child(simulation_buttons)
		simulation_buttons.add_child(PurrUI.button("Complete simulation", "CompleteSimulationButton", func() -> void: action_requested.emit("mock_success"), Color("d4ebdf")))
		simulation_buttons.add_child(PurrUI.button("Skip · no reward", "SkipSimulationButton", func() -> void: action_requested.emit("mock_skip"), Color("f4dce5")))
		simulation_buttons.add_child(PurrUI.button("Simulate failure", "FailSimulationButton", func() -> void: action_requested.emit("mock_failed")))
	else:
		content.add_child(PurrUI.label("Three free hints per garden. Restart and undo do not refill the allowance. Extra hints are optional; all puzzles remain playable without ads.", 16, true))
		watch_button = PurrUI.button("Test rewarded ad · +1 hint" if OS.is_debug_build() else "Rewarded ad unavailable", "WatchAdButton", func() -> void: action_requested.emit("watch"), Color("d4ebdf"))
		content.add_child(watch_button)
		content.add_child(PurrUI.button("Privacy & optional ads", "AdPrivacyButton", func() -> void: action_requested.emit("privacy"), Color("dee9f6")))
	content.add_child(PurrUI.button("Back to puzzle" if mode == "simulation" else "Keep playing", "KeepPlayingButton", func() -> void: action_requested.emit("back"), Color("f4dce5")))
	service.changed.connect(refresh)
	service.result_ready.connect(on_result)
	refresh()
	PurrUI.focus_loop(self)

func refresh() -> void:
	if not is_instance_valid(count_label):
		return
	var sandbox_count := GameServices.hints.sandbox.balance if GameServices.hints.sandbox != null and GameServices.hints.sandbox.available else 0
	count_label.text = "Free hints left: %d / 3" % GameServices.hints.free_remaining(puzzle_id)
	if OS.is_debug_build():
		count_label.text += "\nExtra test hints: %d (development only)" % sandbox_count
	message_label.text = service.last_message
	if watch_button != null:
		watch_button.disabled = not service.is_available()
	if simulation_buttons != null:
		simulation_buttons.visible = not finished

func on_result(message: String, _rewarded: bool) -> void:
	if mode == "simulation":
		finished = true
	refresh()
	message_label.text = message

func _exit_tree() -> void:
	if service != null:
		if service.changed.is_connected(refresh):
			service.changed.disconnect(refresh)
		if service.result_ready.is_connected(on_result):
			service.result_ready.disconnect(on_result)
