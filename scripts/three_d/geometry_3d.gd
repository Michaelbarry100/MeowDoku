class_name MeowGeometry3D
extends RefCounted
## Original texture-free procedural meshes, shared across instances.
static var cache: Dictionary = {}

static func sphere() -> SphereMesh:
	if not cache.has("sphere"):
		var mesh := SphereMesh.new()
		mesh.radius = 0.5
		mesh.height = 1.0
		mesh.radial_segments = 16
		mesh.rings = 8
		cache.sphere = mesh
	return cache.sphere

static func small_sphere() -> SphereMesh:
	if not cache.has("small_sphere"):
		var mesh := SphereMesh.new()
		mesh.radius = 0.5
		mesh.height = 1.0
		mesh.radial_segments = 10
		mesh.rings = 5
		cache.small_sphere = mesh
	return cache.small_sphere

static func cylinder() -> CylinderMesh:
	if not cache.has("cylinder"):
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.5
		mesh.bottom_radius = 0.5
		mesh.height = 1.0
		mesh.radial_segments = 10
		cache.cylinder = mesh
	return cache.cylinder

static func profile(width: float, depth: float, radius: float, steps: int = 6) -> PackedVector2Array:
	var points := PackedVector2Array()
	var centers := [Vector2(width / 2 - radius, depth / 2 - radius), Vector2(-width / 2 + radius, depth / 2 - radius), Vector2(-width / 2 + radius, -depth / 2 + radius), Vector2(width / 2 - radius, -depth / 2 + radius)]
	for corner in range(4):
		for step in range(steps + 1):
			var angle := (float(corner) + float(step) / float(steps)) * PI / 2.0
			points.append(centers[corner] + Vector2(cos(angle), sin(angle)) * radius)
	return points

static func triangle(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, normal: Vector3) -> void:
	tool.set_normal(normal)
	tool.add_vertex(a)
	tool.add_vertex(b)
	tool.add_vertex(c)

static func rounded_box(width: float, depth: float, height: float, radius: float = 0.12, bevel: float = 0.035) -> ArrayMesh:
	var key := "box:%f:%f:%f:%f:%f" % [width, depth, height, radius, bevel]
	if cache.has(key):
		return cache[key]
	var rings: Array[PackedVector3Array] = []
	for layer in range(4):
		var inset := bevel if layer == 0 or layer == 3 else 0.0
		var y: float = [0.0, bevel, height - bevel, height][layer]
		var ring := PackedVector3Array()
		for point in profile(width - inset * 2, depth - inset * 2, maxf(0.01, radius - inset)):
			ring.append(Vector3(point.x, y, point.y))
		rings.append(ring)
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count := rings[0].size()
	for i in range(count):
		var next := (i + 1) % count
		triangle(tool, Vector3(0, height, 0), rings[3][i], rings[3][next], Vector3.UP)
		triangle(tool, Vector3.ZERO, rings[0][next], rings[0][i], Vector3.DOWN)
		for layer in range(3):
			var a := rings[layer][i]
			var b := rings[layer][next]
			var c := rings[layer + 1][next]
			var d := rings[layer + 1][i]
			var normal := -(b - a).cross(c - a).normalized()
			triangle(tool, a, b, c, normal)
			triangle(tool, a, c, d, normal)
	tool.index()
	var mesh := tool.commit()
	mesh.resource_name = "Real beveled rounded box"
	cache[key] = mesh
	return mesh

static func rounded_ring(width: float, depth: float, radius: float, tube: float = 0.012) -> ArrayMesh:
	var key := "ring:%f:%f:%f:%f" % [width, depth, radius, tube]
	if cache.has(key):
		return cache[key]
	var points := profile(width, depth, radius)
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	for i in range(points.size()):
		var tangent := (points[(i + 1) % points.size()] - points[(i - 1 + points.size()) % points.size()]).normalized()
		var outward := Vector3(tangent.y, 0, -tangent.x)
		for side in range(8):
			var angle := float(side) * TAU / 8.0
			var normal := Vector3.UP * cos(angle) + outward * sin(angle)
			vertices.append(Vector3(points[i].x, 0, points[i].y) + normal * tube)
			normals.append(normal)
	for i in range(points.size()):
		for side in range(8):
			var a := i * 8 + side
			var b := ((i + 1) % points.size()) * 8 + side
			var c := ((i + 1) % points.size()) * 8 + (side + 1) % 8
			var d := i * 8 + (side + 1) % 8
			indices.append_array(PackedInt32Array([a, b, c, a, c, d]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	cache[key] = mesh
	return mesh

static func instance(mesh: Mesh, material: Material, position: Vector3 = Vector3.ZERO, scale: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	node.position = position
	node.scale = scale
	return node

static func triangle_count(mesh: Mesh) -> int:
	var total := 0
	for surface in range(mesh.get_surface_count()):
		var arrays := mesh.surface_get_arrays(surface)
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		total += (indices.size() if not indices.is_empty() else vertices.size()) / 3
	return total
