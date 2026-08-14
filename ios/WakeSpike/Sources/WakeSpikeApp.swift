import SwiftUI

@main
struct WakeSpikeApp: App {

    @State private var router = WakeRouter.shared

    var body: some Scene {
        WindowGroup {
            SpikeHomeView()
                .fullScreenCover(isPresented: $router.isInWakeFlow) {
                    WakeView()
                }
                .onOpenURL { url in
                    // Fallback launch path: if the App Intent route turns out not to
                    // work on device, a URL scheme still gets us into the wake flow.
                    // Which of the two actually fires is a spike finding.
                    SpikeLog.shared.log("onOpenURL: \(url.absoluteString)")
                    if url.scheme == QRTokenStore.scheme {
                        router.enterWakeFlow(stageRaw: WakeStage.gentle.rawValue)
                    }
                }
        }
    }
}
