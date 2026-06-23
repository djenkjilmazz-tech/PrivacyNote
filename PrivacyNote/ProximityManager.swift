import UIKit

@Observable
final class ProximityManager {
    private(set) var isNear: Bool = false
    private var observer: NSObjectProtocol?

    func startMonitoring() {
        UIDevice.current.isProximityMonitoringEnabled = true
        isNear = UIDevice.current.proximityState
        observer = NotificationCenter.default.addObserver(
            forName: UIDevice.proximityStateDidChangeNotification,
            object: UIDevice.current,
            queue: .main
        ) { [weak self] _ in
            self?.isNear = UIDevice.current.proximityState
        }
    }

    func stopMonitoring() {
        UIDevice.current.isProximityMonitoringEnabled = false
        if let o = observer {
            NotificationCenter.default.removeObserver(o)
            observer = nil
        }
        isNear = false
    }
}
