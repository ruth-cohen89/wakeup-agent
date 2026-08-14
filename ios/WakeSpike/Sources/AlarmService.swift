import Foundation
import SwiftUI
import AlarmKit
import AppIntents

/// Every AlarmKit call site in the spike lives in this file.
///
/// This code was written on Windows against Apple's documented AlarmKit symbols
/// (WWDC25 session 230 and the AlarmKit reference). There is no Mac on this
/// project — it is compiled by the GitHub Actions `macos-26` runner
/// (`.github/workflows/ios-build.yml`), which is the only compiler it ever sees.
///
/// Each place where a signature could not be confirmed from documentation alone is
/// marked `// SPIKE-VERIFY:` — those are the expected CI build errors, and each is
/// a row to fill in `docs/alarmkit-findings.md`.
///
/// A green build proves the *signature* exists. It proves nothing about runtime
/// behaviour, so markers are narrowed after a successful compile, never deleted.
/// They close only when the device test confirms the behaviour.
///
/// Nothing here invents behaviour. Where the API shape was genuinely unknown the
/// uncertainty is stated rather than guessed around.

// MARK: - Stages

/// The escalation stages from the product spec, mapped to the sound each one uses.
///
/// Critical architectural point discovered during Phase 0 research: the app is
/// granted no background execution when an alarm fires, so it cannot run code at
/// 08:05 to "become more aggressive". Escalation must therefore be baked into the
/// pre-scheduled chain — each alarm carries its own sound and title at schedule
/// time. This enum is what makes that mapping explicit.
enum WakeStage: String, Codable, CaseIterable, Sendable {
    case gentle        // 08:00–08:05, PERFECT window
    case motivation    // 08:05–08:10, SUCCESS window
    case aggressive    // 08:10–08:15, final five minutes
    case postFailure   // 08:15+, FAILED but still trying

    var soundFileName: String {
        switch self {
        case .gentle:      return "gentle_chime.wav"
        case .motivation:  return "warning_pulse.wav"
        case .aggressive:  return "buzzer.wav"
        case .postFailure: return "siren.wav"
        }
    }

    /// Post-failure deliberately rotates sounds — a single repeated noise is easy
    /// for a sleeping brain to adapt to (spec section 9).
    static let postFailureRotation = [
        "buzzer.wav", "siren.wav", "warning_pulse.wav", "buzzer.wav",
    ]

    var alertTitle: String {
        switch self {
        case .gentle:      return "Good morning"
        case .motivation:  return "Time to get up"
        case .aggressive:  return "Get up now"
        case .postFailure: return "Kitchen. QR."
        }
    }

    var tint: Color {
        switch self {
        case .gentle:      return .green
        case .motivation:  return .yellow
        case .aggressive:  return .orange
        case .postFailure: return .red
        }
    }
}

// MARK: - Metadata

/// Custom metadata travels with the alarm so the app knows, when opened from the
/// lock screen, which stage fired and which chain it belonged to.
// SPIKE-VERIFY: AlarmMetadata's exact protocol requirements. Documented as a
// protocol custom metadata conforms to; assumed Codable + Hashable + Sendable here.
struct WakeMetadata: AlarmMetadata {
    let chainID: String
    let stageRaw: String
    let indexInChain: Int

    var stage: WakeStage { WakeStage(rawValue: stageRaw) ?? .gentle }

    init(chainID: UUID, stage: WakeStage, indexInChain: Int) {
        self.chainID = chainID.uuidString
        self.stageRaw = stage.rawValue
        self.indexInChain = indexInChain
    }
}

// MARK: - Chain plan

/// One alarm in a chain: when it fires, what it sounds like, what stage it is.
struct PlannedAlarm: Identifiable, Sendable {
    let id: UUID
    let chainID: UUID
    let fireDate: Date
    let stage: WakeStage
    let soundFileName: String
    let indexInChain: Int
}

