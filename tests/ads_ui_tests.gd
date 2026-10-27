extends SceneTree

var checks := 0
var failures := 0
var app: Control
var capture := false

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)
	else:
		print("PASS: ", description)

func press(parent: Node, name: String) -> void:
	var button := parent.find_child(name, true, false) as BaseButton
	check(button != null, "Control exists: " + name)
	if button != null:
		button.pressed.emit()

func settle() -> void:
	for i in range(4):
		await process_frame

func snapshot(name: String) -> void:
	if not capture:
		return
	await create_timer(0.25).timeout
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://artifacts/ads")
	check(root.get_texture().get_image().save_png("res://artifacts/ads/" + name + ".png") == OK, "Captured " + name)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	TestStorage.configure("ads_ui")
	capture = "--capture" in OS.get_cmdline_user_args()
	root.size = Vector2i(390, 844)
	root.content_scale_size = root.size
	app = preload("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await settle()
	check(not GameServices.ads.initialized and app.overlay == null, "Launching never initializes or displays ads")
	press(app.current_screen, "PlayButton")
	var screen: Control = app.current_screen
	for i in range(3):
		press(screen, "HintButton")
		press(screen, "UndoButton")
	check(GameServices.hints.free_remaining("easy_01") == 0 and screen.moves == 0, "Three free UI hints work without ad permission")
	var board: Array = screen.board.duplicate(true)
	press(screen, "HintButton")
	await settle()
	check(app.overlay.name == "RewardedHintPage" and app.overlay.mode == "options", "Empty inventory offers optional hint choices")
	check(app.overlay.find_child("WatchAdButton", true, false).disabled, "Watch unavailable without explicit local permission")
	await snapshot("01-optional-hints-off")
	press(app.overlay, "KeepPlayingButton")
	check(app.overlay == null and not screen.suspended and screen.board == board, "Declining optional ads returns to unchanged playable board")
	screen.cells[0].pressed.emit()
	check(screen.moves == 1, "Manual play still works with no hints and no ads")
	press(screen, "UndoButton")
	press(screen, "EarnHintButton")
	press(app.overlay, "AdPrivacyButton")
	await settle()
	check(app.overlay.find_child("AllowMockAdsButton", true, false) != null, "Development privacy flow explains local simulation choice")
	await snapshot("02-privacy-choice")
	press(app.overlay, "AllowMockAdsButton")
	press(app.overlay, "BackButton")
	await settle()
	check(not app.overlay.find_child("WatchAdButton", true, false).disabled, "Returning from opt-in makes optional test ad available")
	press(app.overlay, "WatchAdButton")
	await settle()
	check(app.overlay.mode == "simulation" and not screen.visible and screen.suspended, "Ad simulator is a separate full screen; board/control area is hidden")
	check(GameServices.hints.sandbox.balance == 0, "Opening test ad gives no credit")
	await snapshot("03-simulator")
	press(app.overlay, "SkipSimulationButton")
	check(GameServices.hints.sandbox.balance == 0 and app.overlay.finished, "Skip earns nothing and offers return")
	press(app.overlay, "KeepPlayingButton")
	check(screen.visible and not screen.suspended and screen.board == board, "Skipping returns to original puzzle")
	press(screen, "EarnHintButton")
	press(app.overlay, "WatchAdButton")
	var id: String = GameServices.ads.active_id
	press(app.overlay, "CompleteSimulationButton")
	await settle()
	check(GameServices.hints.sandbox.balance == 1 and screen.board == board, "Verified completion credits one test hint without auto-playing it")
	check(GameServices.progression.save.state.hint_inventory.earned_balance == 0, "Production bank remains zero")
	await snapshot("04-simulated-reward")
	var provider := GameServices.ads.provider as MockAdProvider
	provider.reward_earned.emit(id, provider.successful_receipts[id])
	check(GameServices.hints.sandbox.balance == 1, "Duplicate native-style callback has no second UI reward")
	press(app.overlay, "KeepPlayingButton")
	press(screen, "EarnHintButton")
	press(app.overlay, "WatchAdButton")
	app.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	press(app.overlay, "CompleteSimulationButton")
	check(GameServices.hints.sandbox.balance == 1 and app.overlay.name == "RewardedHintPage", "Backgrounding does not place pause menu over ad or invent a reward")
	app.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	check(GameServices.hints.sandbox.balance == 2 and app.overlay.finished, "Foreground return settles only queued verified callback")
	press(app.overlay, "KeepPlayingButton")
	press(screen, "HintButton")
	check(GameServices.hints.sandbox.balance == 1 and screen.moves == 1 and screen.session.hints_used == 4, "Extra hint is spent only on a deliberate Hint tap")
	press(screen, "UndoButton")
	check(GameServices.hints.sandbox.balance == 1 and GameServices.hints.free_remaining("easy_01") == 0, "Undo does not refund rewarded hints or free quota")
	press(screen, "EarnHintButton")
	press(app.overlay, "WatchAdButton")
	press(app.overlay, "FailSimulationButton")
	check(GameServices.hints.sandbox.balance == 1, "Failed test ad does not reward")
	press(app.overlay, "KeepPlayingButton")
	provider.available = false
	press(screen, "EarnHintButton")
	check(app.overlay.find_child("WatchAdButton", true, false).disabled, "Unavailable provider disables Watch without blocking Keep playing")
	press(app.overlay, "KeepPlayingButton")
	provider.available = true
	press(screen, "EarnHintButton")
	press(app.overlay, "AdPrivacyButton")
	press(app.overlay, "AdsOffButton")
	press(app.overlay, "BackButton")
	check(app.overlay.find_child("WatchAdButton", true, false).disabled and GameServices.hints.sandbox.balance == 1, "Privacy opt-out stops requests while retaining earned hints")
	press(app.overlay, "KeepPlayingButton")
	root.size = Vector2i(320, 568)
	root.content_scale_size = root.size
	await settle()
	var tools: HBoxContainer = screen.get_node("Content/Tools")
	check(tools.get_global_rect().end.x <= 304, "Optional hint controls fit smallest phone width")
	for name in ["UndoButton", "HintButton", "EarnHintButton"]:
		var button := screen.find_child(name, true, false) as Button
		check(button.size.x >= 48 and button.size.y >= 48, "Touch-friendly control: " + name)
	await snapshot("05-small-phone-board")
	app.queue_free()
	await process_frame
	app = preload("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await settle()
	check(not GameServices.ads.initialized and GameServices.progression.save.state.ad_privacy.choice == "off", "Relaunch preserves opt-out and never auto-initializes ads")
	press(app.current_screen, "PlayButton")
	check(GameServices.hints.free_remaining("easy_01") == 0 and GameServices.hints.sandbox.balance == 1, "Allowance and test bank survive app reopening")
	app.queue_free()
	await process_frame
	TestStorage.cleanup()
	print("RESULT: %d rewarded-hint UI checks, %d failures" % [checks, failures])
	await TestStorage.drain_audio()
	quit(1 if failures else 0)

