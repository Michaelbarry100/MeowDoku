class_name Meow3DVerticalSlice
extends Node3D
## First playable 3D milestone. All tile/cat states come from PuzzleSession.

const LEVEL := "res://data/three_d_garden.json"
var session := PuzzleSession.new()
var board_3d: PuzzleBoard3D
var camera: Camera3D
var key_light: DirectionalLight3D
var hud: Meow3DHUD
var selected := Vector2i(-1, -1)
var reduced_motion := false
var balanced_quality := true
var pending_picks: Array[Vector2] = []
var touch_index := -1
var touch_origin := Vector2.ZERO
var touch_dragged := false
var last_evaluation: Dictionary
var layout_pending := false
var paused := false

func _ready() -> void:
	MeowAudio.instance().play_music()
	MeowAudio.instance().set_cat_context(self)
	var loaded := LevelData.load_validated(LEVEL)
	if not loaded.ok or not session.begin(loaded.puzzle):
		push_error("3D puzzle admission failed: " + str(loaded.get("errors", [])))
		return
	camera = $Camera3D
	key_light = $KeyLight
	get_viewport().msaa_3d = Viewport.MSAA_2X
	board_3d = $Board3D
	hud = $HUD
	build_stage()
	board_3d.build(session.puzzle)
	hud.undo_requested.connect(undo)
	hud.restart_requested.connect(restart)
	hud.quality_requested.connect(toggle_quality)
	hud.motion_requested.connect(toggle_motion)
	hud.header.minimum_size_changed.connect(queue_layout)
	hud.footer.minimum_size_changed.connect(queue_layout)
	get_viewport().size_changed.connect(queue_layout)
	refresh()
	queue_layout()

func build_stage() -> void:
	var stage := $Stage
	var cream := MeowMaterials3D.material("Cream courtyard floor", Color("f4ede1"), 0.86)
	var plane := PlaneMesh.new()
	plane.size = Vector2(30, 30)
	stage.add_child(MeowGeometry3D.instance(plane, cream, Vector3(0, -0.25, 0)))
	var base := MeowGeometry3D.instance(MeowGeometry3D.rounded_box(4.66, 4.66, 0.26, 0.28, 0.06), MeowMaterials3D.material("Sky blue ceramic plinth", Color("cbdfea"), 0.5), Vector3(0, -0.24, 0))
	base.name = "ThickCeramicBoardBase"
	stage.add_child(base)
	stage.add_child(MeowGeometry3D.instance(MeowGeometry3D.rounded_box(4.47, 4.47, 0.09, 0.22, 0.025), MeowMaterials3D.material("Cream ceramic upper lip", Color("fff6e6"), 0.58), Vector3(0, -0.035, 0)))
	var plant := MeowModelBuilder3D.new()
	var pot := MeowMaterials3D.material("Blush ceramic pot", Color("e9bdcd"), 0.6)
	plant.add(MeowGeometry3D.cylinder(), pot, Transform3D(Basis.IDENTITY.scaled(Vector3(0.30, 0.22, 0.30)), Vector3(0, 0.11, 0)))
	plant.add(MeowGeometry3D.cylinder(), pot, Transform3D(Basis.IDENTITY.scaled(Vector3(0.34, 0.055, 0.34)), Vector3(0, 0.225, 0)))
	var leaf := MeowMaterials3D.material("Mint leaves", Color("90bba0"), 0.74)
	for side in [-1, 0, 1]:
		plant.add(MeowGeometry3D.sphere(), leaf, Transform3D(Basis.from_euler(Vector3(0, 0, side * -0.4)) * Basis.from_scale(Vector3(0.13, 0.37, 0.12)), Vector3(side * 0.07, 0.38, 0)))
	stage.add_child(MeowGeometry3D.instance(plant.finish(), null, Vector3(-2.47, -0.25, -1.8)))
	var pebble := MeowMaterials3D.material("Lavender courtyard stones", Color("d7c9e9"), 0.8)
	for i in range(3):
		stage.add_child(MeowGeometry3D.instance(MeowGeometry3D.small_sphere(), pebble, Vector3(2.45, -0.20, 0.9 + i * 0.22), Vector3(0.22, 0.10, 0.17)))

