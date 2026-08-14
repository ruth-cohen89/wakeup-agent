import Foundation
import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit

/// Owns the kitchen QR token: generation, persistence, validation, and rendering
/// a printable image.
///
/// The token is a random UUID generated on this installation, never a predictable
/// string like "WAKE_UP", and never any backend credential — the QR is a physical
/// proof-of-location device, not an authentication secret.
@MainActor
@Observable
final class QRTokenStore {

    static let shared = QRTokenStore()

    private let tokenKey = "wakespike.qr.token"
    private let versionKey = "wakespike.qr.version"

    private(set) var token: String
    private(set) var version: Int

    /// Scheme is app-specific so a random QR code in the wild cannot match.
    static let scheme = "wake-agent"

    private init() {
        let defaults = UserDefaults.standard
        if let existing = defaults.string(forKey: tokenKey) {
            token = existing
            version = defaults.integer(forKey: versionKey)
        } else {
            token = UUID().uuidString
            version = 1
            defaults.set(token, forKey: tokenKey)
            defaults.set(version, forKey: versionKey)
        }
    }

    /// The exact string encoded into the printed QR code.
    var payload: String {
        "\(Self.scheme)://verify/\(token)"
    }

    /// Regenerating invalidates the printed code immediately — the old token is
    /// overwritten, so a previously printed QR stops matching.
    func regenerate() {
        token = UUID().uuidString
        version += 1
        UserDefaults.standard.set(token, forKey: tokenKey)
        UserDefaults.standard.set(version, forKey: versionKey)
        SpikeLog.shared.log("QR token regenerated (version \(version)) — previous printout is now invalid")
    }

    /// Constant-time-ish comparison is unnecessary here (no attacker, no secret of
    /// value), but exact matching is: a partial or prefix match must not verify.
    func matches(scanned: String) -> Bool {
        scanned == payload
    }

    /// Renders the payload as a QR image suitable for printing.
    func makeQRImage(sidePixels: CGFloat = 720) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(payload.utf8)
        // High error correction so a smudged or partly-lit kitchen printout still scans.
        filter.correctionLevel = "H"

        guard let output = filter.outputImage else { return nil }

        let scale = sidePixels / output.extent.width
        let scaled = output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))

        let context = CIContext()
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
