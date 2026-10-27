extends SceneTree
## Offline asset baker. Original geometry; no runtime 3D cost in the campaign UI.
const NAMES := ["tuxedo", "cream", "tabby", "gray", "rose"]
const COATS := [Color("343441"), Color("ebd3aa"), Color("d99451"), Color("8996ae"), Color("cf95b8")]
const BIBS := [Color("fff7e9"), Color("fff1d9"), Color("ffe8bf"), Color("e5e7f1"), Color("ffe7f2")]

func _initialize() -> void:
	call_deferred("bake")

func bake() -> void:
	root.size = Vector2i(512, 512)
	root.transparent_bg = true
	root.msaa_3d = Viewport.MSAA_4X
	# Smooth production render meshes; the retained real-time prototype is unchanged.
	MeowGeometry3D.sphere().radial_segments = 40
	MeowGeometry3D.sphere().rings = 24
	MeowGeometry3D.small_sphere().radial_segments = 28
	MeowGeometry3D.small_sphere().rings = 16
	var world := Node3D.new()
	root.add_child(world)
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0, 0, 0, 0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("eee4ff")
	env.ambient_light_energy = 0.30
	environment.environment = env
	world.add_child(environment)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 1.39
	camera.position = Vector3(1.0, 0.98, 3.9)
	world.add_child(camera)
	camera.look_at(Vector3(0.035, 0.57, 0), Vector3.UP)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35, -32, 0)
	key.light_color = Color("fff0da")
	key.light_energy = 0.55
	world.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-15, 145, 0)
	fill.light_color = Color("d9e8ff")
	fill.light_energy = 0.18
	world.add_child(fill)
	DirAccess.make_dir_recursive_absolute("res://assets/cats")
	TuxedoCat3D.build_meshes()
	for variant in range(5):
		var cat := TuxedoCat3D.new()
		cat.reduced_motion = true
		world.add_child(cat)
		cat.set_motion(true)
		for child in cat.visual.get_children():
			var instance := child as MeshInstance3D
			for surface in range(instance.mesh.get_surface_count()):
				var source := instance.mesh.surface_get_material(surface) as StandardMaterial3D
				var mat := source.duplicate() as StandardMaterial3D
				if source == MeowMaterials3D.charcoal():
					mat.albedo_color = Color("30313e") if child == cat.eyes else COATS[variant]
				elif source == MeowMaterials3D.cream():
					mat.albedo_color = Color("fffaf0") if child == cat.eyes else BIBS[variant]
				elif source.resource_name == "Sage gold eyes":
					mat.albedo_color = [Color("c3d1a0"), Color("86bcb8"), Color("9db895"), Color("d4bc82"), Color("b7a2d8")][variant]
				mat.roughness = 0.55
				instance.set_surface_override_material(surface, mat)
		# Plush cheeks and small fur tufts, shared silhouette across the collection.
		var extras := MeowModelBuilder3D.new()
		var cheek := MeowMaterials3D.material("cheek_%d" % variant, BIBS[variant])
		var blush := MeowMaterials3D.material("Blush", Color("e9acba"))
		for side in [-1, 1]:
			extras.ellipsoid(Vector3(side * 0.225, 0.685, 0.287), Vector3(0.19, 0.16, 0.11), cheek)
			extras.ellipsoid(Vector3(side * 0.255, 0.697, 0.337), Vector3(0.09, 0.045, 0.025), blush, true)
			for tuft in range(3):
				extras.ellipsoid(Vector3(side * (0.31 + tuft * 0.012), 0.70 - tuft * 0.035, 0.11), Vector3(0.08, 0.065, 0.07), MeowMaterials3D.material("coat_%d" % variant, COATS[variant]), true)
		if variant == 2:
			var stripe := MeowMaterials3D.material("Original tabby stripes", Color("ab6639"))
			for offset in [-1, 0, 1]:
				extras.ellipsoid(Vector3(offset * 0.095, 0.916, 0.235), Vector3(0.042, 0.115, 0.033), stripe, true)
			for side in [-1, 1]:
				for band in range(2):
					extras.ellipsoid(Vector3(side * 0.30, 0.76 - band * 0.06, 0.235), Vector3(0.09, 0.022, 0.04), stripe, true)
		cat.visual.add_child(MeowGeometry3D.instance(extras.finish(), null))
		for frame in range(5):
			await process_frame
		await RenderingServer.frame_post_draw
		var picture := root.get_texture().get_image()
		var error := picture.save_png("res://assets/cats/" + NAMES[variant] + ".png")
		if error != OK:
			push_error("Cannot write cat asset")
			quit(1)
			return
		print("BAKED: ", NAMES[variant], " 512x512 RGBA")
		world.remove_child(cat)
		cat.queue_free()
	world.queue_free()
	quit()
