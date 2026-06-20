import CoreNFC
import SwiftUI

@Observable
@MainActor
final class NFCManager: NSObject {
    static let shared = NFCManager()

    enum ScanState: Equatable {
        case idle
        case scanning
        case found(NFCTagRecord)
        case unknownUID(String)
        case unavailable
        case error(String)
    }

    var scanState: ScanState = .idle

    private var session: NFCTagReaderSession?

    func startScan() {
        guard NFCTagReaderSession.readingAvailable else {
            scanState = .unavailable
            return
        }
        scanState = .scanning
        session = NFCTagReaderSession(
            pollingOption: [.iso14443, .iso15693, .iso18092],
            delegate: self,
            queue: .global(qos: .userInitiated)
        )
        session?.alertMessage = "Hold your device near a totem to scan it."
        session?.begin()
    }

    func dismiss() {
        scanState = .idle
    }
}

// MARK: - NFCTagReaderSessionDelegate
extension NFCManager: NFCTagReaderSessionDelegate {

    nonisolated func tagReaderSessionDidBecomeActive(_ session: NFCTagReaderSession) {}

    nonisolated func tagReaderSession(
        _ session: NFCTagReaderSession,
        didInvalidateWithError error: Error
    ) {
        if let nfcError = error as? NFCReaderError {
            switch nfcError.code {
            case .readerSessionInvalidationErrorUserCanceled,
                 .readerSessionInvalidationErrorSessionTerminatedUnexpectedly:
                Task { @MainActor [weak self] in self?.scanState = .idle }
                return
            default:
                break
            }
        }
        Task { @MainActor [weak self] in
            self?.scanState = .error(error.localizedDescription)
        }
    }

    nonisolated func tagReaderSession(
        _ session: NFCTagReaderSession,
        didDetectTags tags: [NFCTag]
    ) {
        guard let tag = tags.first else { return }

        session.connect(to: tag) { [weak self] error in
            guard let self else { return }

            if let error {
                session.invalidate(errorMessage: "Failed to connect to tag.")
                Task { @MainActor [weak self] in
                    self?.scanState = .error("Connection failed: \(error.localizedDescription)")
                }
                return
            }

            let uid = self.extractUID(from: tag)

            guard !uid.isEmpty else {
                session.invalidate(errorMessage: "Unreadable tag type.")
                Task { @MainActor [weak self] in self?.scanState = .error("Unreadable tag type.") }
                return
            }

            session.alertMessage = "Tag read. Looking up totem…"
            session.invalidate()

            Task { @MainActor [weak self] in
                await self?.resolveUID(uid)
            }
        }
    }

    nonisolated private func extractUID(from tag: NFCTag) -> String {
        let data: Data
        switch tag {
        case .iso7816(let t):  data = t.identifier
        case .iso15693(let t): data = t.identifier
        case .feliCa(let t):   data = t.currentIDm
        case .miFare(let t):   data = t.identifier
        @unknown default:      return ""
        }
        return data.map { String(format: "%02X", $0) }.joined()
    }

    @MainActor
    private func resolveUID(_ uid: String) async {
        do {
            if let record = try await SupabaseManager.shared.lookupNFCTag(uid: uid) {
                scanState = .found(record)
            } else {
                scanState = .unknownUID(uid)
            }
        } catch {
            scanState = .error("Lookup failed: \(error.localizedDescription)")
        }
    }
}
