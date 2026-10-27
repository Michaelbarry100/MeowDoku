extends MarginContainer

signal action_requested(action: String)
@export_enum("tutorial", "settings", "levels", "privacy") var page_kind := "tutorial"
var content: VBoxContainer
var selected_group := "Easy"

func _ready() -> void:
	content = PurrUI.scroll_content(self)
	content.add_child(PurrUI.button("‹  Back", "BackButton", func() -> void: action_requested.emit("back"), Color("f0eaf5")))
	match page_kind:
		"settings": build_settings()
		"levels": build_levels()
		"privacy": build_privacy()
		_: build_tutorial()
	PurrUI.focus_loop(self)

func build_settings() -> void:
	PurrUI.portrait(content, 118, "sleepy")
	content.add_child(PurrUI.label("Your comfort corner", 28, true))
	content.add_child(PurrUI.label("A little calmer, just the way you like it.", 16, true))
	var motion := PurrUI.card(content, Color("ede6f6"))
	var reduced := CheckButton.new()
	reduced.name = "ReducedMotion"
	reduced.text = "Reduced motion"
	reduced.custom_minimum_size.y = 56
	reduced.button_pressed = PlayerPreferences.reduced_motion
	motion.add_child(reduced)
	motion.add_child(PurrUI.label("Keep transitions and cat celebrations still.", 15))
	var touch := PurrUI.card(content, Color("deeee5"))
	var haptics := CheckButton.new()
	haptics.name = "Haptics"
	haptics.text = "Gentle haptics"
	haptics.custom_minimum_size.y = 56
	haptics.button_pressed = PlayerPreferences.haptics
	touch.add_child(haptics)
	touch.add_child(PurrUI.label("Optional light taps on supported phones. Off by default.", 15))
	var limits_card := PurrUI.card(content, Color("f5e8d2"))
	var limits := CheckButton.new()
	limits.name = "MistakeLimits"
	limits.text = "Mistake limits"
	limits.custom_minimum_size.y = 56
	limits.button_pressed = PlayerPreferences.mistake_limits
	limits_card.add_child(limits)
	limits_card.add_child(PurrUI.label("Optional: Easy unlimited, Medium 5, Hard 3, Expert 2. Undo keeps the attempt's mistake count.", 15))
	content.add_child(PurrUI.button("Privacy & optional ads", "PrivacyButton", func() -> void: action_requested.emit("privacy"), Color("dee9f6")))
	var notice := PurrUI.label("Saved on this device. No account needed.", 14, true)
	notice.name = "SaveNotice"
	content.add_child(notice)
	build_audio_settings(notice)
	reduced.toggled.connect(func(enabled: bool) -> void:
		PlayerPreferences.reduced_motion = enabled
		save_preferences(notice))
	haptics.toggled.connect(func(enabled: bool) -> void:
		PlayerPreferences.haptics = enabled
		save_preferences(notice))
	limits.toggled.connect(func(enabled: bool) -> void:
		PlayerPreferences.mistake_limits = enabled
		save_preferences(notice))

func build_audio_settings(notice: Label) -> void:
	var box := PurrUI.card(content)
	content.move_child(box.get_parent(), 4)
	box.add_child(PurrUI.label("Cozy audio", 22))
	for kind in ["music", "sfx"]:
		var toggle := CheckButton.new()
		toggle.name = "MusicEnabled" if kind == "music" else "SfxEnabled"
		toggle.text = "Music" if kind == "music" else "Sound effects & cats"
		toggle.custom_minimum_size.y = 52
		toggle.button_pressed = MeowAudio.instance().music_enabled if kind == "music" else MeowAudio.instance().sfx_enabled
		box.add_child(toggle)
		var caption := PurrUI.label("", 14)
		box.add_child(caption)
		var slider := HSlider.new()
		slider.name = "MusicVolume" if kind == "music" else "SfxVolume"
		slider.min_value = 0
		slider.max_value = 1
		slider.step = 0.05
		slider.value = MeowAudio.instance().music_volume if kind == "music" else MeowAudio.instance().sfx_volume
		slider.custom_minimum_size = Vector2(0, 48)
		slider.tooltip_text = "Music volume" if kind == "music" else "Sound effects and cat volume"
		caption.text = "%s volume · %d%%" % ["Music" if kind == "music" else "Sound", roundi(slider.value * 100)]
		box.add_child(slider)
		toggle.toggled.connect(func(enabled: bool) -> void:
			var error := MeowAudio.instance().set_music_enabled(enabled) if kind == "music" else MeowAudio.instance().set_sfx_enabled(enabled)
			notice.text = "Audio settings saved." if error == OK else "Applied for this session. Could not save audio settings.")
		slider.value_changed.connect(func(value: float) -> void:
			caption.text = "%s volume · %d%%" % ["Music" if kind == "music" else "Sound", roundi(value * 100)]
			var error := MeowAudio.instance().set_music_volume(value) if kind == "music" else MeowAudio.instance().set_sfx_volume(value)
			notice.text = "Audio settings saved." if error == OK else "Applied for this session. Could not save audio settings.")

