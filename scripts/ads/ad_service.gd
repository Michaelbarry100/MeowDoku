class_name AdService
extends RefCounted
## Request/display/reward state machine. Receipts, never requests, mint credits.
signal changed
signal presentation_changed(visible: bool)
signal result_ready(message: String, rewarded: bool)

const CALLBACK_TIMEOUT := 30.0
const DISPLAY_TIMEOUT := 180.0
var provider: AdProvider
var inventory: HintInventory
var consent: AdConsentGate
var development := false
var active_id := ""
var state := "idle"
var app_suspended := false
var pending_receipt: Dictionary = {}
var credited := false
var display_closed := false
var elapsed := 0.0
var last_message := "Optional ads are off. Free hints and normal play are available."
var initialized := false
var disposed := false

func _init(adapter: AdProvider, hints: HintInventory, gate: AdConsentGate, allow_development: bool = false) -> void:
	provider = adapter
	inventory = hints
	consent = gate
	development = allow_development and OS.is_debug_build()
	provider.availability_changed.connect(on_availability)
	provider.opened.connect(on_opened)
	provider.reward_earned.connect(on_reward)
	provider.closed.connect(on_closed)
	provider.failed.connect(on_failed)

func on_availability(_ready: bool) -> void:
	changed.emit()

func prepare() -> bool:
	if not consent.may_initialize(provider, development):
		last_message = "Local ad tests are off. You can keep playing." if provider.is_simulated() else consent.production_block_reason()
		changed.emit()
		return false
	if not initialized:
		provider.initialize()
		initialized = true
	provider.load_rewarded()
	last_message = "Local test ad ready. No network or real advertiser." if is_available() else "Ad unavailable. Your puzzle remains playable."
	changed.emit()
	return is_available()

func is_available() -> bool:
	var wallet_ready := not inventory.repository.read_only and (not development or (inventory.sandbox != null and inventory.sandbox.available and inventory.sandbox.balance < 10000 and inventory.sandbox.transactions.size() < 10000))
	return not disposed and wallet_ready and active_id.is_empty() and not app_suspended and initialized and consent.may_initialize(provider, development) and provider.is_available()

func request_rewarded() -> Dictionary:
	if not is_available():
		last_message = "Ad unavailable. No hint was spent; keep playing normally."
		return {"ok": false, "message": last_message}
	active_id = ("dev:" if development else "live:") + Crypto.new().generate_random_bytes(16).hex_encode()
	pending_receipt.clear()
	credited = false
	display_closed = false
	elapsed = 0.0
	state = "requested"
	var id := active_id
	if not provider.show_rewarded(id):
		on_failed(id, "Ad could not open. No reward earned.")
		return {"ok": false, "message": last_message}
	changed.emit()
	return {"ok": true, "request_id": id}

func on_opened(id: String) -> void:
	if id != active_id or state != "requested":
		return
	state = "showing"
	presentation_changed.emit(true)
	changed.emit()

func on_reward(id: String, receipt: Dictionary) -> void:
	if id.is_empty() or id != active_id or credited or not state in ["showing", "awaiting_reward"] or not consent.may_initialize(provider, development):
		return
	if not provider.verify_reward(id, receipt) or receipt.get("type") != "hint" or receipt.get("amount") != 1 or not receipt.get("transaction_id") is String:
		return
	# This implementation has no live adapter. Even a forged non-mock provider
	# cannot mint production credits; debug credits only go to the sandbox.
	if not development or not provider.is_simulated() or receipt.get("simulated") != true:
		return
	pending_receipt = receipt.duplicate(true)
	if not app_suspended:
		commit_verified_reward()

func commit_verified_reward() -> void:
	if pending_receipt.is_empty() or credited or active_id.is_empty():
		return
	credited = inventory.credit_simulated(active_id, str(pending_receipt.transaction_id))
	last_message = "Simulation complete: 1 test hint added." if credited else "Test hint was already recorded or could not be saved. No new credit added."
	pending_receipt.clear()
	result_ready.emit(last_message, credited)
	changed.emit()
	if display_closed:
		finish_request()

func on_closed(id: String, outcome: String) -> void:
	if id.is_empty() or id != active_id:
		return
	display_closed = true
	presentation_changed.emit(false)
	if credited:
		finish_request()
	elif not pending_receipt.is_empty():
		if not app_suspended:
			commit_verified_reward()
	elif outcome == "closed":
		# Real adapters may deliver the earned callback after dismiss. Keep a
		# bounded callback window, without keeping the board locked.
		state = "awaiting_reward"
		elapsed = 0
	else:
		last_message = "Test ad skipped. No hint earned; your puzzle is unchanged."
		result_ready.emit(last_message, false)
		finish_request()

func on_failed(id: String, reason: String) -> void:
	if id.is_empty() or id != active_id:
		return
	if not pending_receipt.is_empty() and app_suspended:
		display_closed = true
		presentation_changed.emit(false)
		return # Retain an already-verified callback until foreground processing.
	# A real successful callback already committed must not be clawed back by
	# a subsequent dismissal error. A failure alone can never create a reward.
	last_message = reason if not credited else "The earned test hint was kept."
	result_ready.emit(last_message, credited)
	presentation_changed.emit(false)
	finish_request()

func finish_request() -> void:
	provider.cancel(active_id)
	active_id = ""
	state = "idle"
	pending_receipt.clear()
	elapsed = 0
	changed.emit()

func cancel() -> void:
	if active_id.is_empty():
		return
	last_message = "Test ad cancelled. No unverified reward was added."
	presentation_changed.emit(false)
	finish_request()

func set_application_suspended(paused: bool) -> void:
	app_suspended = paused
	if not paused and not pending_receipt.is_empty():
		commit_verified_reward()
	changed.emit()

func tick(delta: float) -> void:
	if active_id.is_empty() or app_suspended:
		return
	elapsed += maxf(0, delta)
	if elapsed >= (CALLBACK_TIMEOUT if state == "awaiting_reward" else DISPLAY_TIMEOUT):
		on_failed(active_id, "Ad timed out. No unverified reward added; keep playing normally.")

func revoke_permission() -> void:
	consent.development_allowed = false
	if not pending_receipt.is_empty():
		# Withdrawal blocks new processing, but does not forfeit a receipt that
		# was already verified while permission was valid.
		display_closed = true
		provider.cancel(active_id)
		presentation_changed.emit(false)
		if not app_suspended:
			commit_verified_reward()
	else:
		cancel()
	last_message = "Optional ad tests are off. Your earned hints are kept."
	changed.emit()

func dispose() -> void:
	if disposed:
		return
	cancel()
	provider.availability_changed.disconnect(on_availability)
	provider.opened.disconnect(on_opened)
	provider.reward_earned.disconnect(on_reward)
	provider.closed.disconnect(on_closed)
	provider.failed.disconnect(on_failed)
	disposed = true
