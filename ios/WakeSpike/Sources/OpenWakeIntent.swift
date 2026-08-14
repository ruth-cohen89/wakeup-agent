import Foundation
import AppIntents

/// The lock-screen secondary button runs this intent to bring the app forward
/// into the wake flow.
///
/// This is the *only* path from the alarm alert into the app. iOS also renders a
/// Stop button that dismisses the alarm without launching anything, and there is
/// no API to suppress it — see docs/architecture.md.
struct OpenWakeIntent: AppIntent {

    static var title: LocalizedStringResource = "Open wake-up"
    static var description = IntentDescription("Opens WakeSpike at the QR verification screen.")

    /// Documented behaviour: an App Intent attached to an alarm's secondary button
    /// can bring the app to the foreground when this is true.
    static var openAppWhenRun: Bool = true

    @Parameter(title: "Stage")
    var stageRaw: String

    init() {
        self.stageRaw = WakeStage.gentle.rawValue
    }

    init(stageRaw: String) {
        self.stageRaw = stageRaw
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        SpikeLog.shared.log("OpenWakeIntent fired (stage=\(stageRaw)) — app opened from alarm")
        WakeRouter.shared.enterWakeFlow(stageRaw: stageRaw)
        return .result()
    }
}

/// Routes the app to the wake screen when launched from an alarm.
@MainActor
@Observable
final class WakeRouter {
    static let shared = WakeRouter()

    var isInWakeFlow = false
    var stage: WakeStage = .gentle
    /// When the alarm-triggered launch happened, to the second.
    var enteredAt: Date?

    private init() {}

    func enterWakeFlow(stageRaw: String) {
        stage = WakeStage(rawValue: stageRaw) ?? .gentle
        enteredAt = Date()
        isInWakeFlow = true
    }

    func exitWakeFlow() {
        isInWakeFlow = false
        enteredAt = nil
    }
}
