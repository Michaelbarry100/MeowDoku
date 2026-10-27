# Optional rewarded hints: architecture and integration plan

Reviewed **26 October 2026**. This project currently contains an offline mock,
not a real advertising SDK. Nothing in this document certifies a store submission
or authorizes enabling real ads without the device and privacy work below.

## What works now

- All puzzles remain free to play. Each campaign puzzle and each dated daily has
  **three free hints**, tracked independently from the attempt's scoring counter.
- Undo/restart do not refill this allowance. Switching screens or reopening the
  app retains it. Another puzzle has its own allowance.
- **Hint (N)** spends a hint only when the player requests a valid next move.
  **+ Hint** opens optional choices; it does not show an ad automatically.
- If unavailable, declined, skipped, cancelled, failed or timed out, ads grant
  nothing and the player can choose **Keep playing**. No existing hint is spent
  by requesting or showing an ad. There is no forced interstitial, banner, app-open
  ad or rewarded interstitial.
- In a debug build, Privacy & optional ads offers an explicitly labeled **local
  simulation**. Its screen hides the board completely. Complete/Skip/Fail controls
  are simulation controls, not a real video or paid advertiser.
- A verified completion credits **one** development hint. It is banked rather than
  automatically applied to the puzzle. The player taps Hint to spend it.
- Release builds select the disabled base provider, cannot load the sandbox, and
  cannot initialize a live SDK. They retain free hints and ordinary gameplay.

