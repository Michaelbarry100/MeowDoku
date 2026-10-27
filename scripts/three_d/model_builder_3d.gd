class_name MeowModelBuilder3D
extends RefCounted
## Bake original component meshes into a small number of PBR material surfaces.
var groups: Dictionary = {}

func add(mesh: Mesh, material: Material, transform: Transform3D) -> void:
	if not groups.has(material):
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		tool.set_material(material)
		groups[material] = tool
	var tool: SurfaceTool = groups[material]
	var normal_transform := transform.basis.inverse().transposed()
	for surface in range(mesh.get_surface_count()):
		var arrays := mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		for index in range(indices.size() if not indices.is_empty() else vertices.size()):
			var i := indices[index] if not indices.is_empty() else index
			tool.set_normal((normal_transform * normals[i]).normalized())
			tool.add_vertex(transform * vertices[i])

func ellipsoid(center: Vector3, dimensions: Vector3, material: Material, small: bool = false) -> void:
	add(MeowGeometry3D.small_sphere() if small else MeowGeometry3D.sphere(), material, Transform3D(Basis.IDENTITY.scaled(dimensions), center))

func segment(a: Vector3, b: Vector3, radius: float, material: Material) -> void:
	var direction := b - a
	var rotation := Basis(Quaternion(Vector3.UP, direction.normalized()))
	add(MeowGeometry3D.cylinder(), material, Transform3D(rotation * Basis.from_scale(Vector3(radius * 2, direction.length(), radius * 2)), (a + b) * 0.5))

func finish() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	for tool in groups.values():
		tool.index()
		tool.commit(mesh)
	return mesh
