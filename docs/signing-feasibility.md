# Signing feasibility without a Mac

**Question:** can GitHub Actions replace a physical Mac completely, for free?

**Answer:** for *compiling*, yes. For *signing, provisioning and installing*, no — and the
blocker is Apple policy, not tooling. Those three move to Windows instead, which works and
is still free.

---

## Four capabilities, routinely conflated

"Can I build iOS apps without a Mac?" hides four separate questions:

| | Capability | Free without a Mac? | Where |
|---|---|---|---|
| 1 | **Compile** — turn Swift into a `.app` | ✅ Yes | GitHub Actions `macos-26` |
| 2 | **Code sign** — apply a cryptographic identity | ❌ Not in CI | Windows / Sideloadly |
| 3 | **Provision** — authorize this app + this device | ❌ Not in CI | Windows / Sideloadly |
| 4 | **Install** — get it onto the iPhone | ❌ Not from CI | Windows, USB |

CI solves (1). It cannot solve (2), (3) or (4). Sideloadly on Windows solves all three.

---

## 1. Compiling — works, free, no Mac

GitHub-hosted `macos-26` runners are **free and unlimited for public repositories**. The
image carries Xcode 26.0.1 → 26.6 and iOS SDKs 26.0 → 26.5, which is what AlarmKit needs.

Since there is no `.xcodeproj` in the repo, CI generates one from `project.yml` with
XcodeGen — so the project never has to be created in the Xcode GUI. That removes the last
step that genuinely required a Mac.

> ⚠️ `macos-latest` does **not** work. It still resolves to an image whose default Xcode is
> 16.4, which has no iOS 26 SDK, so `import AlarmKit` fails with "no such module". The
> workflow pins `runs-on: macos-26` and selects Xcode explicitly.

**Cost note:** free-and-unlimited applies to **public** repos. On a private repo the Free
plan gives 2,000 minutes/month and **macOS bills at 10×**, so ~200 macOS minutes — roughly
25–40 builds. This repo is public specifically to keep the guarantee absolute.

---

## 2 & 3. Signing and provisioning in CI — blocked by Apple

Four independent reasons, any one of which is sufficient:

**a. Free accounts have no developer-portal access.**
Certificates, Identifiers & Profiles on `developer.apple.com` requires an active paid Apple
Developer Program membership. A free Apple ID cannot create or export a development
certificate there, so there is nothing to load into CI as a secret.

**b. The headless auth mechanism requires a paid membership.**
`xcodebuild -allowProvisioningUpdates` can create signing assets automatically, but needs
credentials to do it. The supported non-interactive mechanism is an **App Store Connect API
key** — and generating one requires a paid membership. Free accounts cannot create one.

**c. Interactive Apple ID login can't run on a runner.**
The only path left is signing into Xcode with an Apple ID, which involves 2FA and a GUI.
Ephemeral headless runners cannot do this, and the resulting assets would die with the runner.

**d. Device registration needs the physical phone.**
Free Personal Team device registration happens through Xcode with the iPhone plugged in. A
cloud runner has no iPhone attached and no way to acquire one.

### There is no workaround

Not a different action, not a stored secret, not fastlane, not `match`. Every one of those
presupposes a certificate that a free account is not permitted to create in the first place.
Anyone claiming otherwise is describing a **paid** account.

### Explicitly rejected

- **AWS EC2 Mac** — 24-hour minimum dedicated-host billing. Not free. Rejected.
- **MacStadium / MacinCloud / Scaleway Mac** — all paid subscriptions. Rejected.
- **Paid Apple Developer Program ($99/yr)** — would solve CI signing outright, and is the
  honest answer if the sideload route ever stops working. Rejected for now by requirement.

---

## 4. Installing — Windows does it

Sideloadly implements Apple's free-provisioning flow natively on Windows. It authenticates
your Apple ID with Apple, creates the development certificate, registers the device,
generates the provisioning profile, re-signs the `.ipa`, and installs it over USB.

That is exactly the set of things CI cannot do, and it needs no Mac.

| | |
|---|---|
| iOS support | iOS 7 → iOS 26+ |
| Apple ID | Free accounts supported |
| App limit | **3** sideloaded apps on a free account |
| Expiry | **7 days**, unchanged — this is an Apple rule, not a tool limitation |
| Refresh | Daemon auto-refreshes over Wi-Fi/USB before expiry |
| Windows | 7/8/10/11; needs the **web** versions of iTunes + iCloud, not Microsoft Store versions |
| Credentials | Its FAQ states the Apple ID and password go only to Apple's servers |

Full procedure: `install-from-windows.md`.

---

## Honest limitations of this route

- **You are trusting third-party software with an Apple ID.** Mitigation: use a dedicated
  secondary Apple ID, so a compromise never touches your main iCloud, photos or payment details.
- **The 7-day treadmill is real.** Auto-refresh helps, but if the PC is off or the phone is
  away for a week, the app dies and needs a re-install.
- **3-app ceiling** on a free account.
- **CI proves signatures, never behaviour.** A green build says the AlarmKit API calls exist.
  It says nothing about whether an alarm fires when the phone is locked.
- **One unknown this route creates:** whether AlarmKit functions under a free Personal Team
  profile at all. Evidence says it needs only `NSAlarmKitUsageDescription` and no special
  entitlement — but free profiles restrict entitlements and Sideloadly re-signs the app. This
  is **unproven** and is now a device-test item.

---

## Verdict

GitHub Actions replaces the Mac **for compiling only**. Combined with Sideloadly on Windows,
the full chain — edit → compile → sign → install → run on iPhone — is achievable with no Mac
and no money. The project stays native iOS and stays free.

## Sources

- [macos-26 generally available](https://github.blog/changelog/2026-02-26-macos-26-is-now-generally-available-for-github-hosted-runners/)
- [macos-26 image contents](https://github.com/actions/runner-images/blob/main/images/macos/macos-26-arm64-Readme.md)
- [macos-latest still on Xcode 16.4](https://github.com/actions/runner-images/issues/14165)
- [GitHub Actions billing](https://docs.github.com/en/actions/concepts/billing-and-usage)
- [App Store Connect API keys](https://developer.apple.com/documentation/appstoreconnectapi/creating-api-keys-for-app-store-connect-api)
- [Free vs paid Apple accounts](https://bitrig.com/blog/apple-developer-program-free-vs-paid)
- [Personal Team cannot code sign for distribution](https://developer.apple.com/library/archive/qa/qa1915/_index.html)
- [Sideloadly FAQ](https://sideloadly.io/faq.html)