func build_privacy() -> void:
	content.add_child(PurrUI.label("Privacy comes first", 28, true))
	PurrUI.portrait(content, 110, "sleepy")
	var box := PurrUI.card(content, Color("deeee5"))
	box.add_child(PurrUI.label("ON THIS DEVICE", 12))
	box.add_child(PurrUI.label("Puzzle progress, settings and hint counts stay in local saves. This build has no advertising SDK, analytics, accounts or network ad requests.", 17))
	content.add_child(PurrUI.label("Three free hints per garden. Ads are optional, and unavailable ads never block normal play.", 16, true))
	var notice := PurrUI.label("", 15, true)
	notice.name = "AdPrivacyNotice"
	content.add_child(notice)
	var refresh_notice := func() -> void:
		notice.text = "Local ad tests are allowed. No real advertiser receives data." if GameServices.progression.save.state.ad_privacy.choice == "mock" else "Optional ad tests are off. Free hints are still available."
	refresh_notice.call()
	content.add_child(PurrUI.button("Keep ads off", "AdsOffButton", func() -> void:
		if GameServices.set_ad_choice("off"):
			refresh_notice.call()
		else:
			notice.text = "Ads are off for this session. The choice could not be saved.", Color("d4ebdf")))
	if OS.is_debug_build():
		content.add_child(PurrUI.button("Allow local ad simulations", "AllowMockAdsButton", func() -> void:
			if GameServices.set_ad_choice("mock"):
				refresh_notice.call()
			else:
				notice.text = "Could not save the choice. Ad tests stay off."))
		content.add_child(PurrUI.label("This is a development-only simulator, not consent to a real advertising network. Simulated rewards cannot become production credits.", 15, true))
	else:
		content.add_child(PurrUI.label("Real ads are not enabled in this release. A native consent flow and audience safeguards must be reviewed before any real ad requests.", 15, true))

func save_preferences(notice: Label) -> void:
	notice.text = "Comfort settings saved." if PlayerPreferences.save_settings() == OK else "Applied for this session. Could not save on this device."

func build_levels() -> void:
	content.add_child(PurrUI.label("Pick a little garden", 29, true))
	content.add_child(PurrUI.label("%d unique puzzles. Clear a garden to unlock the next. Your unfinished boards are saved." % GameServices.progression.catalog.levels.size(), 16, true))
	var tabs := GridContainer.new()
	tabs.columns = 2
	content.add_child(tabs)
	var body := VBoxContainer.new()
	body.name = "LevelCards"
	for group in LevelCatalog.GROUPS:
		tabs.add_child(PurrUI.button(group, group + "GroupButton", func() -> void: render_group(group, body), PurrTheme.REGIONS[LevelCatalog.GROUPS.find(group)]))
	content.add_child(body)
	render_group(selected_group, body)

func render_group(group: String, body: VBoxContainer) -> void:
	selected_group = group
	for child in body.get_children():
		body.remove_child(child)
		child.queue_free()
	body.add_child(PurrUI.label(group + " gardens", 24))
	for puzzle in GameServices.progression.catalog.levels:
		if puzzle.difficulty != group:
			continue
		var card := PurrUI.card(body, PurrTheme.REGIONS[(int(puzzle.order) - 1) % 5])
		var unlocked := GameServices.progression.unlocked(puzzle.id)
		var reward: Dictionary = GameServices.progression.save.state.completed.get(puzzle.id, {})
		var progress: Dictionary = GameServices.progression.save.state.sessions.get(puzzle.id, {})
		card.add_child(PurrUI.label("%02d  ·  %s" % [int(puzzle.order), group.to_upper()], 12))
		card.add_child(PurrUI.label(puzzle.title, 23))
		card.add_child(PurrUI.label(("★".repeat(int(reward.stars)) + "☆".repeat(3 - int(reward.stars))) if not reward.is_empty() else ("Saved puzzle" if progress.get("moves", 0) > 0 else ("%d × %d · Unique solution" % [int(puzzle.size), int(puzzle.size)] if unlocked else "Clear the previous garden to unlock.")), 15))
		var id: String = puzzle.id
		var button := PurrUI.button("Open garden" if unlocked else "Locked", "Level%02dButton" % int(puzzle.order), func() -> void: action_requested.emit("level:" + id))
		button.disabled = not unlocked
		card.add_child(button)

func build_tutorial() -> void:
	content.add_child(PurrUI.label("A home for every cat", 29, true))
	PurrUI.portrait(content, 110)
	for rule in [
		["01  ·  ROWS & COLUMNS", "Place exactly one cat in each row and each column."],
		["02  ·  COLORED GARDENS", "Each outlined region needs exactly one cat. Tiny region numbers help identify matching cells."],
		["03  ·  PERSONAL SPACE", "Cats cannot touch along edges or corners. Even diagonal neighbors need a gap."]
	]:
		var box := PurrUI.card(content, PurrTheme.REGIONS[content.get_child_count() % 5])
		box.add_child(PurrUI.label(rule[0], 12))
		box.add_child(PurrUI.label(rule[1], 17))
	var practice := PurrUI.card(content, Color("eee5f7"))
	practice.add_child(PurrUI.label("TRY A TAP", 12))
	practice.add_child(PurrUI.label("Empty → cat → X → empty", 17))
	var grid := GridContainer.new()
	grid.columns = 3
	practice.add_child(grid)
	for column in range(3):
		var demo := preload("res://scenes/grid_cell.tscn").instantiate() as GridCell
		demo.name = "PracticeCell%d" % column
		demo.custom_minimum_size = Vector2(64, 64)
		grid.add_child(demo)
		demo.configure(0, column, PurrTheme.REGIONS[column])
		demo.region_id = column
		demo.board_size = 3
		demo.cell_requested.connect(func(_r: int, _c: int) -> void:
			demo.selected = true
			demo.refresh((demo.state + 1) % 3, false))
	practice.add_child(PurrUI.label("Practice cells only. A check means no current conflict; ! means a rule needs attention. X is your own note.", 15))
	content.add_child(PurrUI.button("Let's play", "TutorialPlayButton", func() -> void: action_requested.emit("play"), Color("d4ebdf")))

