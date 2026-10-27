class_name DevelopmentHintWallet
extends RefCounted
## Separate sandbox file. A release build never loads, credits or spends it.
var path: String
var balance := 0
var transactions: Dictionary = {}
var available := true

func _init(file_path: String) -> void:
	path = file_path
	if not OS.is_debug_build():
		available = false
		return
	if not FileAccess.file_exists(path):
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > 2 * 1024 * 1024:
		available = false
		return
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		available = false
		return
	var data: Variant = parser.data
	if not data is Dictionary or data.get("version") != 1 or not PuzzleRules.is_integer(data.get("balance")) or data.balance < 0 or data.balance > 10000 or not data.get("transactions") is Dictionary or data.transactions.size() > 10000:
		available = false
		return
	for id in data.transactions:
		if not id is String or not id.begins_with("mock:dev:") or data.transactions[id] != true:
			available = false
			return
	balance = int(data.balance)
	transactions = data.transactions.duplicate(true)

func commit() -> bool:
	if not available or not OS.is_debug_build():
		return false
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path).get_base_dir()) != OK:
		return false
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify({"version": 1, "balance": balance, "transactions": transactions}))
	file.flush()
	var error := file.get_error()
	file.close()
	return error == OK and DirAccess.rename_absolute(ProjectSettings.globalize_path(path + ".tmp"), ProjectSettings.globalize_path(path)) == OK

func credit(request_id: String, transaction_id: String) -> bool:
	if not available or not OS.is_debug_build() or not request_id.begins_with("dev:") or transaction_id != "mock:" + request_id or transactions.has(transaction_id) or transactions.size() >= 10000 or balance >= 10000:
		return false
	balance += 1
	transactions[transaction_id] = true
	if commit():
		return true
	balance -= 1
	transactions.erase(transaction_id)
	return false

func spend() -> bool:
	if not available or balance <= 0 or not OS.is_debug_build():
		return false
	balance -= 1
	if commit():
		return true
	balance += 1
	return false

func restore_spend() -> void:
	balance += 1
	if not commit():
		available = false
