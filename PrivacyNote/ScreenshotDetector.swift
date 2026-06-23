import UIKit

@Observable
final class ScreenshotDetector {
    private(set) var didCapture = false
    private var observer: NSObjectProtocol?
    private var resetTask: Task<Void, Never>?

    func startMonitoring() {
        observer = NotificationCenter.default.addObserver(
            forName: UIApplication.userDidTakeScreenshotNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handle()
        }
    }

    func stopMonitoring() {
        if let o = observer {
            NotificationCenter.default.removeObserver(o)
            observer = nil
        }
        resetTask?.cancel()
    }

    private func handle() {
        didCapture = true
        resetTask?.cancel()
        resetTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(3))
            didCapture = false
        }
    }
}
