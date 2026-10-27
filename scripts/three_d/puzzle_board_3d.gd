class_name PuzzleBoard3D
extends Node3D

const TILE := preload("res://scenes/three_d/puzzle_tile.tscn")
const SPACING := 1.08
var tiles: Array[PuzzleTile3D] = []
var size := 4

func build(puzzle: Dictionary) -> void:
	for tile in tiles:
		remove_child(tile)
		tile.queue_free()
	tiles.clear()
	size = int(puzzle.size)
	for row in range(size):
		for column in range(size):
			var tile := TILE.instantiate() as PuzzleTile3D
			tile.name = "Tile_%d_%d" % [row, column]
			tile.position = Vector3((float(column) - float(size - 1) / 2.0) * SPACING, 0.08, (float(row) - float(size - 1) / 2.0) * SPACING)
			add_child(tile)
			tile.configure(row, column, int(puzzle.regions[row][column]), size)
			tiles.append(tile)

func reflect(board: Array, evaluation: Dictionary, selected: Vector2i, reduced: bool) -> void:
	for tile in tiles:
		var coordinate := Vector2i(tile.row, tile.column)
		tile.reflect(int(board[tile.row][tile.column]), evaluation.conflicts.has(coordinate), selected == coordinate, evaluation.complete, reduced)

func pick(camera: Camera3D, screen_position: Vector2) -> Vector2i:
	var origin := camera.project_ray_origin(screen_position)
	var direction := camera.project_ray_normal(screen_position)
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * 60, 1)
	query.collide_with_areas = false
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return Vector2i(-1, -1)
	var tile := hit.collider as PuzzleTile3D
	return Vector2i(tile.row, tile.column) if tile != null else Vector2i(-1, -1)
