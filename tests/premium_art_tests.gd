extends SceneTree

var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	TestStorage.configure("premium_art")
	check(CatArtwork.CATS.size() == 5, "Five original coat variants")
	var hashes: Dictionary = {}
	for texture in CatArtwork.CATS:
		var image: Image = texture.get_image()
		check(image.get_size() == Vector2i(512, 512), "Bounded 512px character texture")
		check(image.get_pixel(0, 0).a == 0 and image.get_pixel(511, 511).a == 0, "Transparent asset corners")
		check(image.get_pixel(256, 256).a > 0.9, "Solid dimensional character at center")
		hashes[hash(image.get_data())] = true
	check(hashes.size() == 5, "All five coats have distinct rendered pixels")
	var app := preload("res://scenes/main.tscn").instantiate()
	root.size = Vector2i(390, 844)
	root.content_scale_size = root.size
	root.add_child(app)
	for frame in range(4):
		await process_frame
	check(app.find_children("*", "SubViewport", true, false).is_empty(), "No runtime 3D viewports in lightweight UI")
	app.show_puzzle()
	for frame in range(4):
		await process_frame
	var screen = app.current_screen
	check(screen.cells.size() == 25, "Campaign board preserved")
	check(screen.get_node("Content/Tools/HintButton") is TactileTool, "Dimensional hint medallion integrated")
	PlayerPreferences.reduced_motion = true
	screen.cells[0].pressed.emit()
	check(screen.board[0][0] == PuzzleRules.CellState.CAT and screen.cells[0].selection_amount == 1, "Reduced-motion selection reflects true board")
	screen.cells[0].pressed.emit()
	check(screen.cells[0].state == PuzzleRules.CellState.EXCLUDED and screen.cells[0].mark_scale == 1, "Exclusion respects reduced motion")
	if "--capture" in OS.get_cmdline_user_args():
		screen.restart()
		for row in range(int(screen.level.size)):
			screen.cells[row * int(screen.level.size) + int(screen.session.solution[row])].pressed.emit()
		app.close_overlay()
		await create_timer(0.35).timeout
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute("res://artifacts/premium")
		check(screen.complete, "Original five-cat collection completes through real cell actions")
		check(root.get_texture().get_image().save_png("res://artifacts/premium/filled-board.png") == OK, "Captured completed premium board")
	app.queue_free()
	await process_frame
	TestStorage.cleanup()
	print("RESULT: %d premium artwork checks, %d failures" % [checks, failures])
	await TestStorage.drain_audio()
	quit(1 if failures else 0)

