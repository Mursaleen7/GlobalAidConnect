import Foundation
import CoreLocation

// MARK: - Location Manager
class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    @Published var lastLocation: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var locationError: String?
    @Published var isInitialized = false
    
    // Default location to use when actual location is unavailable
    let defaultLocation = CLLocation(latitude: 37.7749, longitude: -122.4194) // San Francisco
    
    override init() {
        super.init()
        
        // Configure location manager
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 10 // Update every 10 meters
        
        // Initialize with current authorization status
        if #available(iOS 14.0, *) {
            authorizationStatus = locationManager.authorizationStatus
        } else {
            authorizationStatus = CLLocationManager.authorizationStatus()
        }
        
        // Dispatch to background queue to avoid main thread warning
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.checkAndStartUpdatingLocationIfAuthorized()
            
            DispatchQueue.main.async {
                self?.isInitialized = true
            }
        }
    }
    
    func requestAuthorization() {
        // Always perform authorization requests on the main thread
        if !Thread.isMainThread {
            DispatchQueue.main.async { [weak self] in
                self?.requestAuthorization()
            }
            return
        }
        
        // Only request authorization if we haven't already
        if authorizationStatus == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        } else if authorizationStatus == .denied || authorizationStatus == .restricted {
            // If authorization is denied, notify and use default location
            self.locationError = "Location permission denied. Using default location."
            self.lastLocation = defaultLocation
        } else {
            // If already authorized, start updates
            startUpdatingLocation()
        }
    }
    
    func startUpdatingLocation() {
        if CLLocationManager.locationServicesEnabled() {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                DispatchQueue.main.async {
                    self?.locationManager.startUpdatingLocation()
                }
            }
        } else {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.locationError = "Location services are disabled. Using default location."
                self.lastLocation = self.defaultLocation
            }
        }
    }
    
    func stopUpdatingLocation() {
        locationManager.stopUpdatingLocation()
    }
    
    private func checkAndStartUpdatingLocationIfAuthorized() {
        // This method should now only be called from location delegate methods
        let status: CLAuthorizationStatus
        
        if #available(iOS 14.0, *) {
            status = locationManager.authorizationStatus
        } else {
            status = CLLocationManager.authorizationStatus()
        }
        
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            // Ensure we're on a background thread for performance
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                DispatchQueue.main.async {
                    self?.locationManager.startUpdatingLocation()
                }
            }
        } else if status == .denied || status == .restricted {
            // Use default location if permissions denied
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.locationError = "Location access not granted. Using default location."
                self.lastLocation = self.defaultLocation
            }
        }
        // If status is still .notDetermined, we'll wait for the callback
    }
    
    // MARK: CLLocationManagerDelegate methods
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        // Only update if accuracy is reasonable
        if location.horizontalAccuracy >= 0 {
            DispatchQueue.main.async { [weak self] in
                self?.lastLocation = location
                self?.locationError = nil
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location manager failed with error: \(error.localizedDescription)")
        
        // Handle different error types
        if let clError = error as? CLError {
            switch clError.code {
            case .denied:
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.locationError = "Location access denied. Using default location."
                    self.lastLocation = self.defaultLocation
                }
            case .locationUnknown:
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.locationError = "Unable to determine location. Using last known or default location."
                    if self.lastLocation == nil {
                        self.lastLocation = self.defaultLocation
                    }
                }
            default:
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.locationError = "Location error: \(error.localizedDescription). Using default location."
                    if self.lastLocation == nil {
                        self.lastLocation = self.defaultLocation
                    }
                }
            }
        } else {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.locationError = "Location error: \(error.localizedDescription). Using default location."
                if self.lastLocation == nil {
                    self.lastLocation = self.defaultLocation
                }
            }
        }
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if #available(iOS 14.0, *) {
                self.authorizationStatus = manager.authorizationStatus
            } else {
                self.authorizationStatus = CLLocationManager.authorizationStatus()
            }
        }
        
        checkAndStartUpdatingLocationIfAuthorized()
    }
    
    // For iOS < 14
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        DispatchQueue.main.async { [weak self] in
            self?.authorizationStatus = status
        }
        
        checkAndStartUpdatingLocationIfAuthorized()
    }
}
