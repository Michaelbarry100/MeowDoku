class_name AdConsentGate
extends RefCounted
## Local mock opt-in is NOT a substitute for a certified production CMP/UMP.
const POLICY_VERSION := 1
const PRODUCTION_ADS_ENABLED := false
var development_allowed := false
var audience := "unknown"
var cmp_can_request := false
var cmp_refreshed := false

func may_initialize(provider: AdProvider, development: bool) -> bool:
	if provider.is_simulated():
		return development and OS.is_debug_build() and development_allowed
	# No child/unknown-age real advertising in this version. No personalized mode.
	return PRODUCTION_ADS_ENABLED and not OS.is_debug_build() and audience == "adult" and cmp_refreshed and cmp_can_request

func production_block_reason() -> String:
	return "Real ads are not configured. A reviewed native consent adapter and audience safeguards are required before SDK initialization."
