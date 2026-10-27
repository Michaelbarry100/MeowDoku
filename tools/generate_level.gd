extends SceneTree
## godot --headless --path . --script res://tools/generate_level.gd -- --size=5 --seed=42 --output=res://data/generated_42.json

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var options := {"size": "5", "seed": "42", "output": "", "attempts": "250", "nodes": "100000"}
	for argument in OS.get_cmdline_user_args():
		var parts := argument.trim_prefix("--").split("=", true, 1)
		if not argument.begins_with("--") or parts.size() != 2 or not options.has(parts[0]):
			printerr("Expected --size=N --seed=INTEGER --output=res://data/name.json [--attempts=250 --nodes=100000]")
			quit(1)
			return
		options[parts[0]] = parts[1]
	for key in ["size", "seed", "attempts", "nodes"]:
		if not str(options[key]).is_valid_int():
			printerr("Option --%s must be an integer." % key)
			quit(1)
			return
	var output: String = str(options.output).simplify_path()
	if not output.begins_with("res://data/") or not output.ends_with(".json") or FileAccess.file_exists(output):
		printerr("Choose a new .json file inside res://data/. Existing files are never overwritten.")
		quit(1)
		return
	var result := PuzzleGenerator.generate(int(options.size), int(options.seed), true, int(options.attempts), int(options.nodes))
	if not result.ok:
		printerr("Generation failed: ", result.errors)
		quit(1)
		return
	var file := FileAccess.open(output, FileAccess.WRITE)
	if file == null:
		printerr("Cannot write level: ", FileAccess.get_open_error())
		quit(1)
		return
	file.store_string(JSON.stringify(result.puzzle, "  ") + "\n")
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		printerr("Cannot finish writing level: ", write_error)
		quit(1)
		return
	var loaded := LevelData.load_validated(output)
	if not loaded.ok:
		printerr("Saved level failed validation: ", loaded.errors)
		quit(1)
		return
	print("Saved validated unique puzzle to ", output, " (seed ", result.puzzle.seed, ")")
	quit(0)
