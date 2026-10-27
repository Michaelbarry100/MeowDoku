class_name TuxedoCat3D
extends Node3D
## Actual three-dimensional original model. No sprites, billboards or textures.
static var body_mesh: ArrayMesh
static var eyes_mesh: ArrayMesh
static var tail_mesh: ArrayMesh
var visual: Node3D
var eyes: MeshInstance3D
var tail: MeshInstance3D
var reduced_motion := false
var completed := false
var elapsed := 0.0
var appearance: Tween

static func build_meshes() -> void:
	if body_mesh != null:
		return
	var black := MeowMaterials3D.charcoal()
	var white := MeowMaterials3D.cream()
	var pink := MeowMaterials3D.material("Nose and ear velvet", Color("d993ad"), 0.64)
	var iris := MeowMaterials3D.material("Sage gold eyes", Color("bed49a"), 0.28)
	var builder := MeowModelBuilder3D.new()
	builder.ellipsoid(Vector3(0, 0.33, -0.045), Vector3(0.51, 0.61, 0.45), black)
	builder.ellipsoid(Vector3(0, 0.72, 0.07), Vector3(0.71, 0.59, 0.57), black)
	# White chest, forehead blaze, two muzzle pads and separate socks/paws.
	builder.ellipsoid(Vector3(0, 0.35, 0.175), Vector3(0.32, 0.38, 0.12), white)
	builder.ellipsoid(Vector3(0, 0.755, 0.32), Vector3(0.12, 0.33, 0.075), white)
	for side in [-1, 1]:
		builder.ellipsoid(Vector3(side * 0.07, 0.645, 0.332), Vector3(0.17, 0.13, 0.095), white, true)
		builder.ellipsoid(Vector3(side * 0.155, 0.067, 0.16), Vector3(0.195, 0.13, 0.255), white)
		builder.ellipsoid(Vector3(side * 0.218, 0.105, -0.115), Vector3(0.19, 0.205, 0.255), black)
		var ear := ear_mesh(float(side))
		builder.add(ear, black, Transform3D.IDENTITY)
		# Thick inset inner ear, not a texture decal.
		builder.ellipsoid(Vector3(side * 0.235, 0.972, 0.116), Vector3(0.115, 0.20, 0.035), pink, true)
		for offset in [-1, 0, 1]:
			builder.segment(Vector3(side * 0.13, 0.641 + offset * 0.022, 0.376), Vector3(side * 0.37, 0.655 + offset * 0.060, 0.35), 0.007, white)
	# Small three-dimensional nose and two curved mouth strokes.
	builder.ellipsoid(Vector3(0, 0.668, 0.394), Vector3(0.066, 0.045, 0.039), pink, true)
	for side in [-1, 1]:
		builder.segment(Vector3(0, 0.644, 0.389), Vector3(side * 0.024, 0.615, 0.388), 0.006, black)
		builder.segment(Vector3(side * 0.024, 0.615, 0.388), Vector3(side * 0.049, 0.623, 0.379), 0.006, black)
	body_mesh = builder.finish()
	body_mesh.resource_name = "Original tuxedo body, head, ears, four paws and whiskers"
	var eye_builder := MeowModelBuilder3D.new()
	for side in [-1, 1]:
		# Eyes face slightly upwards toward the overhead camera.
		eye_builder.ellipsoid(Vector3(side * 0.15, 0.79, 0.312), Vector3(0.139, 0.16, 0.085), iris, true)
		eye_builder.ellipsoid(Vector3(side * 0.15, 0.8, 0.352), Vector3(0.047, 0.108, 0.023), black, true)
		eye_builder.ellipsoid(Vector3(side * 0.15 - 0.017, 0.829, 0.363), Vector3(0.025, 0.030, 0.013), white, true)
	eyes_mesh = eye_builder.finish()
	var tail_builder := MeowModelBuilder3D.new()
	var points := [Vector3(0.16, 0.14, -0.20), Vector3(0.32, 0.17, -0.25), Vector3(0.41, 0.29, -0.22), Vector3(0.43, 0.43, -0.17), Vector3(0.38, 0.54, -0.15)]
	for i in range(points.size() - 1):
		tail_builder.segment(points[i], points[i + 1], 0.046, black)
		tail_builder.ellipsoid(points[i + 1], Vector3.ONE * 0.092, black, true)
	tail_mesh = tail_builder.finish()

static func ear_mesh(side: float) -> ArrayMesh:
	var a := Vector3(side * 0.335, 0.86, 0.15)
	var b := Vector3(side * 0.115, 0.91, 0.15)
	var c := Vector3(side * 0.275, 1.145, 0.04)
	var d := Vector3(side * 0.275, 0.88, -0.065)
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for face in [[a, b, c], [a, c, d], [b, d, c], [a, d, b]]:
		var center: Vector3 = (a + b + c + d) / 4.0
		var normal: Vector3 = -(face[1] - face[0]).cross(face[2] - face[0]).normalized()
		var outward: Vector3 = (face[0] + face[1] + face[2]) / 3.0 - center
		if normal.dot(outward) < 0:
			MeowGeometry3D.triangle(tool, face[0], face[2], face[1], -normal)
		else:
			MeowGeometry3D.triangle(tool, face[0], face[1], face[2], normal)
	return tool.commit()

func _ready() -> void:
	build_meshes()
	visual = Node3D.new()
	visual.name = "CatGeometry"
	add_child(visual)
	var body := MeowGeometry3D.instance(body_mesh, null)
	body.name = "MergedBodyHeadEarsPaws"
	visual.add_child(body)
	eyes = MeowGeometry3D.instance(eyes_mesh, null)
	eyes.name = "Expressive3DEyes"
	visual.add_child(eyes)
	tail = MeowGeometry3D.instance(tail_mesh, null)
	tail.name = "Curved3DTail"
	visual.add_child(tail)
	elapsed = float(get_index()) * 0.39
	if not reduced_motion:
		visual.scale = Vector3.ONE * 0.12
		appearance = create_tween()
		appearance.tween_property(visual, "scale", Vector3.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func set_motion(reduced: bool) -> void:
	reduced_motion = reduced
	if appearance:
		appearance.kill()
	if visual != null:
		visual.scale = Vector3.ONE
		visual.position = Vector3.ZERO
		visual.rotation = Vector3.ZERO
		tail.rotation = Vector3.ZERO
		eyes.scale = Vector3.ONE
		eyes.position = Vector3.ZERO

func _process(delta: float) -> void:
	if reduced_motion or visual == null:
		return
	elapsed += delta
	visual.position.y = sin(elapsed * 1.8) * 0.008
	visual.rotation.z = sin(elapsed * 1.2) * 0.013
	tail.rotation.y = sin(elapsed * 1.6) * 0.06
	# Brief geometric blinks; no texture swapping or camera-facing billboards.
	var blink := fmod(elapsed, 4.8)
	var openness := 0.08 if blink > 4.65 else 1.0
	eyes.scale.y = openness
	eyes.position.y = 0.79 * (1.0 - openness)