Google's reward policy calls for clear optional participation and a usable
non-rewarded path; hints here have no cash value or transferability. The UI names
the reward before the player chooses a presentation. [Rewarded-ad policy](https://support.google.com/admob/answer/7313578?hl=en)

## Components and trust boundaries

| Component | Responsibility |
| --- | --- |
| `AdProvider` | Adapter contract: availability, display, earned/open/close/failure events, cancellation and receipt verification. Base implementation is disabled. |
| `MockAdProvider` | Offline adapter that issues a receipt only after explicit successful simulation; available only to debug composition. |
| `AdConsentGate` | Prevent initialization before permission. Production ads remain compiled off; adult audience/CMP checks alone cannot turn them on. |
| `AdService` | Correlate an active random request token with a verified reward; lifecycle, de-duplication, timeouts and suspension. |
| `HintInventory` | Per-puzzle free quota and hint spending. It never loads or displays ads. |
| `DevelopmentHintWallet` | Separate, versioned mock balance and durable receipt ledger; never read/spent/credited in a release build. |
| `PlayerSave` | Version 2 migration, local free quota and future live-balance fields, alongside existing progress/settings. |
| `rewarded_hint_page.gd` | Optional choices and development simulation presentation; no direct currency-granting code. |

Normal flow:

```text
Player chooses + Hint → explicit privacy choice → availability check
→ random request token → provider opened (NO REWARD)
→ provider earned callback → verify token/receipt/type/amount/source
→ persistent unique receipt + one sandbox credit
→ player returns to unchanged board → player chooses Hint to spend
```

Only an active request in showing/awaiting-reward state accepts a receipt. The
provider must verify it against its own earned-callback state, not a caller's
`success=true` flag. Request/open/dismiss/resume are never reward evidence.
Duplicate signals are rejected in memory, and a durable transaction ledger rejects
the same mock receipt after relaunch. A generic dismiss leaves a 30-second earned
callback window; explicit skip/cancel/failure is terminal. Stalled foreground
presentations time out after 180 seconds. Background time does not advance them.

Verified callbacks received while backgrounded are queued and processed once on
return. The app does not put its pause menu over the ad screen. A process kill
before a queued callback is committed deliberately does not manufacture a credit
on relaunch. Production reconciliation after termination is part of the future
native/server-verification integration, not claimed by this mock.

The primary save is now **version 2**, accepting and migrating version 1 with
progress, stars and settings intact. New sections are `ad_privacy` (versioned local
choice) and `hint_inventory` (versioned `free_used`, `earned_balance`,
`transactions`). The live balance stays zero in this implementation. Unknown
inventory versions are read-only instead of being overwritten.

Mock receipts and balances are written to `<save path>.ad_sandbox`, outside the
production save. Debug hints never increase/decrease its live balance or live
receipt ledger. In addition, debug play retains the existing `player_save.json`
profile while release exports use `release_player_save.json`, with no automatic
debug import. Even campaign stars/unlocks earned during mock testing cannot leak
into the default release profile. Normal hint actions and their free/live debit share a primary
save write; failures roll back the action and debit. The mock wallet uses a
separate file, so a process failure between two sandbox-related writes can lose
a development test credit; this is not a live-currency transaction guarantee.
A corrupt sandbox disables new test rewards rather than resetting its ledger.

This is callback de-duplication and source isolation, not anti-tamper protection
against edited local files or modified client code. A real signed verification
system cannot be replaced by a GDScript boolean or a secret embedded in the app.

## Current SDK candidate: researched, not installed

**Poing Studios Godot AdMob Plugin v5.1.0** is the candidate. Its documentation
explicitly supports Godot **4.5+**, Android and iOS. The release notes mention
testing through 4.7.2, and its assets include matching Godot 4.5.1 platform
templates. This covers the project's verified 4.5.1 runtime; the existing 4.7
editor feature stamp is preserved. It has rewarded-ad and UMP interfaces.
[Repository](https://github.com/poingstudios/godot-admob-plugin),
[pinned release](https://github.com/poingstudios/godot-admob-plugin/releases/tag/v5.1.0)

The plugin is a **third-party wrapper**, not Google's official Godot SDK or a
promise of Google support for the wrapper. Google lists it among alternative
platform libraries. [Google's Godot library listing](https://developers.google.com/admob/other-platforms)

The published setup lists Android min SDK 24 / compile SDK 35+, and iOS deployment
15+ with Xcode 15+. These are plugin minimums, not current store submission
requirements. Native versions listed during this review were Android GMA
Next-Gen 1.4.0, iOS GoogleMobileAds 13.9.0 and iOS UMP 3.1.0. Pin and audit the
actual resolved dependency graph before release; do not mix old v3/v4 wrappers
with v5 APIs. [Plugin setup](https://poingstudios.github.io/godot-admob-plugin/stable/)

### Android installation/export plan

1. Work in a reviewed integration branch; pin v5.1.0 and retain its license and
   dependency hashes. Import the plugin and enable it only after auditing its
   automatic SDK initialization/download behavior against the consent gate.
2. Install the matching Godot Android build template and the plugin's matching
   Android binaries; use its Android download manager if automatic acquisition
   fails. Enable the Android platform and use Gradle export.
3. Supply publisher application/ad-unit identifiers from local build/CI
   configuration after registration. They are intentionally absent here. Use
   Google's test units/devices for all native development, never live traffic.
4. Inspect the merged manifest and remove unnecessary permissions/identifiers;
   assess `AD_ID` collection and avoid location/contact/storage permissions for
   advertising. Audit every mediation dependency; begin without mediation.
5. Use compatible SDK/JDK/Gradle tools, signing and an Android App Bundle. For
   this review date, Play requires new phone apps/updates to target API **36+**,
   effective 31 August 2026. Compile against a compatible SDK, not merely the
   plugin's lower documented floor. [Play target policy](https://support.google.com/googleplay/android-developer/answer/11926878?hl=en-en)
6. Test R8/minified release exports on physical devices; v5.1 includes consumer
   keep rules, but inspect callback behavior in the final artifact.
   [R8 integration guide](https://poingstudios.github.io/godot-admob-plugin/stable/android_r8_obfuscation/)

### iOS installation/export plan

1. Use macOS, matching Godot iOS templates and plugin iOS binaries, an Apple
   developer team and signing. Enable the plugin's iOS export configuration.
2. Build with an accepted current Xcode/SDK. Apple has required Xcode 26+/iOS
   26 SDK+ for submissions since 28 April 2026; the plugin's older minimum does
   not satisfy that rule by itself. [Apple SDK requirements](https://developer.apple.com/news/upcoming-requirements/)
3. Review generated Info.plist application ID and any current SKAdNetwork entries,
   native dependency linking, embedded manifests and framework signatures.
   Do not add ATT purpose text or request IDFA just because an ad plugin exists.
   [Google iOS privacy strategies](https://developers.google.com/admob/ios/privacy/strategies?authuser=00)
4. Explicitly test native full-screen pause/foreground behavior: the plugin
   documents Android automatic pause and an iOS pause-on-background setting.
   Drain verified callbacks once, without showing a second pause overlay or
   awarding on resume. [iOS pause guide](https://poingstudios.github.io/godot-admob-plugin/stable/ios_pause_background/)
5. Test both debug/test-unit builds and a signed release/TestFlight build on
   physical devices. Simulator success is not native advertising sign-off.

### Future native adapter contract

Wrap plugin APIs inside a new `AdProvider`; do not import plugin objects into the
puzzle/session/inventory scripts. The candidate exposes
`OnUserEarnedRewardListener.on_user_earned_reward`; map that earned event to the
reward contract, not the full-screen-open/impression/dismiss callbacks. Dispose
loaded ad objects after use. [Plugin rewarded API](https://poingstudios.github.io/godot-admob-plugin/stable/ad_formats/rewarded/)

Before enabling a live grant path, correlate one presentation with one opaque
request nonce, validate the configured reward type/amount, marshal native
callbacks safely, and exercise duplicate/late/error ordering on both platforms.
For cryptographic reward assurance, implement server-side verification, verify
the provider signature and unique transaction, and reconcile outstanding earned
rewards after process termination. A minimal anonymous transaction service can
remain optional to ads; the puzzle itself must continue offline without accounts.
SDK reward listeners alone are not a cryptographic SSV implementation.
[Google Android rewarded flow](https://developers.google.com/admob/android/rewarded),
[Google iOS rewarded flow](https://developers.google.com/admob/ios/rewarded)

The present `PRODUCTION_ADS_ENABLED = false` gate and lack of a live-credit handler
are intentional. Replacing the provider class alone must **not** enable real
ads or live rewards. Add the consent adapter, live receipt path, declarations and
device tests together as a reviewed change.

## Privacy, consent and audience release review

### This mock build

No advertising/analytics SDK is linked, no network ad requests are made, no
advertising ID/IDFA, age, birthdate, location, contact information or account is
requested. Progress, hint quotas, privacy choice and random mock transaction
tokens stay locally on the device. The Settings → Privacy & optional ads page
explains this and offers equally accessible Off and development opt-in choices.
Withdrawal cancels requests immediately, even if saving the preference fails;
the UI explains a session-only choice if it could not be persisted.
An earned callback already verified before withdrawal is retained for one-time
settlement; withdrawal cannot trigger a new reward or forfeit an accepted one.

Local-only processing is outside Play's definition of data transmitted/collected,
but the developer still completes the Data safety form and supplies a privacy
policy. Real SDK behavior must be reflected separately.
[Play Data safety guidance](https://support.google.com/googleplay/android-developer/answer/10787469?hl=en-en)

### Before any real SDK initialization or request

Use a native UMP/CMP adapter, refresh consent information at launch, present
required regional forms, and consult `canRequestAds` before requesting. Make
privacy options/revocation available from Settings when required. A network/CMP
failure must leave ads disabled and the game usable; do not infer consent from
the mock choice or a successful ad request. Validate EEA/UK/Swiss and applicable
US-state messaging/opt-out behavior using native test geography.
[Android UMP](https://developers.google.com/admob/android/privacy),
[iOS UMP](https://developers.google.com/admob/ios/privacy)

This local simulator permission is **not** a legally operative UMP consent form.
There is no production CMP implementation in this version, so real SDK activity
is blocked rather than collecting data before consent. The target audience and
distribution territories still need to be selected by the publisher.

No personalized-ad mode is implemented or planned as a default. On iOS, ATT
permission is needed for tracking/IDFA access as defined by Apple; declining it
must not reduce core gameplay. Avoid cross-app tracking, IDFA and fingerprinting,
and verify any first-party ID defaults instead of assuming a non-personalized
flag eliminates data processing. [Apple tracking/privacy rules](https://developer.apple.com/app-store/user-privacy-and-data-use/)

### Children and unknown audience

The production gate defaults to **unknown audience** and blocks real advertising
for children and unknown-age users. The cute art is not evidence that the app is
adult-only. No DOB is collected or “I am an adult” shortcut used here. If choosing
a mixed-audience release, implement a neutral, legally reviewed age approach and
keep children/unknown users on the ad-free route until safeguards are complete.

Google Families requires appropriate certified SDK versions and excludes
personalized/interest-based ads and remarketing for children or unknown-age
users. Do not enable child-directed targeting merely by flipping a flag; review
age-appropriate creatives, formats, all mediated SDKs and applicable child
privacy obligations first. [Google Play Families](https://support.google.com/googleplay/android-developer/answer/9893335?hl=en)

Apple's Kids Category generally excludes third-party ads/analytics, with limited
contextual-ad exceptions requiring documented safeguards such as human creative
review. A parental gate is not equivalent to legal parental consent. For this
version, keep that route ad-free. General ads must also be age appropriate and
provide suitable reporting/close behavior. [Apple guidelines, 1.3, 2.5.18 and 5.1](https://developer.apple.com/app-store/review/guidelines/)

### Disclosures and manifests

- **Google Play:** declare real ads in App content, complete target-audience and
  rating questions, and publish an accessible policy describing actual SDK
  collection/sharing, retention, choices and contact details. Do not label the
  future SDK-enabled build as collecting nothing because the game has no account.
  [Play declarations](https://support.google.com/googleplay/android-developer/answer/9859455?hl=en)
- The candidate's Android GMA Next-Gen SDK can transmit IP address, interactions,
  diagnostics and device/account identifiers. Review precisely which are enabled
  and complete Data safety for that configuration and every SDK/adapter.
  [GMA Next-Gen disclosure](https://developers.google.com/admob/android/next-gen/privacy/play-data-disclosure?hl=en)
- **Apple:** App Privacy labels must reflect the entire app plus SDK behavior.
  Google's SDK disclosure lists possible IP, device, diagnostic and ad-interaction
  data; non-personalized serving does not mean no collection.
  [Google iOS disclosure](https://developers.google.com/admob/ios/privacy/data-disclosure)
- Include and validate each applicable `PrivacyInfo.xcprivacy` and required-reason
  API declarations in the final archive. Audit the Godot template/app's own API
  use separately from SDK manifests. Generate Xcode's aggregate privacy report;
  do not fabricate an empty “no data” manifest before inspecting the real build.
  [Apple manifest documentation](https://developer.apple.com/documentation/bundleresources/privacy-manifest-files?language=_6)
- Check Apple's listed SDK manifest/signature requirements, including repackaged
  dependencies, and preserve signed SDK resources. GoogleMobileAds not appearing
  by name on a list is not proof that every transitive dependency is exempt.
  [Apple SDK requirements](https://developer.apple.com/support/third-party-SDK-requirements/)

No real SDK or app-specific privacy manifest is added now, so this repository
does not pretend its future native export/declarations have been audited. Host
the final app-specific privacy policy at a real public URL and add publisher
contact information before store submission; no invented policy URL is embedded.

## Tests and production status

```powershell
& $engine --headless --editor --path . --import --quit
& $engine --headless --path . --script res://tests/ads_tests.gd
& $engine --path . --script res://tests/ads_ui_tests.gd -- --capture
```

The unit suite covers earned/skipped/unavailable/failed outcomes, invalid receipts,
duplicate callbacks, late callbacks, cancellation, consent revocation, suspension,
timeouts, restart persistence, free quotas, isolated development credits, storage
failure rollback and save migration. UI tests cover the whole optional flow and
small-phone controls. Captures are in `artifacts/ads/`.

**Implemented and tested:** offline free hints, abstraction/state machine, mock
verification/de-duplication, local privacy choice, save migration and UI safety.
**Simulated:** advertising availability/presentation, earned callback and test
currency. **Not production-ready:** native ads, real network verification, UMP,
SSV/reconciliation, child-audience approval, signed mobile exports and store
declarations. Keep the mock until those are tested on supported devices.
