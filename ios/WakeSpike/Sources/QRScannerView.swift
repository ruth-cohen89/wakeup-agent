import SwiftUI
import AVFoundation

/// Live-camera-only QR scanner.
///
/// Deliberately built on AVCaptureSession with a camera input and nothing else.
/// There is no photo-library picker, no file import, no manual code entry, and no
/// "I'm awake" button anywhere in this view or its callers. The entire point of
/// the QR is proof that the phone — and therefore you — physically reached the
/// kitchen. Any import path would defeat it, so none exists to be tempted by.
struct QRScannerView: UIViewControllerRepresentable {

    /// Called with the decoded string on every detection; the caller decides
    /// whether it matches the stored token.
    let onScan: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onScan: onScan)
    }

    func makeUIViewController(context: Context) -> ScannerViewController {
        let controller = ScannerViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: ScannerViewController, context: Context) {}

    final class Coordinator: NSObject, ScannerViewControllerDelegate {
        private let onScan: (String) -> Void
        /// Detection fires many times a second; only act on the first.
        private var hasFired = false

        init(onScan: @escaping (String) -> Void) {
            self.onScan = onScan
        }

        func scanner(_ controller: ScannerViewController, didRead value: String) {
            guard !hasFired else { return }
            hasFired = true
            onScan(value)
        }
    }
}

protocol ScannerViewControllerDelegate: AnyObject {
    func scanner(_ controller: ScannerViewController, didRead value: String)
}

final class ScannerViewController: UIViewController {

    weak var delegate: ScannerViewControllerDelegate?

    private let session = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private let sessionQueue = DispatchQueue(label: "wakespike.camera")

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        configureSession()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        sessionQueue.async { [session] in
            if !session.isRunning { session.startRunning() }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sessionQueue.async { [session] in
            if session.isRunning { session.stopRunning() }
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    private func configureSession() {
        session.beginConfiguration()

        guard
            let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
            let input = try? AVCaptureDeviceInput(device: device),
            session.canAddInput(input)
        else {
            SpikeLog.shared.log("ERROR camera unavailable — check NSCameraUsageDescription and permission")
            session.commitConfiguration()
            return
        }
        session.addInput(input)

        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else {
            SpikeLog.shared.log("ERROR could not add metadata output")
            session.commitConfiguration()
            return
        }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        // Set only after adding the output, otherwise the type is not yet available.
        output.metadataObjectTypes = [.qr]

        session.commitConfiguration()

        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        layer.frame = view.bounds
        view.layer.addSublayer(layer)
        previewLayer = layer
    }
}

extension ScannerViewController: AVCaptureMetadataOutputObjectsDelegate {
    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard
            let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
            object.type == .qr,
            let value = object.stringValue
        else { return }

        delegate?.scanner(self, didRead: value)
    }
}
