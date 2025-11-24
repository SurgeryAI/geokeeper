import Foundation
import CoreLocation
import SwiftUI
import SwiftData // Required for ModelContext and model types
import Combine // <-- FIX: Added to resolve ObservableObject/Published errors

/// Manages Core Location services, including user location and geofencing.
class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    
    // MARK: - Published Properties (Requires Combine)
    @Published var authorizationStatus: CLAuthorizationStatus?
    @Published var userLocation: CLLocation?
    
    // MARK: - SwiftData Context
    private var modelContext: ModelContext?
    
    override init() {
        super.init()
        manager.delegate = self
        manager.allowsBackgroundLocationUpdates = true
        manager.desiredAccuracy = kCLLocationAccuracyBest
        
        // Request necessary permissions
        manager.requestAlwaysAuthorization()
        manager.startUpdatingLocation()
    }
    
    // MARK: - SwiftData Integration
    
    /// Called from the App's environment to inject the ModelContext.
    func updateContext(context: ModelContext) {
        self.modelContext = context
        // Load existing regions and start monitoring them only once the context is set
        loadAndStartMonitoringRegions()
    }
    
    /// Loads all existing TrackedLocations from SwiftData and starts Core Location monitoring for each.
    private func loadAndStartMonitoringRegions() {
        guard let context = modelContext else {
            print("ModelContext not set. Cannot load regions.")
            return
        }
        
        do {
            let descriptor = FetchDescriptor<TrackedLocation>()
            let existingLocations = try context.fetch(descriptor)
            
            // Clear any old regions first (optional, but safer)
            for region in manager.monitoredRegions {
                manager.stopMonitoring(for: region)
            }
            
            for location in existingLocations {
                startMonitoring(location: location)
            }
        } catch {
            print("Failed to load existing TrackedLocations: \(error)")
        }
    }
    
    // MARK: - Geofencing
    
    func startMonitoring(location: TrackedLocation) {
        let region = location.region
        
        // Configuration for Geofence notifications
        region.notifyOnEntry = true
        region.notifyOnExit = true
        
        if CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self) {
            manager.startMonitoring(for: region)
            print("Monitoring started for: \(location.name) (\(location.id.uuidString))")
        } else {
            print("Geofencing not available on this device.")
        }
    }
    
    func stopMonitoring(location: TrackedLocation) {
        let regionIdentifier = location.id.uuidString
        if let monitoredRegions = manager.monitoredRegions as? Set<CLCircularRegion> {
            if let region = monitoredRegions.first(where: { $0.identifier == regionIdentifier }) {
                manager.stopMonitoring(for: region)
                print("Monitoring stopped for: \(location.name) (\(regionIdentifier))")
            }
        }
    }
    
    // MARK: - CLLocationManagerDelegate
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        userLocation = locations.last
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        self.authorizationStatus = status
        
        if status != .authorizedAlways {
            print("Warning: Geofencing requires 'Always' authorization.")
        }
    }
    
    func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
        print("Monitoring failed for region \(region?.identifier ?? "unknown"): \(error.localizedDescription)")
    }
    
    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        print("Did Enter Region: \(region.identifier)")
        handleRegionEntry(region: region)
    }
    
    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        print("Did Exit Region: \(region.identifier)")
        handleRegionExit(region: region)
    }

    // MARK: - Persistence Handlers
    
    /// Finds the TrackedLocation and updates its entryTime upon region entry.
    private func handleRegionEntry(region: CLRegion) {
        guard let context = modelContext,
              let uuid = UUID(uuidString: region.identifier) else {
            print("Context or UUID missing for region entry: \(region.identifier)")
            return
        }
        
        do {
            // Find the tracked location using its UUID ID
            let descriptor = FetchDescriptor<TrackedLocation>(predicate: #Predicate { $0.id == uuid })
            guard let location = try context.fetch(descriptor).first else {
                print("Could not find TrackedLocation with ID: \(region.identifier)")
                return
            }
            
            // Update the entry time
            location.entryTime = Date()
            print("Updated \(location.name) entryTime to \(location.entryTime!)")
            
            try context.save()
        } catch {
            print("Failed to handle region entry persistence: \(error)")
        }
    }
    
    /// Finds the TrackedLocation, creates a LocationLog, and saves both upon region exit.
    private func handleRegionExit(region: CLRegion) {
        guard let context = modelContext,
              let uuid = UUID(uuidString: region.identifier) else {
            print("Context or UUID missing for region exit: \(region.identifier)")
            return
        }
        
        do {
            // Find the tracked location
            let descriptor = FetchDescriptor<TrackedLocation>(predicate: #Predicate { $0.id == uuid })
            guard let location = try context.fetch(descriptor).first,
                  let entryTime = location.entryTime else {
                print("Could not find TrackedLocation or entryTime for exit: \(region.identifier)")
                return
            }
            
            let exitTime = Date()
            
            // 1. Create and insert the LocationLog
            let newLog = LocationLog(locationName: location.name, entry: entryTime, exit: exitTime)
            context.insert(newLog)
            
            // 2. Clear the entry time on the TrackedLocation (marking it inactive)
            location.entryTime = nil
            print("Created LocationLog for \(location.name). Duration: \(newLog.durationString)")

            try context.save()
        } catch {
            print("Failed to handle region exit persistence: \(error)")
        }
    }
}
