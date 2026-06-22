import UIKit

// Watches UIScreen brightness as a proxy for ambient light.
// When iOS auto-brightness dims the screen below the threshold, isLowLight flips true.
@Observable
@MainActor
final class AmbientLightMonitor {
    static let shared = AmbientLightMonitor()

    private(set) var isLowLight: Bool = false

    private var observer: Any?
    private let threshold: CGFloat = 0.3

    private init() {}

    func start() {
        updateState()
        observer = NotificationCenter.default.addObserver(
            forName: UIScreen.brightnessDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateState()
        }
    }

    func stop() {
        if let observer {
            NotificationCenter.default.removeObserver(observer)
        }
        observer = nil
    }

    private func updateState() {
        isLowLight = UIScreen.main.brightness < threshold
    }
}
