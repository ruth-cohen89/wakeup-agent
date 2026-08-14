# Phase 0 — the device test protocol

Run these in order on the iPhone. Record every result in `alarmkit-findings.md`.

Setup first: `mac-setup.md`.

**Before you start:** open the app, tap **Run planner self-check**. It must say
PASS. That validates the stage-boundary logic without needing any alarm to fire —
if it fails, something got broken in transit and the rest of the results are suspect.

---

## Test 1 — Authorization

- [ ] Tap **Request AlarmKit authorization**. Note the exact prompt wording.
- [ ] Note the resulting state string.
- [ ] Go to *Settings ▸ WakeSpike*, revoke alarm access, return, tap **Refresh state**.
- [ ] Record what a revoked state looks like — the real app must detect this before
      bedtime and warn loudly (spec section 33).

## Test 2 — Single alarm, app closed, phone locked

- [ ] Tap **Gentle** under "Single alarm, +60s".
- [ ] Swipe the app fully closed. Lock the phone. Put it face down.
- [ ] Wait.

Record: did it fire? How long after the minute? What appeared on the Lock Screen?

## Test 3 — Custom sounds

- [ ] Repeat Test 2 once per stage (Gentle / Motivation / Aggressive / PostFailure).

Record for each: did the custom sound play, or did iOS substitute a default?
**Did it loop until you slid Stop, or stop on its own?** Time how long it rang if
it stopped by itself.

> Research says iOS 26.1 repeats until Stop with no auto-dismiss, and that 26.0
> did not repeat sounds under 30s. Our files are 30s to sidestep that. Confirm
> which behaviour your build actually has.

- [ ] Also confirm whether `.wav` was accepted at all. If sounds are silent or
      default, do the `afconvert` step in `mac-setup.md` and retest.

## Test 4 — Maximum alarm count ⚠️ THE GATE

The app shows **"A real morning needs N alarms"** at the top of this section. That
is the number to clear.

- [ ] Set the stepper to 5 → **Run cap test** → note "Currently scheduled" → **Cancel all**
- [ ] Repeat at 20
- [ ] Repeat at 50
- [ ] Repeat at 100

Record the highest count that scheduled successfully, and the **exact error text**
where it stopped. Check the log — `AlarmService` records `CHAIN STOPPED at index N`.

**Why this matters:** if the cap is below the real-morning number, "keep trying
after 08:15" cannot be done purely with pre-scheduled alarms, and Milestone 3
changes to wider spacing plus in-app audio once the app is open. Everything
downstream depends on this number.

- [ ] **Cancel all** before moving on.

## Test 5 — Stop independence

This is the behaviour the entire design rests on.

- [ ] Tap **Compressed chain: 6 alarms, 20s apart**.
- [ ] Lock the phone.
- [ ] When the first fires, **slide Stop**.
- [ ] Wait 20 seconds.

Record: **did the second alarm still fire?** If Stop cancels the whole chain, the
core product requirement is not achievable as designed — say so plainly in the
findings, and note what iOS does instead.

## Test 6 — Lock Screen affordances

- [ ] Schedule a single alarm, let it fire, and photograph the Lock Screen.

Record exactly: which buttons appear, their labels, whether Stop is a slide or a
tap, whether the alarm shows in Dynamic Island / StandBy, and whether anything can
dismiss it *without* interacting with the alert (side button? volume? Face ID?).
Any of those is a loophole the real product must account for.

## Test 7 — Secondary button opens the app

- [ ] When an alarm fires, tap **Scan QR** on the Lock Screen.

Record: does the app open? Straight into `WakeView`? Does it need Face ID first?
How many seconds from tap to usable screen? Check the log for `OpenWakeIntent fired`.

If the App Intent route doesn't work, try the URL fallback: with the phone
unlocked, open Safari and enter the QR payload string. Note which route worked —
this determines how the real app gets launched.

## Test 8 — QR verification cancels the chain

- [ ] Tap **Show / print kitchen QR**, print it, tape it in the kitchen.
- [ ] Schedule the 6-alarm compressed chain.
- [ ] Let one or two fire. Walk to the kitchen. Open the scanner. Scan.

Record: the verified timestamp, and that "Currently scheduled" dropped to 0.

- [ ] Try scanning something else (any other QR) → must show **Not your code**.
- [ ] Tap **Regenerate token**, then scan the *old printout* → must be rejected.
- [ ] Confirm there is genuinely no way to verify except the live camera.

## Test 9 — Survival across reboot

- [ ] Schedule a chain starting ~10 minutes out.
- [ ] Power the iPhone fully off, wait a minute, power on. **Do not open the app.**

Record: did the alarms still fire? This decides whether `SYSTEM_UNAVAILABLE`
(spec section 20) needs to distinguish "phone was off" from "you ignored it".

## Test 10 — Sound format

Covered in Test 3; record the conclusion explicitly: WAV accepted, or CAF required.

## Test 11 — Repeating weekly alarms

`AlarmService` currently schedules `.fixed` dates. If time allows, try a
`.relative` schedule with a Sun–Thu recurrence.

Record: does one repeating alarm re-arm itself after Stop? If so, the production
schedule can be far cheaper than 46 one-shot alarms per day — which may be the
answer if Test 4 finds a low cap.

---

## Finishing up

- [ ] Open the log, tap Share, send it to yourself.
- [ ] Paste it into `alarmkit-findings.md` under "Raw log".
- [ ] Fill in **every** row of the findings table, including honest "not
      achievable" entries.

Phase 0 is done when no row says "unknown". Do not start Phase 1 before then.