/// Builds the escalation chain. Pure, synchronous, no AlarmKit types — so this is
/// the one piece of scheduling logic that is unit-testable without a device, and
/// it carries straight into the real product unchanged.
enum ChainPlanner {

    /// Real-product shape: gentle 0–5m, motivation 5–10m, aggressive 10–15m, then
    /// post-failure repeats until `totalMinutes`.
    ///
    /// - Parameters:
    ///   - start: the wake target (08:00 in production).
    ///   - spacingSeconds: gap between alarms in the chain.
    ///   - totalMinutes: how far past the target to keep trying.
    static func plan(
        start: Date,
        spacingSeconds: Int,
        totalMinutes: Int,
        perfectWindowMinutes: Int = 5,
        deadlineMinutes: Int = 15
    ) -> [PlannedAlarm] {
        let chainID = UUID()
        var planned: [PlannedAlarm] = []
        var offset = 0
        var index = 0
        let totalSeconds = totalMinutes * 60

        while offset <= totalSeconds {
            let minutesIn = offset / 60
            let stage: WakeStage
            if minutesIn < perfectWindowMinutes {
                stage = .gentle
            } else if minutesIn < perfectWindowMinutes * 2 {
                stage = .motivation
            } else if minutesIn < deadlineMinutes {
                stage = .aggressive
            } else {
                stage = .postFailure
            }

            let sound: String
            if stage == .postFailure {
                let rotation = WakeStage.postFailureRotation
                sound = rotation[index % rotation.count]
            } else {
                sound = stage.soundFileName
            }

            planned.append(
                PlannedAlarm(
                    id: UUID(),
                    chainID: chainID,
                    fireDate: start.addingTimeInterval(TimeInterval(offset)),
                    stage: stage,
                    soundFileName: sound,
                    indexInChain: index
                )
            )

            offset += spacingSeconds
            index += 1
        }

        return planned
    }

    /// Deterministic checks on the stage boundaries.
    ///
    /// The planner is pure logic and carries straight into the real product, so it
    /// is worth verifying — but adding an XCTest target to a borrowed Mac costs
    /// setup time and another signing identity. Running the checks in-app instead
    /// keeps the Mac session to a single target while still proving the boundaries.
    ///
    /// Boundary semantics match the spec: the PERFECT window is 08:00:00–08:05:00
    /// and the SUCCESS deadline is 08:15:00, so an alarm exactly at minute 5 is
    /// already past gentle, and one exactly at minute 15 is already post-failure.
    static func selfCheck() -> [String] {
        var failures: [String] = []

        let start = Date(timeIntervalSince1970: 0)
        let plan = plan(start: start, spacingSeconds: 120, totalMinutes: 90)

        func expect(_ condition: Bool, _ label: String) {
            if !condition { failures.append(label) }
        }

        expect(plan.count == 46, "expected 46 alarms for a 90-minute morning at 120s, got \(plan.count)")

        func stage(atMinute minute: Int) -> WakeStage? {
            plan.first { Int($0.fireDate.timeIntervalSince(start)) == minute * 60 }?.stage
        }

        expect(stage(atMinute: 0) == .gentle, "minute 0 should be gentle")
        expect(stage(atMinute: 4) == .gentle, "minute 4 should be gentle (PERFECT window)")
        expect(stage(atMinute: 6) == .motivation, "minute 6 should be motivation")
        expect(stage(atMinute: 8) == .motivation, "minute 8 should be motivation")
        expect(stage(atMinute: 10) == .aggressive, "minute 10 should be aggressive")
        expect(stage(atMinute: 14) == .aggressive, "minute 14 should be aggressive")
        expect(stage(atMinute: 16) == .postFailure, "minute 16 should be post-failure")
        expect(stage(atMinute: 88) == .postFailure, "minute 88 should still be post-failure")

        // The chain must not give up at the deadline — that is the whole point.
        let postFailureCount = plan.filter { $0.stage == .postFailure }.count
        expect(postFailureCount > 30, "expected sustained post-failure alarms, got \(postFailureCount)")

        // Post-failure must rotate sounds rather than repeat one the brain adapts to.
        let postFailureSounds = Set(plan.filter { $0.stage == .postFailure }.map(\.soundFileName))
        expect(postFailureSounds.count >= 3, "post-failure should rotate ≥3 sounds, got \(postFailureSounds.count)")

        // Every alarm in one plan belongs to the same chain.
        expect(Set(plan.map(\.chainID)).count == 1, "all alarms in a plan must share one chainID")

        // IDs must be unique or cancellation would miss some.
        expect(Set(plan.map(\.id)).count == plan.count, "alarm IDs must be unique")

        return failures
    }

