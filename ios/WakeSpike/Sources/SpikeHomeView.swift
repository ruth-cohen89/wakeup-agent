import SwiftUI

/// The spike control panel. Every row maps to a numbered test in
/// docs/00-phase0-spike.md, so the device session is "tap down the list".
struct SpikeHomeView: View {

    @State private var alarms = AlarmService.shared
    @State private var log = SpikeLog.shared
    @State private var qr = QRTokenStore.shared

    @State private var showingQR = false
    @State private var showingLog = false
    @State private var capTestCount = 5
    @State private var selfCheckResult: String?
    @State private var repeatingTime = Date()

    var body: some View {
        NavigationStack {
            List {
                authorizationSection
                singleAlarmSection
                capTestSection
                chainSection
                rebootSection
                repeatingSection
                qrSection
                logSection
            }
            .navigationTitle("WakeSpike")
            .sheet(isPresented: $showingQR) { qrSheet }
            .sheet(isPresented: $showingLog) { logSheet }
            .onAppear {
                alarms.refreshAuthorizationState()
                Task { await alarms.refreshLiveAlarmCount() }
            }
        }
    }

    // MARK: Test 1

    private var authorizationSection: some View {
        Section {
            LabeledContent("State", value: alarms.authorizationText)
            Button("Request AlarmKit authorization") {
                Task { await alarms.requestAuthorization() }
            }
            Button("Refresh state") { alarms.refreshAuthorizationState() }
        } header: {
            Text("Test 1 — Authorization")
        } footer: {
            Text("Then deny in Settings ▸ WakeSpike and refresh, to see what a revoked permission looks like.")
        }
    }

    // MARK: Tests 2, 3

