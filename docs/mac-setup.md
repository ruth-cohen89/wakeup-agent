# Mac setup — WakeSpike

Everything here needs macOS + Xcode + your iPhone on **iOS 26 or later**. Budget
~20 minutes for setup, then run `00-phase0-spike.md`.

Nothing on this page costs money. Free Apple Personal Team only.

---

## Before you sit down at the Mac

- [ ] Confirm the iPhone is on iOS 26+ (*Settings ▸ General ▸ About ▸ Software Version*).
      AlarmKit does not exist below iOS 26 — if the phone is older, stop, nothing
      here will run.
- [ ] Have your Apple ID password to hand (Xcode will ask when adding the account).
- [ ] Bring a Lightning/USB-C cable.
- [ ] Have a printer available, or be ready to display the QR on a second screen.

---

## Path A — no tool installs (recommended for a borrowed Mac)

1. Copy or clone this repo onto the Mac.
2. Xcode ▸ **File ▸ New ▸ Project ▸ iOS ▸ App**.
   - Product Name: `WakeSpike`
   - Interface: **SwiftUI**, Language: **Swift**
   - Storage: **None**, tests: unchecked
   - Save it inside the repo's `ios/` folder.
3. In the new project, delete the generated `ContentView.swift` **and** the
   generated `WakeSpikeApp.swift` (Move to Trash). Ours replace them.
4. Drag `ios/WakeSpike/Sources/` from Finder into the Xcode project navigator.
   - ✅ *Copy items if needed* — **uncheck** (keep them in the repo)
   - ✅ *Create groups*
   - ✅ Target: **WakeSpike**
5. Drag `ios/WakeSpike/Resources/` in the same way, but choose
   **Create folder references** so the four `.wav` files land in the bundle root.
6. Select the **WakeSpike target ▸ General**:
   - Minimum Deployments: **iOS 26.0**
7. Target ▸ **Info** — add these two rows (they're in the repo's `Info.plist` if you
   want to copy the exact strings):
   - `NSAlarmKitUsageDescription` → *"WakeSpike schedules your morning alarms…"*
   - `NSCameraUsageDescription` → *"WakeSpike uses the camera to scan the QR code…"*

   Also add a URL Type with scheme `wake-agent` (Info ▸ URL Types ▸ +).
8. Target ▸ **Signing & Capabilities**:
   - ✅ Automatically manage signing
   - Team: **your Apple ID (Personal Team)** — add the account via
     *Xcode ▸ Settings ▸ Accounts ▸ +* if it isn't listed
   - Bundle Identifier: something unique, e.g. `com.ruthcohen.wakespike`
9. Connect the iPhone, pick it as the run destination, press **⌘R**.
10. First run only — on the iPhone: *Settings ▸ General ▸ VPN & Device Management*
    ▸ tap your developer certificate ▸ **Trust**. Then run again.

## Path B — if the Mac already has XcodeGen

```bash
cd ios/WakeSpike
xcodegen generate
open WakeSpike.xcodeproj
```

Then do steps 8–10 above. Edit `PRODUCT_BUNDLE_IDENTIFIER` in `project.yml` first.

Do **not** install Homebrew on a borrowed Mac just for this — Path A is fine.

---

## Expected build errors (this is normal)

The Swift was written on Windows and has never been compiled. Seven AlarmKit
signatures could not be confirmed from documentation alone. They are all in
`Sources/AlarmService.swift` and all marked:

```swift
// SPIKE-VERIFY: <the assumption>
```

Find them with **⌘F → "SPIKE-VERIFY"**, or:

```bash
grep -rn "SPIKE-VERIFY" ios/
```

When the compiler rejects one, use Xcode's autocomplete or **⌥-click** the symbol
to see the real signature, fix it in place, and **write the correct signature into
`alarmkit-findings.md`**. That record is a Phase 0 deliverable — the corrected API
shape is what the real product gets built on.

Nothing outside `AlarmService.swift` depends on AlarmKit, so the rest of the app
should compile untouched.

---

## Sound format fallback

The bundled sounds are `.wav`. If AlarmKit rejects them (a spike test item):

```bash
cd ios/WakeSpike/Resources/Sounds
for f in *.wav; do afconvert -f caff -d LEI16 "$f" "${f%.wav}.caf"; done
```

Then change `soundFileName` in `AlarmService.swift` to the `.caf` names and
re-run. `afconvert` ships with macOS — no install needed.

---

## Re-signing every ~7 days

Free Personal Team provisioning profiles expire in about a week, and the app will
refuse to launch when it lapses. To restore it:

1. Connect the iPhone.
2. Open the project, press **⌘R**.

That's all — no reconfiguration. Known free-account limits: **10 App IDs per 7
days**, 3 devices, 10 capability changes per 7 days. This is why the spike is a
single target with no widget extension: every extra bundle ID burns quota.
