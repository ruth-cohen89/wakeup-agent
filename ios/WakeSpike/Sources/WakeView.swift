import SwiftUI

/// The screen the alarm opens into. Colour and copy follow the stage design in
/// spec section 26, so the device session also validates the visual language that
/// Simulation Mode will reuse later.
struct WakeView: View {

    @State private var router = WakeRouter.shared
    @State private var alarms = AlarmService.shared
    @State private var showingScanner = false
    @State private var elapsed: TimeInterval = 0

    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            router.stage.background.ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                Text(router.stage.headline)
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)

                // Never colour alone — the stage is always named in text too.
                Label(router.stage.stateLabel, systemImage: router.stage.symbol)
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.9))

                if let enteredAt = router.enteredAt {
                    VStack(spacing: 4) {
                        Text("Opened at \(SpikeLog.timestamp(enteredAt))")
                        Text("Awake for \(formatted(elapsed))")
                            .monospacedDigit()
                    }
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.85))
                }

                Spacer()

                Text("The alarm stops when you scan the code in the kitchen.")
                    .font(.callout)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.horizontal, 32)

                Button {
                    showingScanner = true
                } label: {
                    Label("Scan kitchen QR", systemImage: "qrcode.viewfinder")
                        .font(.title3.bold())
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.white)
                        .foregroundStyle(.black)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 24)

                // No "I'm awake" button, and no way out of this screen that is not a
                // live scan — closing it is possible only because this is a spike.
                Button("Close (spike only)") {
                    SpikeLog.shared.log("wake screen dismissed WITHOUT scan (spike escape hatch)")
                    router.exitWakeFlow()
                }
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.7))
                .padding(.bottom, 24)
            }
        }
        .fullScreenCover(isPresented: $showingScanner) {
            ScanScreen()
        }
        .onReceive(tick) { _ in
            if let enteredAt = router.enteredAt {
                elapsed = Date().timeIntervalSince(enteredAt)
            }
        }
    }

    private func formatted(_ interval: TimeInterval) -> String {
        let total = Int(interval)
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}

/// Wraps the camera scanner with token validation and the cancel-everything action.
struct ScanScreen: View {

    @Environment(\.dismiss) private var dismiss
    @State private var status: Status = .scanning

    enum Status: Equatable {
        case scanning
        case rejected
        case verified(Date)
    }

    var body: some View {
        ZStack {
            QRScannerView { value in
                handle(value)
            }
            .ignoresSafeArea()

            VStack {
                Spacer()
                banner
                    .padding()
            }
        }
        .overlay(alignment: .topTrailing) {
            Button("Cancel") { dismiss() }
                .padding()
                .foregroundStyle(.white)
        }
    }

    @ViewBuilder
    private var banner: some View {
        switch status {
        case .scanning:
            Text("Point the camera at the kitchen code")
                .padding()
                .background(.black.opacity(0.7))
                .foregroundStyle(.white)
                .clipShape(Capsule())
        case .rejected:
            Label("Not your code", systemImage: "xmark.octagon.fill")
                .padding()
                .background(.red)
                .foregroundStyle(.white)
                .clipShape(Capsule())
        case .verified(let at):
            VStack(spacing: 4) {
                Label("Verified", systemImage: "checkmark.seal.fill")
                    .font(.headline)
                Text(SpikeLog.timestamp(at)).font(.caption).monospacedDigit()
            }
            .padding()
            .background(.green)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private func handle(_ value: String) {
        // Timestamp captured before any async work, so the recorded wake time is
        // the moment of the scan rather than the moment cancellation finished.
        let scannedAt = Date()

        guard QRTokenStore.shared.matches(scanned: value) else {
            status = .rejected
            SpikeLog.shared.log("QR REJECTED (payload did not match stored token)")
            return
        }

        status = .verified(scannedAt)
        SpikeLog.shared.log("QR VERIFIED at \(SpikeLog.timestamp(scannedAt)) — cancelling remaining alarms")

        Task {
            await AlarmService.shared.cancelAll(reason: "qr verified")
            try? await Task.sleep(for: .seconds(1.5))
            WakeRouter.shared.exitWakeFlow()
            dismiss()
        }
    }
}

// MARK: - Stage presentation

extension WakeStage {
    var background: Color {
        switch self {
        case .gentle:      return Color(red: 0.10, green: 0.45, blue: 0.25)
        case .motivation:  return Color(red: 0.70, green: 0.55, blue: 0.05)
        case .aggressive:  return Color(red: 0.80, green: 0.30, blue: 0.05)
        case .postFailure: return Color(red: 0.45, green: 0.05, blue: 0.05)
        }
    }

    var headline: String {
        switch self {
        case .gentle:      return "Good morning"
        case .motivation:  return "Time to move"
        case .aggressive:  return "Final minutes"
        case .postFailure: return "Get up and finish this"
        }
    }

    var stateLabel: String {
        switch self {
        case .gentle:      return "PERFECT WINDOW"
        case .motivation:  return "SUCCESS WINDOW"
        case .aggressive:  return "FINAL 5 MINUTES"
        case .postFailure: return "FAILED — VERIFICATION STILL REQUIRED"
        }
    }

    var symbol: String {
        switch self {
        case .gentle:      return "sun.horizon.fill"
        case .motivation:  return "figure.walk"
        case .aggressive:  return "exclamationmark.triangle.fill"
        case .postFailure: return "xmark.octagon.fill"
        }
    }
}
