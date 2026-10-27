extends SceneTree
## Deterministic offline curation. Keeps the original 32 IDs/boards and adds 118.
const LEGACY_PATH := "res://tests/fixtures/legacy_campaign_v1.json"
const TARGET := 150

func _initialize() -> void:
	call_deferred("run")

func fail(message: String) -> void:
	push_error(message)
	quit(1)

func run() -> void:
	var legacy: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(LEGACY_PATH))
	var chosen: Array[Dictionary] = []
	var seen: Dictionary = {}
	var counts := {"Easy": 0, "Medium": 0, "Hard": 0, "Expert": 0}
	var titles: Dictionary = {}
	var legacy_ids: Array = []
	for original in legacy.levels:
		if not PuzzleValidator.validate(original).valid:
			fail("Original level is invalid: " + str(original.id))
			return
		var puzzle: Dictionary = original.duplicate(true)
		chosen.append(puzzle)
		seen[CampaignDifficulty.symmetry_signature(puzzle)] = true
		counts[puzzle.difficulty] += 1
		titles[puzzle.title] = true
		legacy_ids.append(puzzle.id)
	if chosen.size() != 32 or seen.size() != 32:
		fail("Original campaign must contain 32 distinct valid puzzles.")
		return
	var names := ["Peach", "Mint", "Lilac", "Cream", "Sky", "Rose", "Honey", "Velvet", "Cloud", "Clover"]
	var places := ["Nook", "Terrace", "Orchard", "Window", "Courtyard", "Trail", "Hollow", "Porch", "Meadow", "Arbor", "Garden", "Cove", "Retreat"]
	var name_index := 0
	var attempted := 0
	for seed_value in range(2000, 8000):
		if chosen.size() == TARGET:
			break
		attempted += 1
		var generated := PuzzleGenerator.generate(5, seed_value)
		if not generated.ok:
			continue
		var puzzle: Dictionary = generated.puzzle
		var metrics := CampaignDifficulty.measure(puzzle)
		# After the two retained introductory boards, avoid reversing the ramp.
		if metrics.score < 311:
			continue
		var group := CampaignDifficulty.group_for(metrics.score)
		if counts[group] >= CampaignDifficulty.GROUP_COUNTS[group]:
			continue
		var signature := CampaignDifficulty.symmetry_signature(puzzle)
		if seen.has(signature):
			continue
		seen[signature] = true
		counts[group] += 1
		puzzle.id = "%s_%02d" % [group.to_lower(), counts[group]]
		puzzle.difficulty = group
		puzzle.curation = metrics
		var title := ""
		while title.is_empty() or titles.has(title):
			title = names[name_index % names.size()] + " " + places[name_index / names.size()]
			name_index += 1
		puzzle.title = title
		titles[title] = true
		chosen.append(puzzle)
		if chosen.size() % 10 == 0:
			print("CURATION: ", chosen.size(), "/150; candidates ", attempted, "; groups ", counts)
	if chosen.size() != TARGET:
		fail("Insufficient validated candidates: " + str(counts))
		return
	# Stable original order breaks ties; only the order metadata is changed.
	var intro: Array[Dictionary] = []
	var ranked: Array[Dictionary] = []
	for puzzle in chosen:
		if CampaignDifficulty.INTRO_IDS.has(puzzle.id):
			intro.append(puzzle)
		else:
			ranked.append(puzzle)
	ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var sa: int = a.curation.score
		var sb: int = b.curation.score
		if sa != sb:
			return sa < sb
		var ai := legacy_ids.find(a.id)
		var bi := legacy_ids.find(b.id)
		if ai >= 0 or bi >= 0:
			return ai < bi if ai >= 0 and bi >= 0 else ai >= 0
		return int(a.seed) < int(b.seed))
	intro.append_array(ranked)
	var manifest := {"version": 1, "campaign_revision": 2, "target_count": TARGET, "daily_seed": legacy.daily_seed, "daily_pool": legacy_ids, "curation": "150 unique 5x5 puzzles; original 32 IDs/boards retained. Remaining 118 seeded, uniqueness validated, rotation/reflection deduplicated. Two introductory boards followed by nondecreasing singleton/solver-node score. Difficulty is heuristic, not human calibrated.", "difficulty_counts": CampaignDifficulty.GROUP_COUNTS, "levels": []}
	for index in range(intro.size()):
		var puzzle: Dictionary = intro[index]
		puzzle.order = index + 1
		if not PuzzleValidator.validate(puzzle).valid:
			fail("Final admission failed: " + str(puzzle.id))
			return
		var path := "res://data/levels/" + str(puzzle.id) + ".json"
		var file := FileAccess.open(path, FileAccess.WRITE)
		if file == null:
			fail("Cannot write " + path)
			return
		file.store_string(JSON.stringify(puzzle, "  ") + "\n")
		file.close()
		manifest.levels.append({"path": path})
	var file := FileAccess.open(LevelCatalog.PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest, "  ") + "\n")
	file.close()
	print("BUILT: ", intro.size(), " validated levels; ", counts, "; candidates ", attempted)
	quit()
