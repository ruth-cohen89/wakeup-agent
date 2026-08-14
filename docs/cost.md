# Cost

**Phase 0 recurring cost: $0.00.** Nothing in this repo can generate a bill.

## What's in use

| Thing | Cost | Notes |
|---|---|---|
| **GitHub Actions macOS runners** | **Free** | Unlimited for **public** repos — see the condition below |
| **Sideloadly** | **Free** | Signs and installs from Windows |
| **iTunes / iCloud for Windows** | **Free** | Apple's web versions, needed for device drivers |
| Xcode | Free | Runs on the CI runner; we never install it |
| Apple Personal Team signing | Free | 7-day expiry, re-sign via Sideloadly |
| AlarmKit | Free | System framework, no entitlement, no paid membership |
| AVFoundation / CoreImage | Free | System frameworks |
| Python stdlib (`wave`, `math`) | Free | No pip installs |
| XcodeGen | Free | Installed on the CI runner via Homebrew at build time |

**Third-party packages: none. Cloud services: none. SaaS: none.**

### ⚠️ The one condition on "free"

GitHub-hosted runner minutes are unlimited **only for public repositories**. On a
private repo the Free plan gives 2,000 minutes/month and **macOS bills at 10×** —
about 200 macOS minutes, or 25–40 builds.

**This repo is public specifically to keep the zero-cost guarantee absolute.** If
it is ever made private, that guarantee weakens to a quota, and heavy iteration
could exceed it.

## Explicitly declined

- **Apple Developer Program ($99/yr)** — not needed. The cost is re-signing weekly,
  which is accepted. It *would* enable CI signing outright, and is the honest
  fallback if the sideload route ever stops working.
- **AWS EC2 Mac** — 24-hour minimum dedicated-host billing. Not free. Rejected.
- **MacStadium / MacinCloud / Scaleway Mac** — paid subscriptions. Rejected.
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
