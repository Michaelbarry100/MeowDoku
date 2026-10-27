class_name MeowMaterials3D
extends RefCounted

static var cache: Dictionary = {}

static func material(key: String, color: Color, roughness: float = 0.65) -> StandardMaterial3D:
	if cache.has(key):
		return cache[key]
	var result := StandardMaterial3D.new()
	result.resource_name = key
	result.albedo_color = color
	result.roughness = roughness
	result.metallic_specular = 0.35
	cache[key] = result
	return result

static func charcoal() -> StandardMaterial3D:
	return preload("res://resources/three_d/charcoal_fur.tres")

static func cream() -> StandardMaterial3D:
	return preload("res://resources/three_d/cream_fur.tres")

static func region(id: int, count: int) -> StandardMaterial3D:
	return material("Pastel region %d of %d" % [id, count], PurrTheme.region_color(id, count))
