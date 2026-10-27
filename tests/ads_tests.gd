extends SceneTree

class FailedOpenProvider extends MockAdProvider:
	func show_rewarded(_id: String) -> bool:
		return false

class PretendLiveProvider extends AdProvider:
	var initialized := false
	func initialize() -> void:
		initialized = true
	func is_available() -> bool:
		return true
	func verify_reward(_id: String, _receipt: Dictionary) -> bool:
		return true

var checks := 0
var failures := 0

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)
	else:
		print("PASS: ", description)

func count() -> int:
	return GameServices.hints.sandbox.balance

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	TestStorage.configure("ads")
	GameServices.initialize()
	check(GameServices.default_save_path != GameServices.RELEASE_SAVE_PATH and GameServices.default_save_path == PlayerSave.DEFAULT_PATH, "Debug and release factory profiles are separate; old debug progress stays intact")
	var progress := GameServices.progression
	var inventory := GameServices.hints
	var ads := GameServices.ads
	var provider := ads.provider as MockAdProvider
	check(provider != null and not provider.initialized, "Development factory chooses an uninitialized offline mock")
	check(not ads.prepare() and not provider.initialized, "No initialization before local opt-in")
	check(not ads.request_rewarded().ok and count() == 0, "Consent-denied request cannot grant a reward")
	var session := progress.open_session("easy_01")
	check(inventory.balance("easy_01") == 3, "Three free hints per puzzle")
	for i in range(3):
		check(inventory.use_hint(session, progress).ok, "Free hint works without any advertising")
		session.undo()
		progress.record(session)
	check(inventory.free_remaining("easy_01") == 0 and inventory.balance("easy_01") == 0, "Undo does not replenish free hints")
	session.restart()
	progress.record(session)
	check(inventory.free_remaining("easy_01") == 0, "Restart does not replenish free hints")
	check(inventory.use_hint(session, progress).get("needs_hint", false), "Exhaustion offers optional hints without applying a move")
	check(session.cycle(0, 0).ok, "No hints or ads never prevents manual play")
	check(inventory.free_remaining("easy_02") == 3, "Another garden has its own free allowance")
	progress.save.read_only = true
	# A different garden still has free quota, but cannot spend it unless its
	# action and debit can be saved in the same repository transaction.
	progress.save.state.unlocked.append("easy_02")
	var no_write := progress.open_session("easy_02")
	check(not inventory.use_hint(no_write, progress).ok and no_write.moves == 0 and inventory.free_remaining("easy_02") == 3, "Failed persistence rolls back hint placement and allowance together")
	progress.save.read_only = false
	check(GameServices.set_ad_choice("mock") and ads.prepare(), "Explicit local opt-in enables mock availability")
	var requested := ads.request_rewarded()
	check(requested.ok and ads.state == "showing" and count() == 0, "Requesting and opening do not reward")
	check(not ads.request_rewarded().ok, "Only one presentation can be active")
	var id: String = requested.request_id
	var fake := {"transaction_id": "mock:" + id, "type": "hint", "amount": 1, "simulated": true}
	provider.reward_earned.emit(id, fake)
	check(count() == 0, "Shaped but unverified reward callback is rejected")
	provider.reward_earned.emit("wrong-request", fake)
	check(count() == 0, "Unmatched callback is rejected")
	provider.finish("success")
	check(count() == 1 and ads.active_id.is_empty(), "Verified mock completion earns exactly one sandbox hint")
	provider.reward_earned.emit(id, fake)
	provider.closed.emit(id, "completed")
	check(count() == 1, "Duplicate reward/close callbacks do not duplicate hint")
	check(not inventory.credit_simulated(id, "mock:" + id) and count() == 1, "Persistent receipt ledger rejects duplicate transaction")
	check(progress.save.state.hint_inventory.earned_balance == 0 and progress.save.state.hint_inventory.transactions.is_empty(), "Mock cannot credit production balance or receipt ledger")
	var before := count()
	ads.request_rewarded()
	provider.finish("skipped")
	check(count() == before and ads.active_id.is_empty(), "Skipped ad gives no reward")
	ads.request_rewarded()
	provider.finish("failed")
	check(count() == before and ads.active_id.is_empty(), "Failed ad gives no reward")
	provider.available = false
	check(not ads.prepare() and not ads.request_rewarded().ok and count() == before, "Unavailable ad leaves balance unchanged")
	provider.available = true
	ads.prepare()
	requested = ads.request_rewarded()
	id = requested.request_id
	provider.opened.emit(id)
	check(count() == before, "Duplicate open event cannot reward")
	ads.set_application_suspended(true)
	check(not ads.request_rewarded().ok, "No new ad request while suspended")
	provider.finish("success")
	check(count() == before and not ads.pending_receipt.is_empty(), "Verified callback during suspension is queued, not fabricated from resume")
	ads.tick(10000)
	check(not ads.active_id.is_empty(), "Background time does not time out a verified pending callback")
	ads.set_application_suspended(false)
	check(count() == before + 1 and ads.active_id.is_empty(), "Returning processes verified callback exactly once")
	ads.set_application_suspended(false)
	check(count() == before + 1, "Duplicate resume does not duplicate reward")
	before = count()
	ads.request_rewarded()
	ads.set_application_suspended(true)
	ads.set_application_suspended(false)
	check(count() == before, "Suspending/resuming without earned callback never rewards")
	ads.cancel()
	check(count() == before and ads.active_id.is_empty(), "Cancellation never invents reward")
	ads.request_rewarded()
	ads.set_application_suspended(true)
	provider.finish("skipped")
	ads.set_application_suspended(false)
	check(count() == before, "Skipped ad during suspension gives no reward on resume")
	requested = ads.request_rewarded()
	id = requested.request_id
	provider.closed.emit(id, "closed")
	check(ads.state == "awaiting_reward" and count() == before, "Dismiss without reward waits without credit")
	provider.finish("success")
	check(count() == before + 1, "Verified callback after generic dismiss can settle once")
	before = count()
	requested = ads.request_rewarded()
	id = requested.request_id
	provider.closed.emit(id, "closed")
	ads.tick(31)
	provider.finish("success")
	check(count() == before and ads.active_id.is_empty(), "Timed-out request rejects late callbacks")
	ads.request_rewarded()
	ads.tick(181)
	check(count() == before and ads.active_id.is_empty(), "Stalled display times out with no reward")
	requested = ads.request_rewarded()
	id = requested.request_id
	GameServices.set_ad_choice("off")
	provider.reward_earned.emit(id, fake)
	check(count() == before and not ads.is_available(), "Revoking opt-in cancels active request and rejects stale callbacks")
	check(inventory.sandbox.transactions.size() == before, "Each sandbox credit has one unique durable receipt")
	GameServices.set_ad_choice("mock")
	progress.save.read_only = true
	check(not GameServices.set_ad_choice("off") and not ads.consent.development_allowed and progress.save.state.ad_privacy.choice == "off", "Privacy withdrawal takes effect even if preference save fails")
	progress.save.read_only = false
	progress.persist()
	GameServices.set_ad_choice("mock")
	ads.prepare()
	ads.request_rewarded()
	ads.set_application_suspended(true)
	provider.finish("success")
	GameServices.set_ad_choice("off")
	check(count() == before and not ads.pending_receipt.is_empty(), "Withdrawal retains a reward already verified before the choice changed")
	ads.set_application_suspended(false)
	before += 1
	check(count() == before and ads.active_id.is_empty(), "Already-verified reward settles once despite later opt-out")
	var same_wallet := DevelopmentHintWallet.new(progress.save.path + ".ad_sandbox")
	check(same_wallet.balance == before and not same_wallet.credit(String(same_wallet.transactions.keys()[0]).trim_prefix("mock:"), str(same_wallet.transactions.keys()[0])), "Reloading sandbox retains balance and duplicate protection")
	var production_inventory := HintInventory.new(progress.save, false)
	check(not production_inventory.credit_simulated("dev:fake", "mock:dev:fake"), "Release-mode inventory refuses all simulated credits")
	check(production_inventory.balance("easy_01") == 0, "Production-mode inventory never loads mock credits")
	var release_mock := MockAdProvider.new()
	var allowed := AdConsentGate.new()
	allowed.development_allowed = true
	var release_service := AdService.new(release_mock, production_inventory, allowed, false)
	check(not release_service.prepare() and not release_service.request_rewarded().ok and not release_mock.initialized, "Development provider cannot run in release-mode service")
	release_service.dispose()
	var live := PretendLiveProvider.new()
	var live_gate := AdConsentGate.new()
	live_gate.audience = "adult"
	live_gate.cmp_refreshed = true
	live_gate.cmp_can_request = true
	var live_service := AdService.new(live, production_inventory, live_gate, true)
	check(not live_service.prepare() and not live.initialized, "Live SDK initialization is fail-closed even with claimed consent")
	live_service.active_id = "live:spoof"
	live_service.state = "showing"
	live_service.on_reward("live:spoof", {"type": "hint", "amount": 1, "transaction_id": "fake-live", "simulated": false})
	check(progress.save.state.hint_inventory.earned_balance == 0, "Forged live provider cannot mint production rewards in development")
	live_service.dispose()
	var failing := FailedOpenProvider.new()
	var failure_service := AdService.new(failing, inventory, allowed, true)
	check(failure_service.prepare() and not failure_service.request_rewarded().ok and count() == before, "Failure to open is not rewarded")
	failure_service.dispose()
	progress.save.state.hint_inventory.earned_balance = 4
	check(inventory.balance("easy_01") == before, "Debug inventory does not spend or expose a live balance")
	session.restart()
	check(inventory.use_hint(session, progress).ok and count() == before - 1 and progress.save.state.hint_inventory.earned_balance == 4, "Spending a simulated hint changes sandbox only, not production bank")
	progress.save.state.hint_inventory.earned_balance = 0
	progress.persist()
	var saved_board := session.board.duplicate(true)
	var saved_balance := inventory.balance("easy_01")
	GameServices.initialize()
	check(GameServices.hints.balance("easy_01") == saved_balance and GameServices.hints.free_remaining("easy_01") == 0, "Inventory/allowance persist across service restart")
	check(GameServices.progression.open_session("easy_01").board == saved_board, "Hint spending and board survive reloading")
	var reloaded := GameServices.ads.provider as MockAdProvider
	check(not reloaded.initialized and GameServices.ads.active_id.is_empty(), "Relaunch does not resurrect ad presentation or grant pending rewards")
	var unavailable_wallet := HintInventory.new(GameServices.progression.save, true)
	unavailable_wallet.sandbox.available = false
	var ready_mock := MockAdProvider.new()
	var blocked_wallet := AdService.new(ready_mock, unavailable_wallet, allowed, true)
	check(not blocked_wallet.prepare() and not blocked_wallet.request_rewarded().ok, "Cannot show a test ad when its reward wallet is unavailable")
	blocked_wallet.dispose()
	# Migrate previous saves without erasing progress/settings or inventing credits.
	var old := PlayerSave.defaults()
	old.version = 1
	old.erase("hint_inventory")
	old.erase("ad_privacy")
	old.unlocked = ["easy_01", "easy_02"]
	old.settings.reduced_motion = true
	old.sessions = {"easy_01": GameServices.progression.open_session("easy_01").snapshot()}
	old.completed = {"easy_01": {"stars": 2, "best_moves": 5, "mistakes": 0, "hints": 1}}
	var migration_path := GameServices.save_path + ".migration"
	var file := FileAccess.open(migration_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(old))
	file.close()
	var migrated := PlayerSave.new(migration_path)
	check(migrated.load_file().ok and migrated.state.version == 2 and migrated.state.unlocked.size() == 2 and migrated.state.settings.reduced_motion and migrated.state.hint_inventory.earned_balance == 0, "Version 1 migrates to version 2 without losing progress or minting credits")
	var migrated_progress := ProgressionService.new(GameServices.progression.catalog, migrated)
	check(migrated_progress.open_session("easy_01").board == saved_board and migrated_progress.total_stars() == 2, "Migration preserves existing boards, undo snapshots and completion stars")
	var future_wallet := PlayerSave.defaults()
	future_wallet.hint_inventory.version = 999
	file = FileAccess.open(migration_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(future_wallet))
	file.close()
	check(migrated.load_file().read_only, "Unknown future inventory version is preserved without overwriting")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(migration_path))
	var corrupt_wallet_path := GameServices.save_path + ".bad_sandbox"
	file = FileAccess.open(corrupt_wallet_path, FileAccess.WRITE)
	file.store_string("not-json")
	file.close()
	var corrupt_wallet := DevelopmentHintWallet.new(corrupt_wallet_path)
	check(not corrupt_wallet.available and not corrupt_wallet.credit("dev:fake", "mock:dev:fake"), "Corrupt sandbox fails closed instead of clearing duplicate history")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(corrupt_wallet_path))
	TestStorage.cleanup()
	print("RESULT: %d rewarded-ad/inventory checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
