# AlarmKit findings

**Status: EMPTY — awaiting the physical-device session.**

Nothing in this file is confirmed until it is filled in from a real iPhone. Until
then, Phase 0 is not complete and Phase 1 does not start.

Test numbers refer to `00-phase0-spike.md`. Fill in *every* row, including honest
"not achievable" answers.

---

## Environment

| | |
|---|---|
| Date of session | |
| iPhone model | |
| iOS version | |
| Xcode version | |
| Signing | Free Personal Team |

---

## Results

| # | Question | Result | Notes |
|---|---|---|---|
| 1 | Does authorization succeed? What does a revoked state look like? | unknown | |
| 2 | Does an alarm fire with the app closed and phone locked? | unknown | |
| 3 | Do custom sounds play? | unknown | |
| 3b | **Does the sound loop until Stop, or auto-dismiss?** | unknown | If it auto-stops, how long did it ring? |
| 4 | **Maximum concurrently scheduled alarms** | unknown | Highest successful count + exact error text |
| 4b | Does that clear the real-morning requirement? | unknown | App displays the required number |
| 5 | **Does Stop on alarm #1 leave #2 scheduled?** | unknown | The whole design rests on this |
| 6 | Which buttons does the Lock Screen render? | unknown | Attach photo |
| 6b | Can the alarm be dismissed *without* touching the alert? | unknown | Side button / volume / Face ID? |
| 7 | Does the secondary button open the app into the wake flow? | unknown | App Intent or URL fallback? |
| 8 | Does a valid QR scan cancel all remaining alarms? | unknown | |
| 8b | Is an invalid / regenerated-stale QR rejected? | unknown | |
| 9 | Do pending alarms survive a full power cycle? | unknown | Decides SYSTEM_UNAVAILABLE handling |
| 10 | Is `.wav` accepted, or is `.caf` required? | unknown | |
| 11 | Does a `.relative` weekly alarm re-arm after Stop? | unknown | Possible cheap alternative to long chains |

---

## Corrected API signatures

Every `// SPIKE-VERIFY:` marker that the compiler rejected. This section is what
the real product gets built on — record the *actual* signature, not a paraphrase.

| Assumed | Actual | File / line |
|---|---|---|
| `AlarmManager.shared.authorizationState` | | AlarmService.swift |
| `try await AlarmManager.shared.requestAuthorization()` | | AlarmService.swift |
| `AlarmMetadata` conformance requirements | | AlarmService.swift |
| `secondaryButtonBehavior: .custom` | | AlarmService.swift |
| `AlertConfiguration.AlertSound.named(_:)` | | AlarmService.swift |
| `AlarmConfiguration(schedule:attributes:secondaryIntent:sound:)` | | AlarmService.swift |
| `AlarmManager.shared.cancel(id:)` | | AlarmService.swift |

---

## Consequences for the product spec

Fill this in after the table above. Each finding should name the spec section and
milestone it constrains, so Phase 1 continues without re-deriving any of it.

### Alarm cap → Milestone 3 (escalation stages)

*If the cap comfortably exceeds a real morning:* keep the pre-scheduled chain as
designed; escalation is baked in at schedule time.

*If the cap is tight:* record the number here, then choose — wider spacing, a
shorter post-failure tail, `.relative` repeating alarms (Test 11), or in-app
looping audio once the app is open. Write the decision and the reasoning.

**Decision:**

### Stop-button behaviour → spec sections 10, 18 (failure and penalty semantics)

If Stop cannot be suppressed (expected), the honest product statement is: *the app
keeps re-presenting alarms until QR verification, but each individual alarm can be
dismissed.* Confirm and write the exact wording to use in the app's own UI so it
does not over-promise.

**Decision:**

### No background execution → all escalation logic

Confirmed by research, re-confirm on device: the app cannot change an alarm's sound
at 08:05. Everything must be decided at schedule time. This is why `ChainPlanner`
is pure and stage assignment happens up front.

**Confirmed:** yes / no

### Reboot survival → spec section 20 (SYSTEM_UNAVAILABLE)

**Decision:**

### Sound format → Milestone 5 (Sound Lab)

Whichever format wins here is the format the real sound library must ship in.

**Decision:**

---

## Raw log

Paste the exported SpikeLog contents here.

```
(paste)
```
