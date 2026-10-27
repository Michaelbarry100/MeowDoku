class_name PlayerSave
extends RefCounted
## Versioned storage only. Gameplay and reward decisions belong to other classes.

const VERSION := 2
const DEFAULT_PATH := "user://player_save.json"
const MAX_BYTES := 32 * 1024 * 1024
var path: String
var state: Dictionary
var load_status := "missing"
var read_only := false
var last_error := OK

func _init(file_path: String = DEFAULT_PATH) -> void:
	path = file_path
	state = defaults()

static func defaults() -> Dictionary:
	return {"version": VERSION, "unlocked": [], "completed": {}, "sessions": {}, "dailies": {}, "active_id": "", "settings": {"reduced_motion": false, "haptics": false, "mistake_limits": false, "music_enabled": true, "sfx_enabled": true, "music_volume": 0.65, "sfx_volume": 0.8}, "ad_privacy": {"version": 1, "choice": "off"}, "hint_inventory": {"version": 1, "free_used": {}, "earned_balance": 0, "transactions": {}}}

func decode(file_path: String) -> Dictionary:
	if not FileAccess.file_exists(file_path):
		return {"ok": false, "status": "missing"}
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return {"ok": false, "status": "unreadable"}
	if file.get_length() > MAX_BYTES:
		return {"ok": false, "status": "corrupt"}
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		return {"ok": false, "status": "corrupt"}
	var raw: Variant = parser.data
	if not raw is Dictionary or not PuzzleRules.is_integer(raw.get("version")):
		return {"ok": false, "status": "corrupt"}
	if not int(raw.version) in [1, VERSION]:
		return {"ok": false, "status": "unsupported"}
	var clean := defaults()
	for field in ["completed", "sessions", "dailies", "settings"]:
		if raw.has(field) and not raw[field] is Dictionary:
			return {"ok": false, "status": "corrupt"}
	if raw.has("unlocked") and not raw.unlocked is Array:
		return {"ok": false, "status": "corrupt"}
	for id in raw.get("unlocked", []):
		if id is String and not id.is_empty() and not clean.unlocked.has(id):
			clean.unlocked.append(id)
	for id in raw.get("completed", {}):
		var reward: Variant = raw.completed[id]
		if not id is String or not reward is Dictionary:
			continue
		var valid := true
		for field in ["stars", "best_moves", "mistakes", "hints"]:
			if not PuzzleRules.is_integer(reward.get(field)) or reward[field] < 0 or reward[field] > 1000000:
				valid = false
		if valid and reward.stars >= 1 and reward.stars <= 3:
			clean.completed[id] = reward.duplicate(true)
	for field in ["sessions", "dailies"]:
		for id in raw.get(field, {}):
			if id is String and raw[field][id] is Dictionary:
				clean[field][id] = raw[field][id].duplicate(true)
	for setting in clean.settings:
		var fallback: Variant = clean.settings[setting]
		var value: Variant = raw.get("settings", {}).get(setting, fallback)
		clean.settings[setting] = (value if value is bool else fallback) if fallback is bool else PlayerPreferences.volume(value, fallback)
	clean.active_id = raw.get("active_id", "") if raw.get("active_id", "") is String else ""
	if raw.has("ad_privacy"):
		if not raw.ad_privacy is Dictionary or raw.ad_privacy.get("version") != 1:
			return {"ok": false, "status": "unsupported"}
		clean.ad_privacy.choice = "mock" if raw.ad_privacy.get("choice") == "mock" else "off"
	if raw.has("hint_inventory"):
		var wallet: Variant = raw.hint_inventory
		if not wallet is Dictionary or wallet.get("version") != 1:
			return {"ok": false, "status": "unsupported"}
		if not wallet.get("free_used") is Dictionary or not wallet.get("transactions") is Dictionary or not PuzzleRules.is_integer(wallet.get("earned_balance")) or wallet.earned_balance < 0 or wallet.earned_balance > 1000000:
			return {"ok": false, "status": "corrupt"}
		for id in wallet.free_used:
			if id is String:
				var used: Variant = wallet.free_used[id]
				clean.hint_inventory.free_used[id] = clampi(int(used), 0, 3) if PuzzleRules.is_integer(used) and used >= 0 else 3
		clean.hint_inventory.earned_balance = int(wallet.earned_balance)
		for transaction in wallet.transactions:
			if transaction is String and wallet.transactions[transaction] == true:
				clean.hint_inventory.transactions[transaction] = true
	return {"ok": true, "status": "loaded", "state": clean}

func load_file() -> Dictionary:
	read_only = false
	state = defaults()
	var primary := decode(path)
	if primary.ok:
		state = primary.state
		load_status = "loaded"
	elif primary.status == "unsupported" or primary.status == "unreadable":
		# Never overwrite a future-version file or a file we cannot inspect.
		read_only = true
		load_status = primary.status
	else:
		var backup := decode(path + ".bak")
		if backup.ok:
			state = backup.state
			load_status = "recovered"
		elif backup.status in ["unsupported", "unreadable"]:
			read_only = true
			load_status = backup.status
		else:
			load_status = primary.status
	return {"ok": load_status in ["loaded", "recovered", "missing"], "status": load_status, "read_only": read_only}

func commit() -> Error:
	if read_only:
		last_error = ERR_UNAVAILABLE
		return last_error
	var absolute := ProjectSettings.globalize_path(path)
	var directory_error := DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	if directory_error != OK:
		last_error = directory_error
		return last_error
	var text := JSON.stringify(state, "  ")
	if text.to_utf8_buffer().size() > MAX_BYTES:
		last_error = ERR_OUT_OF_MEMORY
		return last_error
	var temporary := path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		last_error = FileAccess.get_open_error()
		return last_error
	file.store_string(text)
	file.flush()
	last_error = file.get_error()
	file.close()
	if last_error != OK:
		return last_error
	if not decode(temporary).ok:
		last_error = ERR_FILE_CORRUPT
		return last_error
	var old := decode(path)
	if old.status in ["unsupported", "unreadable"]:
		read_only = true
		last_error = ERR_UNAVAILABLE
		return last_error
	if old.ok:
		last_error = DirAccess.copy_absolute(absolute, absolute + ".bak")
	elif FileAccess.file_exists(path):
		last_error = DirAccess.copy_absolute(absolute, absolute + ".corrupt")
	if last_error != OK:
		return last_error
	last_error = DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), absolute)
	return last_error
