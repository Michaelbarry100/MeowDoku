class_name PuzzleTile3D
extends StaticBody3D

const CAT := preload("res://scenes/three_d/tuxedo_cat.tscn")
const HEIGHT := 0.20
var row := 0
var column := 0
var state := PuzzleRules.CellState.EMPTY
var invalid := false
var selected := false
var visual: Node3D
var tile_mesh: MeshInstance3D
var ring: MeshInstance3D
var cross: Node3D
var check_mark: MeshInstance3D
var warning: Node3D
var cat: TuxedoCat3D
var cat_shape: CollisionShape3D
var selection_tween: Tween
var reduced_motion := false

func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	visual = Node3D.new()
	visual.name = "RaisedTileVisual"
	add_child(visual)
	tile_mesh = MeowGeometry3D.instance(MeowGeometry3D.rounded_box(1.0, 1.0, HEIGHT), MeowMaterials3D.region(0, 4))
	tile_mesh.name = "BeveledTileMesh"
	visual.add_child(tile_mesh)
	var shape := CollisionShape3D.new()
	shape.name = "TileCollision"
	var box := BoxShape3D.new()
	box.size = Vector3(1, HEIGHT, 1)
	shape.shape = box
	shape.position.y = HEIGHT / 2
	add_child(shape)
	cat_shape = CollisionShape3D.new()
	cat_shape.name = "CatTouchCollision"
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.27
	capsule.height = 0.82
	cat_shape.shape = capsule
	cat_shape.position = Vector3(0, HEIGHT + 0.41, 0.04)
	cat_shape.disabled = true
	add_child(cat_shape)
	ring = MeowGeometry3D.instance(MeowGeometry3D.rounded_ring(0.94, 0.94, 0.12), MeowMaterials3D.material("Selection plum", Color("70618d"), 0.38), Vector3(0, HEIGHT + 0.014, 0))
	ring.name = "StateRimGeometry"
	ring.visible = false
	visual.add_child(ring)
	cross = Node3D.new()
	cross.name = "ExcludedXGeometry"
	for angle in [-PI / 4, PI / 4]:
		var stroke := MeowGeometry3D.instance(MeowGeometry3D.rounded_box(0.51, 0.065, 0.035, 0.03, 0.01), MeowMaterials3D.material("Notes plum", Color("766386")), Vector3(0, HEIGHT + 0.008, 0))
		stroke.rotation.y = angle
		cross.add_child(stroke)
	cross.visible = false
	visual.add_child(cross)
	var check_builder := MeowModelBuilder3D.new()
	var green := MeowMaterials3D.material("Valid sage", Color("327d65"), 0.55)
	check_builder.segment(Vector3(0.22, HEIGHT + 0.04, 0.29), Vector3(0.28, HEIGHT + 0.04, 0.36), 0.019, green)
	check_builder.segment(Vector3(0.28, HEIGHT + 0.04, 0.36), Vector3(0.41, HEIGHT + 0.04, 0.20), 0.019, green)
	check_mark = MeowGeometry3D.instance(check_builder.finish(), null)
	check_mark.name = "ValidCheckGeometry"
	check_mark.visible = false
	visual.add_child(check_mark)
	warning = Node3D.new()
	warning.name = "ConflictExclamationGeometry"
	var red := MeowMaterials3D.material("Conflict rose", Color("b23e60"), 0.5)
	warning.add_child(MeowGeometry3D.instance(MeowGeometry3D.rounded_box(0.045, 0.13, 0.03, 0.015, 0.008), red, Vector3(0.38, HEIGHT + 0.025, 0.22)))
	warning.add_child(MeowGeometry3D.instance(MeowGeometry3D.small_sphere(), red, Vector3(0.38, HEIGHT + 0.04, 0.36), Vector3(0.055, 0.028, 0.055)))
	warning.visible = false
	visual.add_child(warning)

func configure(r: int, c: int, region_id: int, count: int) -> void:
	row = r
	column = c
	set_meta("tile_coordinate", Vector2i(row, column))
	tile_mesh.material_override = MeowMaterials3D.region(region_id, count)

func reflect(new_state: int, conflict: bool, is_selected: bool, completed: bool, motion_off: bool) -> void:
	var changed_selection := selected != is_selected
	state = new_state
	invalid = conflict
	selected = is_selected
	reduced_motion = motion_off
	cross.visible = state == PuzzleRules.CellState.EXCLUDED
	warning.visible = state == PuzzleRules.CellState.CAT and invalid
	check_mark.visible = state == PuzzleRules.CellState.CAT and not invalid
	ring.visible = selected or state == PuzzleRules.CellState.CAT or completed
	ring.material_override = MeowMaterials3D.material("Conflict rose", Color("b23e60"), 0.5) if invalid else (MeowMaterials3D.material("Valid sage", Color("327d65"), 0.55) if completed or state == PuzzleRules.CellState.CAT else MeowMaterials3D.material("Selection plum", Color("70618d"), 0.38))
	if state == PuzzleRules.CellState.CAT and cat == null:
		cat = CAT.instantiate() as TuxedoCat3D
		cat.reduced_motion = reduced_motion
		cat.position.y = HEIGHT
		cat.scale = Vector3.ONE * 0.72
		visual.add_child(cat)
	elif state != PuzzleRules.CellState.CAT and cat != null:
		visual.remove_child(cat)
		cat.queue_free()
		cat = null
	cat_shape.set_deferred("disabled", state != PuzzleRules.CellState.CAT)
	if cat != null:
		cat.completed = completed
		if cat.reduced_motion != reduced_motion:
			cat.set_motion(reduced_motion)
	if changed_selection or reduced_motion:
		if selection_tween:
			selection_tween.kill()
		var rise := 0.055 if selected else 0.0
		if reduced_motion:
			visual.position.y = rise
		else:
			selection_tween = create_tween()
			selection_tween.tween_property(visual, "position:y", rise, 0.14).set_trans(Tween.TRANS_SINE)
