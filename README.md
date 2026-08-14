# wakeup-agent

A personal iOS wake-up accountability agent. One user, local-first, zero recurring cost.

**Status: Phase 0 — AlarmKit feasibility spike. Not a product yet.**

The eventual product wakes you Sunday–Thursday at 08:00, escalates through gentle →
motivational → aggressive stages, marks the attempt FAILED at 08:15, and then *keeps
trying* until you physically scan a QR code taped in your kitchen.

Phase 0 exists to answer one question before any of that gets built:

> How much of that experience does iOS actually permit?

**Built entirely without a Mac.** Development is on Windows, compilation happens on a
free GitHub Actions macOS runner, and signing and installation happen on Windows via
Sideloadly. See `docs/signing-feasibility.md` for what that can and cannot do.

## What's here now

| Path | Purpose |
|---|---|
| `ios/WakeSpike/` | Minimal spike app — schedule alarms, chain them, scan the QR, log results |
| `.github/workflows/ios-build.yml` | The compile gate — the only thing that compiles this project |
| `tools/generate_sounds.py` | Generates throwaway 30s test tones (stdlib only, no pip installs) |
| `docs/ci-build.md` | How the CI build works and how to read a failure |
| `docs/signing-feasibility.md` | **Can CI replace a Mac?** Compile yes; sign/provision/install no, and exactly why |
| `docs/install-from-windows.md` | Sideloadly setup, install steps, the 7-day refresh |
| `docs/00-phase0-spike.md` | The on-device test protocol |
| `docs/alarmkit-findings.md` | Results — **empty until the device session** |
| `docs/architecture.md` | What's proven, what's assumed, and the build pipeline |
| `docs/mac-setup.md` | Superseded; kept for reference only |
| `docs/cost.md` | Zero-cost accounting |

## Build → install

1. Push. GitHub Actions compiles on `macos-26` and uploads `WakeSpike-unsigned.ipa`.
2. Download that artifact on Windows.
3. Sideloadly signs it with a free Apple ID and installs it over USB.
4. Run `docs/00-phase0-spike.md` on the phone.

Locally on Windows you can regenerate the alarm test tones:

```bash
python tools/generate_sounds.py
```

> ⚠️ Free Apple signing expires every 7 days. Until that's stable, **keep a normal
> iOS Clock alarm as a backup** — an expired certificate means no alarm.

## Ground rules

- No paid Apple Developer Program. Free Personal Team, re-signed ~every 7 days.
- No paid SaaS, no cloud resources, no third-party packages.
- The wake experience must work with no internet connection.
- AI (later, optional) never sits on the critical wake path.