    private var singleAlarmSection: some View {
        Section {
            ForEach(WakeStage.allCases, id: \.self) { stage in
                Button {
                    Task { await alarms.scheduleSingle(secondsFromNow: 60, stage: stage) }
                } label: {
                    HStack {
                        Circle().fill(stage.tint).frame(width: 10, height: 10)
                        Text(stage.rawValue.capitalized)
                        Spacer()
                        Text(stage.soundFileName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        } header: {
            Text("Tests 2–3 — Single alarm, +60s")
        } footer: {
            Text("Schedule one, lock the phone, put it down. Confirm it fires locked, note whether the sound loops until you slide Stop, and whether it plays at all (WAV acceptance).")
        }
    }

    // MARK: Test 4 — the gate

    /// What a real 08:00 morning actually costs in alarms, at 2-minute spacing
    /// through to 09:30. This is the number Test 4 has to clear.
    private var realMorningDemand: Int {
        ChainPlanner.plan(
            start: Date(),
            spacingSeconds: 120,
            totalMinutes: 90
        ).count
    }

    private var capTestSection: some View {
        Section {
            LabeledContent("A real morning needs", value: "\(realMorningDemand) alarms")
                .font(.subheadline.bold())
            Stepper("Schedule \(capTestCount) alarms", value: $capTestCount, in: 1...200, step: 5)
            Button("Run cap test (\(capTestCount))") {
                // Far enough out that they don't actually ring during the test.
                let start = Date().addingTimeInterval(60 * 60)
                let planned = ChainPlanner.compressedPlan(
                    start: start,
                    spacingSeconds: 60,
                    count: capTestCount
                )
                Task { await alarms.scheduleChain(planned) }
            }
            LabeledContent("App believes scheduled", value: "\(alarms.scheduledIDs.count)")
            LabeledContent("iOS actually holds", value: liveCountText)
                .font(.subheadline.bold())
            Button("Refresh from AlarmKit") {
                Task { await alarms.refreshLiveAlarmCount() }
            }
            if let error = alarms.lastError {
                Text(error).font(.caption).foregroundStyle(.red)
            }
            Button("Cancel all", role: .destructive) {
                Task { await alarms.cancelAll(reason: "manual") }
            }
        } header: {
            Text("Test 4 — Maximum alarm count ⚠️")
        } footer: {
            Text("The blocker. Try 5, 20, 50, 100. Watch 'iOS actually holds' and the log for where it stops — the app's own count only records schedule calls that returned success. If the cap is below the real-morning number above, the chain design has to change. Cancel all between runs.")
        }
    }

    /// `nil` means the AlarmKit query itself failed, which is a different — and more
    /// interesting — result than zero alarms.
    private var liveCountText: String {
        alarms.liveAlarmCount.map(String.init) ?? "query failed"
    }

    // MARK: Test 5

    private var chainSection: some View {
        Section {
            Button("Chain of 5, 2 min apart, starting in 1 min") {
                let start = Date().addingTimeInterval(60)
                let planned = ChainPlanner.compressedPlan(start: start, spacingSeconds: 120, count: 5)
                Task { await alarms.scheduleChain(planned) }
            }
            Button("Compressed chain: 6 alarms, 20s apart") {
                let start = Date().addingTimeInterval(30)
                let planned = ChainPlanner.compressedPlan(start: start, spacingSeconds: 20, count: 6)
                Task { await alarms.scheduleChain(planned) }
            }
        } header: {
            Text("Test 5 — Stop independence")
        } footer: {
            Text("Slide Stop on the first alarm. The second must still fire. This is the single behaviour the whole 'keep trying after 08:15' design rests on.")
        }
    }

    // MARK: Test 9

    private var rebootSection: some View {
        Section {
            Button("Chain of 5, 2 min apart, starting in 10 min") {
                let start = Date().addingTimeInterval(10 * 60)
                let planned = ChainPlanner.compressedPlan(start: start, spacingSeconds: 120, count: 5)
                Task { await alarms.scheduleChain(planned) }
            }
        } header: {
            Text("Test 9 — Survival across reboot")
        } footer: {
            Text("Ten minutes is the point: long enough to power the phone fully off and back on before the first alarm is due, short enough not to lose the session waiting. Schedule, power off, wait a minute, power on, and do not open the app.")
        }
    }

    // MARK: Test 11

    private var repeatingSection: some View {
        Section {
            DatePicker(
                "Fire at",
                selection: $repeatingTime,
                displayedComponents: .hourAndMinute
            )
            Button("Schedule repeating Sun–Thu alarm") {
                let parts = Calendar.current.dateComponents([.hour, .minute], from: repeatingTime)
                Task {
                    await alarms.scheduleRepeatingWeekly(
                        hour: parts.hour ?? 8,
                        minute: parts.minute ?? 0
                    )
                }
            }
        } header: {
            Text("Test 11 — Repeating weekly alarm")
        } footer: {
            Text("The escape route if Test 4 finds a low cap. One repeating alarm that re-arms itself after Stop would make a production morning cost a handful of alarms instead of \(realMorningDemand). Set a time two minutes out, let it fire, slide Stop, and check tomorrow — or just confirm it schedules at all.")
        }
    }

    // MARK: Tests 7, 8

    private var qrSection: some View {
        Section {
            Button("Show / print kitchen QR") { showingQR = true }
            LabeledContent("Token version", value: "\(qr.version)")
            Button("Regenerate token", role: .destructive) {
                qr.regenerate()
            }
            NavigationLink("Open scanner directly") {
                ScanScreen()
            }
        } header: {
            Text("Tests 7–8 — QR verification")
        } footer: {
            Text("Print the code and tape it in the kitchen. Regenerating invalidates the printed copy immediately. Scanning a valid code cancels every remaining alarm in the chain.")
        }
    }

    private var logSection: some View {
        Section {
            Button("Run planner self-check") {
                let failures = ChainPlanner.selfCheck()
                if failures.isEmpty {
                    selfCheckResult = "PASS — all stage boundaries correct"
                    SpikeLog.shared.log("planner self-check PASS")
                } else {
                    selfCheckResult = "FAIL — " + failures.joined(separator: "; ")
                    SpikeLog.shared.log("planner self-check FAIL: \(failures.joined(separator: "; "))")
                }
            }
            if let result = selfCheckResult {
                Text(result)
                    .font(.caption)
                    .foregroundStyle(result.hasPrefix("PASS") ? .green : .red)
            }
            Button("View log (\(log.entries.count) entries)") { showingLog = true }
        } header: {
            Text("Results")
        } footer: {
            Text("Run the self-check first — it proves the stage boundaries without needing an alarm to fire. Then share the log and paste it into docs/alarmkit-findings.md.")
        }
    }

    // MARK: Sheets

    private var qrSheet: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if let image = qr.makeQRImage() {
                    Image(uiImage: image)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 320)
                        .padding()
                        .background(.white)
                } else {
                    Text("Could not render QR").foregroundStyle(.red)
                }
                Text("Kitchen verification code")
                    .font(.headline)
                Text("Version \(qr.version)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let image = qr.makeQRImage() {
                    ShareLink(
                        item: Image(uiImage: image),
                        preview: SharePreview("Kitchen QR", image: Image(uiImage: image))
                    ) {
                        Label("Export / print", systemImage: "printer")
                    }
                }
                Spacer()
            }
            .padding()
            .navigationTitle("Kitchen QR")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { showingQR = false }
                }
            }
        }
    }

    private var logSheet: some View {
        NavigationStack {
            List {
                ForEach(log.entries.reversed()) { entry in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.message).font(.callout)
                        Text(SpikeLog.timestamp(entry.at))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Spike log")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { showingLog = false }
                }
                ToolbarItem(placement: .primaryAction) {
                    ShareLink(item: log.exportText) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
    }
}
