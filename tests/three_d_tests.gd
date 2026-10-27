extends SceneTree

var checks := 0
var failures := 0
var game: Meow3DVerticalSlice
var capture := false

func check(condition: bool, description: String) -> void:
	checks += 1
	if condition:
		print("PASS: ", description)
	else:
		failures += 1
		push_error(description)

func settle() -> void:
	for i in range(4):
		await process_frame
	await physics_frame
	await physics_frame

func screenshot(name: String) -> void:
	if not capture:
		return
	await create_timer(0.45).timeout
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://artifacts/three_d")
	check(root.get_texture().get_image().save_png("res://artifacts/three_d/" + name + ".png") == OK, "Saved 3D capture: " + name)

func click(point: Vector2) -> void:
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
		event.pressed = down
		event.position = point
		event.global_position = point
		root.push_input(event, true)
		await process_frame
	await settle()

func tile_point(index: int) -> Vector2:
	return game.camera.unproject_position(game.board_3d.tiles[index].global_position + Vector3(0, PuzzleTile3D.HEIGHT, 0))

func reflected() -> bool:
	for tile in game.board_3d.tiles:
		if tile.state != int(game.session.board[tile.row][tile.column]):
			return false
		if (tile.cat != null) != (tile.state == 1):
			return false
		if tile.cross.visible != (tile.state == 2):
			return false
	return true

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	capture = "--capture" in OS.get_cmdline_user_args()
	root.size = Vector2i(390, 844)
	root.content_scale_size = root.size
	game = preload("res://scenes/three_d/vertical_slice.tscn").instantiate()
	root.add_child(game)
	await settle()
	check(game is Node3D, "3D game scene has a Node3D root")
	check(game.camera.current and game.camera.projection == Camera3D.PROJECTION_ORTHOGONAL, "Real orthographic Camera3D is active")
	check(game.board_3d.tiles.size() == 16, "Board contains sixteen individual 3D tiles")
	check(game.key_light is DirectionalLight3D and game.key_light.shadow_enabled, "Real directional shadow light enabled")
	check(game.get_node("WorldEnvironment").environment != null, "WorldEnvironment provides ambient lighting")
	check(PuzzleValidator.validate(game.session.puzzle).classification == "unique", "Production 4x4 level admitted as unique")
	check(game.find_children("*", "Sprite3D", true, false).is_empty(), "No Sprite3D impostors or billboards")
	check(game.find_children("*", "Sprite2D", true, false).is_empty(), "No 2D sprite board or cats")
	var segment_test := MeowModelBuilder3D.new()
	segment_test.segment(Vector3.ZERO, Vector3.RIGHT, 0.05, MeowMaterials3D.cream())
	var segment_bounds := segment_test.finish().get_aabb().size
	check(segment_bounds.x >= 0.99 and segment_bounds.y <= 0.11, "Rotated 3D strokes preserve their intended length and thickness")
	for tile in game.board_3d.tiles:
		check(tile.tile_mesh.mesh.get_aabb().size.y >= 0.19, "Tile has actual geometric thickness")
		check(tile.tile_mesh.material_override is StandardMaterial3D and tile.tile_mesh.material_override.shading_mode != BaseMaterial3D.SHADING_MODE_UNSHADED, "Tile uses lit PBR material")
		check(game.board_3d.pick(game.camera, tile_point(tile.row * 4 + tile.column)) == Vector2i(tile.row, tile.column), "Camera physics ray hits the correct tile")
	check(game.board_3d.pick(game.camera, Vector2(-500, -500)) == Vector2i(-1, -1), "Missed ray does not select a cell")
	await screenshot("01-empty-board")
	await click(tile_point(0))
	check(game.session.board[0][0] == 1 and game.session.moves == 1, "Pointer ray places a cat")
	check(game.board_3d.tiles[0].cat is TuxedoCat3D and reflected(), "Real 3D cat exactly reflects logic state")
	var cat := game.board_3d.tiles[0].cat
	check(cat.find_child("MergedBodyHeadEarsPaws", true, false) is MeshInstance3D and cat.eyes is MeshInstance3D and cat.tail is MeshInstance3D, "Cat consists of actual body/face/tail mesh geometry")
	var cat_triangles := MeowGeometry3D.triangle_count(TuxedoCat3D.body_mesh) + MeowGeometry3D.triangle_count(TuxedoCat3D.eyes_mesh) + MeowGeometry3D.triangle_count(TuxedoCat3D.tail_mesh)
	check(cat_triangles > 1000 and cat_triangles < 6500, "Procedural cat polygon budget is bounded")
	print("MODEL: ", cat_triangles, " triangles; ", TuxedoCat3D.body_mesh.get_surface_count() + TuxedoCat3D.eyes_mesh.get_surface_count() + TuxedoCat3D.tail_mesh.get_surface_count(), " material surfaces per cat")
	var face := cat.to_global(Vector3(0, 0.79, 0.31))
	check(game.board_3d.pick(game.camera, game.camera.unproject_position(face)) == Vector2i(0, 0), "Raycasting the cat face selects its own tile")
	await screenshot("02-tuxedo-on-tile")
	await click(tile_point(1))
	check(game.last_evaluation.status == "invalid" and game.board_3d.tiles[0].warning.visible and game.board_3d.tiles[1].warning.visible, "Conflicting cats show actual 3D exclamation markers")
	check(game.hud.status.text.contains("row 1"), "HUD explains invalid row immediately")
	await screenshot("03-conflict")
	await click(tile_point(1))
	check(game.session.board[0][1] == 2 and game.board_3d.tiles[1].cat == null and game.board_3d.tiles[1].cross.visible, "Second tap replaces cat with raised 3D X")
	check(reflected(), "Render state matches board after exclusion")
	game.undo()
	await settle()
	check(game.session.board[0][1] == 1 and reflected(), "Undo restores actual cat geometry")
	game.restart()
	await settle()
	check(game.session.moves == 0 and reflected() and not game.session.is_complete(), "Restart clears logical and 3D state")
	var point := tile_point(5)
	for down in [true, false]:
		var touch := InputEventScreenTouch.new()
		touch.index = 0
		touch.position = point
		touch.pressed = down
		root.push_input(touch, true)
		await process_frame
	await settle()
	check(game.session.board[1][1] == 1 and game.session.moves == 1, "Touch tap uses raycast and changes one cell once")
	var emulated := InputEventMouseButton.new()
	emulated.device = -1
	emulated.pressed = true
	emulated.button_index = MOUSE_BUTTON_LEFT
	emulated.position = point
	game._unhandled_input(emulated)
	await settle()
	check(game.session.moves == 1, "Emulated mouse event cannot double-count a touch")
	var drag_start := InputEventScreenTouch.new()
	drag_start.index = 0
	drag_start.pressed = true
	drag_start.position = point
	game._unhandled_input(drag_start)
	var drag_end := InputEventScreenTouch.new()
	drag_end.index = 0
	drag_end.pressed = false
	drag_end.position = point + Vector2(50, 0)
	game._unhandled_input(drag_end)
	await settle()
	check(game.session.moves == 1, "Dragging across the board does not create a tap")
	await click(game.hud.quality_button.get_global_rect().get_center())
	check(not game.key_light.shadow_enabled and not game.balanced_quality and game.session.moves == 1, "Quality button disables shadows without selecting tiles")
	check(game.board_3d.tiles[5].cat.reduced_motion, "Low-power mode also stops idle animation")
	game.toggle_quality()
	game.toggle_motion()
	check(game.reduced_motion and game.board_3d.tiles[5].cat.reduced_motion, "Reduced-motion toggle stops cat movement")
	game.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	game.queue_pick(tile_point(3))
	await settle()
	check(game.session.moves == 1, "Suspended game ignores queued selections")
	game.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	game.restart()
	await settle()
	for viewport_size in [Vector2i(320, 568), Vector2i(320, 640), Vector2i(390, 844), Vector2i(430, 932), Vector2i(768, 1024)]:
		root.size = viewport_size
		root.content_scale_size = viewport_size
		await settle()
		var available := game.hud.board_rect()
		for tile in game.board_3d.tiles:
			var center := tile.global_position + Vector3(0, PuzzleTile3D.HEIGHT, 0)
			var screen := game.camera.unproject_position(center)
			check(available.has_point(screen), "Tile target stays outside HUD at %s" % viewport_size)
			check(game.board_3d.pick(game.camera, screen) == Vector2i(tile.row, tile.column), "Portrait resize keeps ray hits correct")
		var origin := game.board_3d.tiles[5].global_position + Vector3(0, PuzzleTile3D.HEIGHT, 0)
		var horizontal := game.camera.unproject_position(origin + Vector3(0.5, 0, 0)).distance_to(game.camera.unproject_position(origin - Vector3(0.5, 0, 0)))
		var vertical := game.camera.unproject_position(origin + Vector3(0, 0, 0.5)).distance_to(game.camera.unproject_position(origin - Vector3(0, 0, 0.5)))
		check(horizontal >= 48 and vertical >= 48, "Projected tile touch targets at least 48 units at %s" % viewport_size)
		check(game.hud.footer.get_global_rect().end.y <= viewport_size.y - 16, "Overlay controls fit portrait viewport")
		await screenshot("size-%dx%d" % [viewport_size.x, viewport_size.y])
	root.size = Vector2i(390, 844)
	root.content_scale_size = root.size
	await settle()
	for row in range(4):
		await click(tile_point(row * 4 + int(game.session.solution[row])))
	check(game.session.is_complete() and game.last_evaluation.complete and game.session.moves == 4, "Real raycast placements complete all puzzle rules")
	check(reflected() and game.hud.status.text.contains("complete"), "Completed 3D board and HUD agree")
	await screenshot("04-completed-board")
	print("BOARD_RENDER: ", Engine.get_frames_per_second(), " FPS; draw calls ", int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)), "; primitives ", int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)))
	await click(tile_point(0))
	check(game.session.moves == 4, "Victory rejects further tile placements")
	# Alternate real camera angle and close-up prove the model has depth.
	if capture:
		var target := game.board_3d.tiles[int(game.session.solution[3]) + 12].cat
		game.camera.size = 1.5
		game.camera.position = target.global_position + Vector3(1.1, 0.8, 2.0)
		game.camera.look_at(target.global_position + Vector3(0, 0.45, 0), Vector3.UP)
		game.hud.visible = false
		await screenshot("05-cat-geometry-closeup")
		game.hud.visible = true
		game.fit_camera()
	print("RENDER: ", Engine.get_frames_per_second(), " FPS; draw calls ", int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)), "; primitives ", int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)))
	game.queue_free()
	await process_frame
	print("RESULT: %d 3D checks, %d failures" % [checks, failures])
	await TestStorage.drain_audio()
	quit(1 if failures else 0)