    /// Compressed variant for bench testing without waiting a real morning.
    static func compressedPlan(start: Date, spacingSeconds: Int = 20, count: Int) -> [PlannedAlarm] {
        let chainID = UUID()
        var planned: [PlannedAlarm] = []
        let stages = WakeStage.allCases
        for index in 0..<count {
            let stage = stages[min(index / 2, stages.count - 1)]
            planned.append(
                PlannedAlarm(
                    id: UUID(),
                    chainID: chainID,
                    fireDate: start.addingTimeInterval(TimeInterval(index * spacingSeconds)),
                    stage: stage,
                    soundFileName: stage.soundFileName,
                    indexInChain: index
                )
            )
        }
        return planned
    }
}

// MARK: - Service

@MainActor
@Observable
final class AlarmService {

    static let shared = AlarmService()

    private(set) var scheduledIDs: [UUID] = []
    private(set) var lastError: String?
    private(set) var authorizationText: String = "unknown"

    /// Chain IDs persist so the app can cancel the remainder after a QR scan even
    /// if it was killed and relaunched from the lock screen in between.
    private let storageKey = "wakespike.scheduled.ids"

    private init() {
        scheduledIDs = (UserDefaults.standard.array(forKey: storageKey) as? [String] ?? [])
            .compactMap(UUID.init(uuidString:))
    }

    private func persist() {
        UserDefaults.standard.set(scheduledIDs.map(\.uuidString), forKey: storageKey)
    }

    // MARK: Authorization

    func refreshAuthorizationState() {
        // SPIKE-VERIFY: property name and enum case names on AlarmManager.
        let state = AlarmManager.shared.authorizationState
        authorizationText = String(describing: state)
        SpikeLog.shared.log("authorizationState = \(authorizationText)")
    }

    func requestAuthorization() async {
        do {
            // SPIKE-VERIFY: documented as `requestAuthorization()`; return type assumed
            // to be the authorization state.
            let state = try await AlarmManager.shared.requestAuthorization()
            authorizationText = String(describing: state)
            SpikeLog.shared.log("requestAuthorization -> \(authorizationText)")
        } catch {
            record(error, context: "requestAuthorization")
        }
    }

    // MARK: Scheduling

    /// Test 2 in the protocol: a single alarm, default 60s out.
    func scheduleSingle(secondsFromNow: Int = 60, stage: WakeStage = .gentle) async {
        let fireDate = Date().addingTimeInterval(TimeInterval(secondsFromNow))
        let planned = PlannedAlarm(
            id: UUID(),
            chainID: UUID(),
            fireDate: fireDate,
            stage: stage,
            soundFileName: stage.soundFileName,
            indexInChain: 0
        )
        await schedule(planned)
        SpikeLog.shared.log(
            "scheduled single \(stage.rawValue) at \(SpikeLog.timestamp(fireDate)) sound=\(planned.soundFileName)"
        )
    }

