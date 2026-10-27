class_name HintInventory
extends RefCounted
## Allowance and inventory only. It never requests or displays advertisements.
const FREE_PER_PUZZLE := 3
var repository: PlayerSave
var sandbox: DevelopmentHintWallet
var development := false

func _init(save: PlayerSave, allow_development: bool = false) -> void:
	repository = save
	development = allow_development and OS.is_debug_build()
	if development:
		sandbox = DevelopmentHintWallet.new(save.path + ".ad_sandbox")

func free_remaining(puzzle_id: String) -> int:
	return maxi(0, FREE_PER_PUZZLE - int(repository.state.hint_inventory.free_used.get(puzzle_id, 0)))

func balance(puzzle_id: String) -> int:
	var extra := 0 if development else int(repository.state.hint_inventory.earned_balance)
	if development and sandbox != null and sandbox.available:
		extra += sandbox.balance
	return free_remaining(puzzle_id) + extra

func credit_simulated(request_id: String, transaction_id: String) -> bool:
	return development and sandbox != null and sandbox.credit(request_id, transaction_id)

func use_hint(session: PuzzleSession, progress: ProgressionService) -> Dictionary:
	var possible := session.next_hint()
	if not possible.ok:
		return possible
	var id: String = str(session.puzzle.id)
	var source := "free"
	if free_remaining(id) <= 0:
		if not development and int(repository.state.hint_inventory.earned_balance) > 0:
			source = "earned"
		elif development and sandbox != null and sandbox.available and sandbox.balance > 0:
			source = "sandbox"
		else:
			return {"ok": false, "needs_hint": true, "message": "No hints left for this garden. Keep playing, or choose an optional extra hint."}
	var previous_state := repository.state.duplicate(true)
	var previous_session := session.snapshot()
	var previous_message := session.last_message
	if source == "sandbox" and not sandbox.spend():
		return {"ok": false, "message": "Could not save the test hint. Nothing was spent."}
	if source == "free":
		repository.state.hint_inventory.free_used[id] = int(repository.state.hint_inventory.free_used.get(id, 0)) + 1
	elif source == "earned":
		repository.state.hint_inventory.earned_balance -= 1
	var applied := session.use_hint()
	var recorded: Dictionary = progress.record(session) if applied.ok else {"ok": false}
	if applied.ok and recorded.ok:
		applied["source"] = source
		return applied
	# For production balances/free quotas the board, ledger and debit share one
	# save write. Mock credits deliberately live outside that production file.
	repository.state = previous_state
	session.restore(previous_session)
	session.last_message = previous_message
	if source == "sandbox":
		sandbox.restore_spend()
	return {"ok": false, "message": "Could not save this hint. Your board and hint allowance were kept."}
