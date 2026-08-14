# Installing on the iPhone from Windows

CI produces an **unsigned** `.ipa`. This is how it becomes a running app on your phone,
with no Mac and no money.

Read `signing-feasibility.md` first if you want to know why CI can't do this part.

---

## Use a secondary Apple ID

**Create a fresh, free Apple ID used only for sideloading.** Sideloadly needs an Apple ID and
password. Its FAQ states credentials are sent only to Apple's servers, but it is still
third-party software handling an Apple account.

A dedicated account means that if the tool, the PC, or the account is ever compromised, your
main iCloud, photos, messages, backups and payment details are untouched. It costs nothing and
takes two minutes at [appleid.apple.com](https://appleid.apple.com).

You do **not** need to sign into iCloud on the iPhone with it. It is only used for signing.

---

## One-time setup

1. **iTunes and iCloud — the web versions.**
   Sideloadly needs Apple's device drivers, which the Microsoft Store versions do not provide.
   - Uninstall the Microsoft Store versions if present.
   - Install from Apple directly: [iTunes for Windows (64-bit)](https://support.apple.com/en-us/106372) and iCloud for Windows.

2. **Sideloadly** — download from [sideloadly.io](https://sideloadly.io) and install.

3. **Connect the iPhone by USB**, unlock it, and tap **Trust This Computer**.

---

## Each install

1. Download **WakeSpike-unsigned-ipa** from the GitHub Actions run (Actions ▸ latest green
   run ▸ Artifacts). Unzip it to get `WakeSpike-unsigned.ipa`.
2. Open Sideloadly. Confirm your iPhone shows in the device dropdown.
3. Drag `WakeSpike-unsigned.ipa` onto the Sideloadly window.
4. Enter the **secondary** Apple ID. Complete the 2FA prompt if asked.
5. Press **Start**. Sideloadly creates the certificate, registers the device, generates the
   provisioning profile, re-signs, and installs — all the steps CI cannot do.
6. On the iPhone: **Settings ▸ General ▸ VPN & Device Management** ▸ tap the developer
   profile ▸ **Trust**.
7. Launch WakeSpike. Grant the alarm and camera permissions when asked.

Then run the device protocol in `00-phase0-spike.md`.

---

## The 7-day treadmill

Free Apple accounts issue 7-day certificates. This is Apple's rule; nothing here changes it.

- Sideloadly's daemon auto-refreshes apps nearing expiry when the phone is reachable over
  Wi-Fi or USB. Leave it configured and it mostly handles itself.
- If it lapses, the app stops launching. Re-run the install steps above — roughly two minutes.
- **A free account allows only 3 sideloaded apps at once.** WakeSpike is one of them.

Practical consequence for this project: **the alarm cannot be trusted as your only alarm.**
Until the certificate situation is stable, keep a normal iOS Clock alarm as a backup. An
expired certificate on a Tuesday night means no alarm on Wednesday morning.

---

## Troubleshooting

| Symptom | Cause |
|---|---|
| iPhone not listed | Microsoft Store iTunes installed instead of Apple's; or "Trust This Computer" not tapped |
| "Unable to sign" / cert errors | Free account already has 3 sideloaded apps — remove one |
| App installs but won't open | Developer profile not trusted (step 6) |
| App suddenly stops opening | 7-day certificate expired — re-install |
| Alarm permission missing | `NSAlarmKitUsageDescription` missing from the build, or free provisioning refused the capability — **record this, it is a device-test finding** |

---

## What this does not solve

Installation is not verification. Everything in `00-phase0-spike.md` still has to be run by
hand on the phone — especially **Test 4** (maximum concurrent alarms) and **Test 5** (does
Stop on one alarm leave the next scheduled), which together decide whether the product's core
behaviour is achievable at all.

And one unknown created by this route: **whether AlarmKit works under a free Personal Team
profile.** If alarm scheduling fails with a permissions or entitlement error after a
successful install, that is the answer — record it in `alarmkit-findings.md`.