    /// Tests 4 and 5: schedule N independent alarms.
    ///
    /// Each alarm gets its own UUID deliberately. The whole point of the chain is
    /// that pressing Stop on one alarm must not cancel the others — iOS gives no
    /// way to make a single alarm un-dismissable, so independence is what makes
    /// "keep trying after 08:15" possible at all.
    func scheduleChain(_ planned: [PlannedAlarm]) async {
        SpikeLog.shared.log("--- scheduling chain of \(planned.count) ---")
        var succeeded = 0
        for alarm in planned {
            let ok = await schedule(alarm)
            if ok {
                succeeded += 1
            } else {
                // The cap, if one exists, shows up here. Record where it stopped.
                SpikeLog.shared.log(
                    "CHAIN STOPPED at index \(alarm.indexInChain) after \(succeeded) successful schedules"
                )
                break
            }
        }
        SpikeLog.shared.log("--- chain result: \(succeeded)/\(planned.count) scheduled ---")
    }

    @discardableResult
    private func schedule(_ planned: PlannedAlarm) async -> Bool {
        do {
            let stopButton = AlarmButton(
                text: "Stop",
                textColor: .white,
                systemImageName: "stop.circle"
            )

            // The secondary button is the only route from the lock screen into the
            // app. iOS always renders the Stop button too, and that cannot be
            // removed — the chain is the mitigation, not this button.
            let scanButton = AlarmButton(
                text: "Scan QR",
                textColor: .white,
                systemImageName: "qrcode.viewfinder"
            )

            let alert = AlarmPresentation.Alert(
                title: LocalizedStringResource(stringLiteral: planned.stage.alertTitle),
                stopButton: stopButton,
                secondaryButton: scanButton,
                // SPIKE-VERIFY: exact case name for the custom (open-app) behaviour.
                // Documented that a secondary button can run an App Intent with
                // openAppWhenRun = true; the enum case spelling is unconfirmed.
                secondaryButtonBehavior: .custom
            )

            let metadata = WakeMetadata(
                chainID: planned.chainID,
                stage: planned.stage,
                indexInChain: planned.indexInChain
            )

            let attributes = AlarmAttributes<WakeMetadata>(
                presentation: AlarmPresentation(alert: alert),
                metadata: metadata,
                tintColor: planned.stage.tint
            )

            // SPIKE-VERIFY: AlertSound factory name and whether a bare filename or a
            // filename-with-extension is expected. Also whether .wav is accepted at
            // all — if not, convert with `afconvert -f caff -d LEI16 in.wav out.caf`
            // and change these to .caf (see docs/mac-setup.md).
            let sound = AlertConfiguration.AlertSound.named(planned.soundFileName)

            // SPIKE-VERIFY: this is the least certain line in the file. Documentation
            // describes AlarmConfiguration as holding schedule, attributes and sound,
            // but the exact initializer/factory shape (and how the App Intent for the
            // secondary button is attached) could not be confirmed from Windows.
            let configuration = AlarmConfiguration(
                schedule: .fixed(planned.fireDate),
                attributes: attributes,
                secondaryIntent: OpenWakeIntent(stageRaw: planned.stage.rawValue),
                sound: sound
            )

            try await AlarmManager.shared.schedule(id: planned.id, configuration: configuration)

            scheduledIDs.append(planned.id)
            persist()
            return true
        } catch {
            record(error, context: "schedule index \(planned.indexInChain)")
            return false
        }
    }

    // MARK: Cancelling

    /// Called on a verified QR scan. This is the only thing that ends the morning.
    func cancelAll(reason: String) async {
        SpikeLog.shared.log("cancelAll(\(reason)) — \(scheduledIDs.count) alarms")
        for id in scheduledIDs {
            do {
                // SPIKE-VERIFY: `cancel(id:)` — documented as available alongside
                // stop/pause/resume; throwing/async-ness unconfirmed.
                try AlarmManager.shared.cancel(id: id)
            } catch {
                record(error, context: "cancel \(id)")
            }
        }
        scheduledIDs.removeAll()
        persist()
        SpikeLog.shared.log("cancelAll complete")
    }

    // MARK: Errors

    private func record(_ error: Error, context: String) {
        let message = "\(context): \(error.localizedDescription)"
        lastError = message
        SpikeLog.shared.log("ERROR \(message)")
    }
}
