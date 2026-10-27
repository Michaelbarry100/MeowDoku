class_name MockAdProvider
extends AdProvider
## Offline development transport. Completing the simulator is NOT a real ad.
var available := true
var initialized := false
var active_id := ""
var successful_receipts: Dictionary = {}

func is_simulated() -> bool:
	return true

func initialize() -> void:
	initialized = true

func load_rewarded() -> void:
	availability_changed.emit(is_available())

func is_available() -> bool:
	return initialized and available and active_id.is_empty()

func show_rewarded(request_id: String) -> bool:
	if not is_available():
		return false
	active_id = request_id
	availability_changed.emit(false)
	opened.emit(request_id)
	return true

func finish(outcome: String) -> void:
	if active_id.is_empty():
		return
	var id := active_id
	active_id = ""
	match outcome:
		"success":
			var receipt := {"transaction_id": "mock:" + id, "type": "hint", "amount": 1, "simulated": true}
			successful_receipts[id] = receipt.duplicate(true)
			reward_earned.emit(id, receipt)
			closed.emit(id, "completed")
		"failed": failed.emit(id, "Simulated display failure. No hint earned.")
		_: closed.emit(id, "skipped")
	availability_changed.emit(is_available())

func verify_reward(request_id: String, receipt: Dictionary) -> bool:
	return successful_receipts.has(request_id) and successful_receipts[request_id] == receipt and receipt.get("simulated") == true and receipt.get("amount") == 1 and receipt.get("type") == "hint"

func cancel(request_id: String) -> void:
	if active_id == request_id:
		active_id = ""
	availability_changed.emit(is_available())
