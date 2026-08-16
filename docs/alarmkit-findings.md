# AlarmKit findings

Evidence lands here in two stages, and they prove different things:

| Stage | Where | Proves | Does NOT prove |
|---|---|---|---|
| **A — Compile** | GitHub Actions `macos-26` | The API signatures exist and typecheck against a real iOS 26 SDK | Any runtime behaviour whatsoever |
| **B — Device** | iPhone via Sideloadly | What actually happens at 08:00 | — |

A green build does **not** close a `// SPIKE-VERIFY:` marker. It narrows it: the
signature is right, the behaviour is still unknown. Markers close only in stage B.

**Stage A status: PASS — green build on 2026-08-14, three CI iterations.
Re-confirmed 2026-08-16 with two further signatures (`AlarmManager.alarms`,
`Alarm.Schedule.Relative`), both green first try.**
**Stage B status: EMPTY — awaiting the physical device.**

Phase 0 is not complete and Phase 1 does not start until stage B is filled in.

Test numbers refer to `00-phase0-spike.md`. Fill in *every* row, including honest
"not achievable" answers.

---

## Stage A — compile results

| | |
|---|---|
| Date of run | 2026-08-14 |
| Workflow run URL | https://github.com/ruth-cohen89/wakeup-agent/actions/runs/31830358071 |
| Runner image | `macos-26` |
| macOS version | (logged in run output) |
| Xcode version | Xcode 26.0.1 (`/Applications/Xcode_26.0.1.app`) |
| iOS SDK compiled against | iOS 26.0 |
| Result | **PASS** — green build after 3 iterations |
| Unsigned `.ipa` produced? | Yes — `WakeSpike-unsigned.ipa` artifact uploaded |
| CI iterations | Run 1: `AlertConfiguration` / `AlarmConfiguration` not in scope. Run 2: `OpenWakeIntent` didn't conform to `LiveActivityIntent`. Run 3: green. |

---

## Stage B — device environment

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
| 11 | Does a `.relative` weekly alarm re-arm after Stop? | unknown | Possible cheap alternative to long chains. Construction compiles (stage A); runtime re-arm is the open part |
| 12 | **Does AlarmKit work under a free Personal Team profile?** | unknown | New risk from the sideload route — free profiles restrict entitlements and Sideloadly re-signs the app. If alarm scheduling fails after a successful install, this is why |

---

## Corrected API signatures — from stage A (compile)

Every `// SPIKE-VERIFY:` marker the compiler rejected. This section is what the
real product gets built on — record the *actual* signature, not a paraphrase.

Status values: `unverified` → `compiles` (stage A) → `behaviour confirmed` (stage B).

| Assumed | Actual | Status |
|---|---|---|
| `AlarmManager.shared.authorizationState` | Same — compiles as written | compiles |
| `try await AlarmManager.shared.requestAuthorization()` | Same — compiles as written | compiles |
| `AlarmMetadata` conformance requirements | `WakeMetadata: AlarmMetadata` compiles with `Codable`-compatible fields | compiles |
| `secondaryButtonBehavior: .custom` | Same — compiles as written | compiles |
| `AlertConfiguration.AlertSound.named(_:)` | Same type path, but requires `import ActivityKit` (not re-exported by AlarmKit) | compiles |
| `AlarmConfiguration(schedule:attributes:secondaryIntent:sound:)` | `AlarmManager.AlarmConfiguration<M>.alarm(schedule:attributes:stopIntent:secondaryIntent:sound:)` — nested under `AlarmManager`, uses `.alarm()` factory, has additional `stopIntent:` parameter | compiles |
| `AlarmManager.shared.cancel(id:)` | Same — compiles as written | compiles |
| `OpenWakeIntent: AppIntent` (implicit) | Must conform to `LiveActivityIntent` (extends `AppIntent`), requires `import ActivityKit` | compiles |
| `AlarmManager.shared.alarms` (existence, throwing-ness, async-ness all unknown) | Exists. **Throwing but not async** — probed as `try await`, compiler warned "no 'async' operations occur within 'await' expression" and said nothing about `try`. Returns a collection (`.count` typechecks) | compiles |
| `Alarm.Schedule.Relative(time:repeats:)` + `Alarm.Schedule.Relative.Time(hour:minute:)` + `.weekly([.sunday, …])` | All correct as guessed — the whole relative-schedule construction compiled unchanged | compiles |
| `AlarmManager.shared.schedule(id:configuration:)` returns Void | Returns a value — CI warns "result of call is unused". The spike discards it; the real product should look at what it hands back | compiles |

All live in `ios/WakeSpike/Sources/AlarmService.swift` and `OpenWakeIntent.swift`.
Three corrections were needed; the other eight compiled as originally guessed.

Note the asymmetry this table hides: `AlarmManager.alarms` compiling proves a
*count* can be read, not that the count drops when an alarm is stopped. That is
exactly the Test 8 question and it stays stage B.

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
