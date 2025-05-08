import Foundation
import Network

// MARK: - Network Monitoring
class NetworkMonitor {
    static let shared = NetworkMonitor()
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    private(set) var isConnected = true
    
    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let newConnectionState = path.status == .satisfied
            
            DispatchQueue.main.async {
                self?.isConnected = newConnectionState
                NotificationCenter.default.post(
                    name: Notification.Name("connectivityChanged"),
                    object: newConnectionState
                )
            }
        }
        monitor.start(queue: queue)
    }
    
    deinit {
        monitor.cancel()
    }
}
