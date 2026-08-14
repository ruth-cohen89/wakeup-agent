# Cost

**Phase 0 recurring cost: $0.00.** Nothing in this repo can generate a bill.

## What's in use

| Thing | Cost | Notes |
|---|---|---|
| Xcode | Free | Mac App Store |
| Apple Personal Team signing | Free | 7-day expiry, re-run ⌘R to renew |
| AlarmKit | Free | System framework, no entitlement, no paid membership |
| AVFoundation / CoreImage | Free | System frameworks |
| Python stdlib (`wave`, `math`) | Free | No pip installs |
| XcodeGen | Free, optional | Only if the Mac already has it — don't install it for this |

**Third-party packages: none. Cloud services: none. SaaS: none.**

## Explicitly declined

- **Apple Developer Program ($99/yr)** — not needed. The cost is re-signing weekly,
  which is accepted.
- **Paid cloud TTS** — later milestones use Apple's on-device speech synthesis.
- **Any always-on server** — the wake experience must work with no internet at all,
  so there is nothing for a server to do at 08:00.

## Things that could cost money later — none approved yet

If any of these ever get proposed, they get written down here *before* being used,
with the free-tier limits and what happens past them.

| Candidate | Milestone | Free tier | Status |
|---|---|---|---|
| Cloud Run | 14 | Scales to zero at `min-instances=0` | Not started |
| Firestore | 14 | Generous free quota; one user is far inside it | Not started |
| Gemini API | 15 | Flash/Flash-Lite free tier; used occasionally, never on the wake path | Not started |

If GCP billing is ever enabled, set a budget alert first.

## The rule

No service with a fixed monthly minimum, and no paid dependency added silently. If
something might cost money, it gets documented here before it gets used.
