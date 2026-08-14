# wakeup-agent

A personal iOS wake-up accountability agent. One user, local-first, zero recurring cost.

**Status: Phase 0 — AlarmKit feasibility spike. Not a product yet.**

The eventual product wakes you Sunday–Thursday at 08:00, escalates through gentle →
motivational → aggressive stages, marks the attempt FAILED at 08:15, and then *keeps
trying* until you physically scan a QR code taped in your kitchen.

Phase 0 exists to answer one question before any of that gets built:

> How much of that experience does iOS actually permit?

## What's here now

| Path | Purpose |
|---|---|
| `ios/WakeSpike/` | Minimal spike app — schedule alarms, chain them, scan the QR, log results |
| `tools/generate_sounds.py` | Generates throwaway 30s test tones (stdlib only, no pip installs) |
| `docs/00-phase0-spike.md` | The on-device test protocol — run this on the Mac session |
| `docs/alarmkit-findings.md` | Results table — **empty until the device session** |
| `docs/mac-setup.md` | Exact Xcode setup + free-signing steps |
| `docs/architecture.md` | What's proven, what's assumed, what it means for later milestones |
| `docs/cost.md` | Zero-cost accounting |

## Quick start (Windows, today)

```bash
python tools/generate_sounds.py
```

That is the whole Windows-verifiable surface. Everything else needs macOS + an iPhone
on iOS 26+; see `docs/mac-setup.md`.

## Ground rules

- No paid Apple Developer Program. Free Personal Team, re-signed ~every 7 days.
- No paid SaaS, no cloud resources, no third-party packages.
- The wake experience must work with no internet connection.
- AI (later, optional) never sits on the critical wake path.
