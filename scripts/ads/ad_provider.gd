class_name AdProvider
extends RefCounted
## Native adapters must normalize SDK callbacks into this contract. No IDs here.
signal availability_changed(ready: bool)
signal opened(request_id: String)
signal reward_earned(request_id: String, receipt: Dictionary)
signal closed(request_id: String, outcome: String)
signal failed(request_id: String, reason: String)

func is_simulated() -> bool:
	return false

func initialize() -> void:
	pass

func load_rewarded() -> void:
	availability_changed.emit(false)

func is_available() -> bool:
	return false

func show_rewarded(_request_id: String) -> bool:
	return false

func verify_reward(_request_id: String, _receipt: Dictionary) -> bool:
	# Base/disabled provider can never verify a reward.
	return false

func cancel(_request_id: String) -> void:
	pass
