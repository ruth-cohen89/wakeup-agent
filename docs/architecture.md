# Architecture

Phase 0 state. Everything below is labelled **proven**, **researched**, or
**unproven** so nothing gets built on an assumption by accident.

---

## The one-line problem

iOS will not let an app hold you hostage until you scan a QR code. The product
requirement is "keep trying until kitchen verification"; the platform offers
"present an alarm the user can dismiss". The architecture is the strongest bridge
between those two that iOS actually permits.

---

## Three findings that drive every design decision

### 1. The Stop button cannot be removed — *researched*

`AlarmPresentation.Alert` requires a `stopButton`. There is no API to suppress it,
make it slower, or require anything before it works. You can slide Stop on the
Lock Screen and go back to sleep without the app ever launching.

**Consequence:** a single alarm can never satisfy the requirement. The unit of
persistence is a *chain* of independently scheduled alarms — Stop ends one alarm,
not the morning. Only a verified QR scan cancels the remainder.

### 2. The app gets no background execution when an alarm fires — *researched*

There is no callback at 08:05 in which to swap to a nastier sound. The app runs
only when you open it.

**Consequence, and the most important one:** escalation must be **baked into the
pre-scheduled chain**. Each alarm carries its own sound, title and tint chosen at
schedule time. This is why `ChainPlanner` is a pure function producing a
`[PlannedAlarm]` — the entire morning is decided the night before.

This inverts the obvious design. There is no runtime "escalation engine"; there is
a planner that emits a fully-resolved schedule.

### 3. Alarm sound loops until Stop on iOS 26.1 — *researched, needs device confirmation*

Reported behaviour: 26.0 did not repeat sounds under 30s; 26.1 repeats until the
user slides Stop, with no auto-dismiss. Our test tones are 30s to stay clear of
the 26.0 regression regardless.

**Consequence:** within a single alarm, persistence is good. The gap the chain
covers is *between* alarms.

---

## The critical unknown

**Maximum concurrently scheduled AlarmKit alarms per app.** Not documented in
Apple's reference, the WWDC session, or the developer forums.

A real morning — 08:00 target, 2-minute spacing, running to 09:30 — needs **46
alarms**. The app displays this number and Test 4 measures the actual cap.

| If the cap is | Then |
|---|---|
| ≥ 46 | Chain design ships as specified |
| 10–45 | Widen spacing, or shorten the post-failure tail, and document the honest limit |
| < 10 | Chain is not viable; fall back to `.relative` repeating alarms plus in-app looping audio once opened |

Until Test 4 runs, **no downstream milestone should be built**, because the answer
changes what Milestone 3 even is.

---

## Component map

```
ChainPlanner          pure    plan(start:spacing:total:) -> [PlannedAlarm]
                              selfCheck() -> [String]        (in-app assertions)
        │
        ▼
AlarmService          impure  the ONLY file touching AlarmKit
                              schedule / scheduleChain / cancelAll
                              persists chain IDs to UserDefaults
        │
        ▼
OpenWakeIntent        AppIntent, openAppWhenRun = true
        │                     ← the only route from Lock Screen into the app
        ▼
WakeRouter ──► WakeView ──► ScanScreen ──► QRScannerView (AVCaptureSession)
                                    │
                                    ▼
                              QRTokenStore.matches()
                                    │
                                    ▼
                              AlarmService.cancelAll()   ← ends the morning
```

`SpikeLog` sits alongside everything, recording to the second.

### Why AlarmKit contact is confined to one file

Seven signatures could not be confirmed from Windows. Concentrating them means the
Mac session has exactly one file to repair, and the corrected signatures land in
one place in `alarmkit-findings.md`. Every other file compiles independently of
whether the AlarmKit guesses were right.

---

## QR verification design

- Token: random `UUID` per installation, persisted in `UserDefaults`.
- Payload: `wake-agent://verify/<uuid>` — app-specific scheme so a stray QR in the
  world cannot match.
- Not a secret: it authenticates *location*, not identity. Nothing of value leaks
  if photographed, which is why no backend credential goes near it.
- Regeneration overwrites the token, so a previously printed code stops matching
  immediately.
- **Live camera only.** `AVCaptureSession` + `AVCaptureMetadataOutput`, no
  `PHPicker`, no `UIImagePickerController`, no manual entry, no "I'm awake"
  button. The absence is the feature — the QR is only meaningful as proof you
  physically walked to the kitchen.

Known and accepted weakness: you could photograph the QR once and scan the photo
off a second screen. No software can prevent that. It is a commitment device, not
a security boundary.

---

## What Phase 0 deliberately does not build

Streaks, rewards, wallet, inbox, dashboard, penalties, emergency override,
motivation manager, TTS, Sound Lab, simulation mode, persistence layer, backend,
Firestore, Gemini.

Two of those have already been shaped by Phase 0 research, though, and the shape
should survive into implementation:

- **Simulation Mode** reuses `ChainPlanner.compressedPlan` and the `WakeStage`
  colour/label vocabulary in `WakeView` — both already exist.
- **Wake history** needs second-precision timestamps; `SpikeLog.timestamp` already
  establishes the format.

---

---

## Build and delivery pipeline

Development happens on Windows with no Mac available, so the toolchain is split
across three machines:

```
Windows            edit Swift, commit, push
   │
   ▼
GitHub Actions     macos-26 · Xcode 26 · iOS 26 SDK · free on public repos
   │               xcodegen generate  →  xcodebuild archive (UNSIGNED)
   │               →  WakeSpike-unsigned.ipa artifact
   ▼
Windows            Sideloadly + free secondary Apple ID
   │               certificate · device registration · provisioning · re-sign
   ▼
iPhone             install over USB, trust profile, run the device protocol
   │
   └──────────────  re-sign every ~7 days (Apple free-tier rule)
```

Four capabilities, three of which CI cannot provide:

| Capability | Where | Why not CI |
|---|---|---|
| Compile | GitHub Actions | — |
| Code sign | Windows | Free accounts get no developer-portal certificates |
| Provision | Windows | App Store Connect API keys need a paid membership |
| Install | Windows, USB | A cloud runner has no iPhone attached |

Full reasoning and citations: `signing-feasibility.md`.

### Consequence for the product

**The alarm cannot be your only alarm while certificates expire weekly.** Keep a
normal iOS Clock alarm as a backup until the signing situation is stable. This is
a product-level caveat, not just an ops detail.

### Consequence for the code

`project.yml` is now load-bearing — there is no `.xcodeproj` in the repo and none
should be committed. CI generates it. This removed the last step that genuinely
required a Mac.

---

## Cost

Zero, conditional on the repo staying public. See `cost.md`.
