# CI build

`.github/workflows/ios-build.yml` is the only thing that compiles this project. There is no
Mac; the GitHub-hosted macOS runner is the compiler.

## What it proves and what it doesn't

**Proves:** the AlarmKit API signatures in `AlarmService.swift` exist and typecheck against a
real iOS 26 SDK.

**Does not prove:** that any of it *works*. Whether an alarm fires when locked, whether Stop
on alarm #1 leaves #2 scheduled, whether a chain of 46 alarms is even allowed — none of that
is visible to a compiler. Those stay in `00-phase0-spike.md` as device tests.

This is why `// SPIKE-VERIFY:` markers are **narrowed, not deleted**, when a build goes green:

```swift
// SPIKE-VERIFY: signature confirmed by CI <date>; runtime behaviour still unproven
```

## What the workflow does

1. Pins `runs-on: macos-26` and selects `Xcode_26.0.1.app` — the *oldest* iOS 26 Xcode on the
   image, so we compile against the lowest SDK the app claims to support rather than only
   proving it builds on the newest.
2. Records `sw_vers`, `xcodebuild -version` and the iOS SDK list into the run summary.
3. `brew install xcodegen` → `xcodegen generate` in `ios/WakeSpike/`.
4. `xcodebuild archive` for `generic/platform=iOS` with `CODE_SIGNING_ALLOWED=NO`.
5. Packages `Products/Applications` → `Payload/` → `WakeSpike-unsigned.ipa`.
6. Checks the four alarm `.wav` files actually made it into the bundle.
7. Uploads the `.ipa` and `build.log` as artifacts — **both on success and failure**.

> Never change `macos-26` to `macos-latest`. That image's default Xcode is 16.4, which has no
> iOS 26 SDK, and `import AlarmKit` fails with a misleading "no such module".

## Running it

Automatic on every push and PR. Manual: **Actions ▸ iOS build ▸ Run workflow**.

## Reading a failure from Windows

1. Open the run in the browser. The **Summary** page shows the toolchain and the failing step.
2. Expand **Build unsigned archive** for the compiler errors inline.
3. Or download the **build-log** artifact for the full unfiltered output.

Compiler errors will nearly all be in `ios/WakeSpike/Sources/AlarmService.swift` — it is the
only file touching AlarmKit, which is exactly why the code was structured that way.

Every corrected signature goes into `alarmkit-findings.md` → "Corrected API signatures".

## Getting the app

Download the **WakeSpike-unsigned-ipa** artifact. It is a zip containing
`Payload/WakeSpike.app` and is **unsigned** — it will not install by itself. Sideloadly signs
and installs it: see `install-from-windows.md`.

## Cost

Free. Public repos get unlimited GitHub-hosted runner minutes. If this repo were ever made
private, macOS would bill at 10× against a 2,000-minute Free-plan quota — about 25–40 builds
a month. See `cost.md`.