func refresh() -> void:
	last_evaluation = PuzzleRules.evaluate(session.board, session.puzzle.regions)
	board_3d.reflect(session.board, last_evaluation, selected, reduced_motion or not balanced_quality)
	hud.refresh(session, last_evaluation, balanced_quality, reduced_motion)
	queue_layout()

func queue_layout() -> void:
	if layout_pending:
		return
	layout_pending = true
	call_deferred("fit_camera")

func fit_camera() -> void:
	layout_pending = false
	if camera == null or hud == null:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	if viewport_size.x < 1 or viewport_size.y < 1:
		return
	var available := hud.board_rect()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	camera.size = 5.6
	camera.position = Vector3(0, 9.5, 4.8)
	camera.look_at(Vector3(0, 0.18, 0), Vector3.UP)
	var desired_y := available.get_center().y
	camera.position += camera.basis.y * ((desired_y - viewport_size.y / 2.0) * camera.size / viewport_size.x)

func _unhandled_input(event: InputEvent) -> void:
	if paused or session.puzzle.is_empty():
		return
	if event is InputEventScreenTouch:
		if event.pressed and touch_index == -1:
			touch_index = event.index
			touch_origin = event.position
			touch_dragged = false
		elif event.pressed:
			touch_dragged = true
		elif event.index == touch_index:
			if not touch_dragged and event.position.distance_to(touch_origin) <= 18:
				queue_pick(event.position)
			touch_index = -1
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and event.index == touch_index:
		if event.position.distance_to(touch_origin) > 18:
			touch_dragged = true
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and event.device != -1:
		queue_pick(event.position)
		get_viewport().set_input_as_handled()

func queue_pick(point: Vector2) -> void:
	if not session.is_complete() and hud.board_rect().has_point(point):
		pending_picks.append(point)

func _physics_process(_delta: float) -> void:
	if paused:
		pending_picks.clear()
		return
	for point in pending_picks:
		var coordinate := board_3d.pick(camera, point)
		if coordinate.x >= 0:
			apply_cell(coordinate)
	pending_picks.clear()

func apply_cell(coordinate: Vector2i) -> bool:
	var result := session.cycle(coordinate.x, coordinate.y)
	if not result.ok:
		return false
	selected = coordinate
	refresh()
	MeowAudio.instance().play_sfx("select")
	var state := int(session.board[coordinate.x][coordinate.y])
	MeowAudio.instance().play_sfx("invalid" if state == PuzzleRules.CellState.CAT and last_evaluation.status == "invalid" else ("place" if state == PuzzleRules.CellState.CAT else ("mark" if state == PuzzleRules.CellState.EXCLUDED else "erase")))
	if session.is_complete():
		MeowAudio.instance().play_sfx("complete")
		MeowAudio.instance().play_cat("chirp")
	elif state == PuzzleRules.CellState.CAT and last_evaluation.status != "invalid":
		MeowAudio.instance().play_cat()
	return true

func undo() -> void:
	var result := session.undo()
	if result.ok:
		selected = Vector2i(result.row, result.column)
		refresh()
		MeowAudio.instance().play_sfx("undo")

func restart() -> void:
	pending_picks.clear()
	session.restart()
	selected = Vector2i(-1, -1)
	refresh()
	MeowAudio.instance().play_sfx("restart")

func audio_has_cats() -> bool:
	return not session.puzzle.is_empty() and last_evaluation.cat_count > 0 and not session.is_complete()

func toggle_quality() -> void:
	balanced_quality = not balanced_quality
	key_light.shadow_enabled = balanced_quality
	get_viewport().msaa_3d = Viewport.MSAA_2X if balanced_quality else Viewport.MSAA_DISABLED
	refresh()

func toggle_motion() -> void:
	reduced_motion = not reduced_motion
	refresh()

func _process(_delta: float) -> void:
	if hud != null and hud.profile_label.visible:
		hud.profile_label.text = "%d FPS · %d draw calls · %d visible primitives" % [Engine.get_frames_per_second(), int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)), int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))]

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED:
		paused = true
		pending_picks.clear()
		touch_index = -1
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		paused = false

