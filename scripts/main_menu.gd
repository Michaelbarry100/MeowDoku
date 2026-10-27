extends MarginContainer

signal play_requested
signal action_requested(action: String)

func _ready() -> void:
	var content := PurrUI.scroll_content(self)
	content.add_child(PurrUI.label("A LITTLE LOGIC, A LOT OF CATS", 12, true))
	PurrUI.portrait(content, 182)
	content.add_child(PurrUI.label(str(ProjectSettings.get_setting("application/config/name")), 32, true))
	content.add_child(PurrUI.label("Make a little room for happiness.", 16, true))
	var play_card := PurrUI.card(content)
	var resume := GameServices.progression.resume_id()
	play_card.add_child(PurrUI.label("YOUR SAVED GARDEN" if not resume.is_empty() else "YOUR NEXT QUIET MOMENT", 11))
	play_card.add_child(PurrUI.button("Resume puzzle" if not resume.is_empty() else "Play  ·  Start a garden", "PlayButton", func() -> void: play_requested.emit(), Color("f3d2df")))
	var row := HBoxContainer.new()
	content.add_child(row)
	row.add_child(PurrUI.button("Daily Puzzle", "DailyButton", func() -> void: action_requested.emit("daily"), Color("d4ebdf")))
	row.add_child(PurrUI.button("Levels", "LevelsButton", func() -> void: action_requested.emit("levels"), Color("d6e9f5")))
	content.add_child(PurrUI.label("A fresh daily garden, grown on your device.", 13, true))
	var links := HBoxContainer.new()
	content.add_child(links)
	links.add_child(PurrUI.button("How to play", "RulesButton", func() -> void: action_requested.emit("tutorial"), Color("f6dce5")))
	links.add_child(PurrUI.button("Settings", "SettingsButton", func() -> void: action_requested.emit("settings"), Color("f5e8cf")))
	content.add_child(PurrUI.label("No rush. Just one happy cat at a time.", 13, true))
	content.add_child(PurrUI.label("%d stars  ·  %d / %d gardens complete" % [GameServices.progression.total_stars(), count_campaign_completed(), GameServices.progression.catalog.levels.size()], 14, true))
	if not GameServices.progression.notice.is_empty() or not GameServices.catalog_error.is_empty():
		content.add_child(PurrUI.label(GameServices.catalog_error if not GameServices.catalog_error.is_empty() else GameServices.progression.notice, 14, true))

func count_campaign_completed() -> int:
	var count := 0
	for puzzle in GameServices.progression.catalog.levels:
		if GameServices.progression.save.state.completed.has(puzzle.id):
			count += 1
	return count
