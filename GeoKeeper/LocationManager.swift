import Foundation
import CoreLocation
import SwiftUI
import SwiftData // Required for ModelContext and model types
import Combine // <-- FIX: Added to resolve ObservableObject/Published errors

/// Manages Core Location services, including user location and geofencing.
class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    
    // MARK: - Published Properties (Requires Combine)
    /// The current authorization status for location services.
    @Published private(set) var authorizationStatus: CLAuthorizationStatus?
    /// The user's current location.
    @Published private(set) var userLocation: CLLocation?
    
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
    
    /// Injects the ModelContext from the App's environment.
    /// - Parameter context: The SwiftData ModelContext for data operations.
    func updateContext(context: ModelContext) {
        self.modelContext = context
        // Load existing regions and start monitoring them only once the context is set
        loadAndStartMonitoringRegions()
    }
    
    /// Loads all existing TrackedLocations from SwiftData and starts Core Location monitoring for each.
    private func loadAndStartMonitoringRegions() {
        guard let context = modelContext else {
#if DEBUG
            print("ModelContext not set. Cannot load regions.")
#endif
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
#if DEBUG
            print("Failed to load existing TrackedLocations: \(error)")
#endif
        }
    }
    
    // MARK: - Geofencing
    
    /// Starts monitoring a geofence region for a given tracked location.
    /// - Parameter location: The TrackedLocation whose region should be monitored.
    func startMonitoring(location: TrackedLocation) {
        let region = location.region
        
        // Configuration for Geofence notifications
        region.notifyOnEntry = true
        region.notifyOnExit = true
        
        if CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self) {
            manager.startMonitoring(for: region)
#if DEBUG
            print("Monitoring started for: \(location.name) (\(location.id.uuidString))")
#endif
        } else {
#if DEBUG
            print("Geofencing not available on this device.")
#endif
        }
    }
    
    /// Stops monitoring the geofence region associated with a given tracked location.
    /// - Parameter location: The TrackedLocation whose region monitoring should be stopped.
    func stopMonitoring(location: TrackedLocation) {
        let regionIdentifier = location.id.uuidString
        let circularRegions = manager.monitoredRegions.compactMap { $0 as? CLCircularRegion }
        if let region = circularRegions.first(where: { $0.identifier == regionIdentifier }) {
            manager.stopMonitoring(for: region)
#if DEBUG
            print("Monitoring stopped for: \(location.name) (\(regionIdentifier))")
#endif
        }
    }
    
    // MARK: - CLLocationManagerDelegate
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        userLocation = locations.last
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        self.authorizationStatus = status
        
        if status != .authorizedAlways {
#if DEBUG
            print("Warning: Geofencing requires 'Always' authorization.")
#endif
        }
    }
    
    func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
#if DEBUG
        print("Monitoring failed for region \(region?.identifier ?? "unknown"): \(error.localizedDescription)")
#endif
    }
    
    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
#if DEBUG
        print("Did Enter Region: \(region.identifier)")
#endif
        handleRegionEntry(region: region)
    }
    
    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
#if DEBUG
        print("Did Exit Region: \(region.identifier)")
#endif
        handleRegionExit(region: region)
    }

    // MARK: - Persistence Handlers
    
    /// Handles updating the entry time of a tracked location upon region entry.
    /// - Parameter region: The region that was entered.
    private func handleRegionEntry(region: CLRegion) {
        guard let context = modelContext,
              let uuid = UUID(uuidString: region.identifier) else {
#if DEBUG
            print("Context or UUID missing for region entry: \(region.identifier)")
#endif
            return
        }
        
        do {
            // Find the tracked location using its UUID ID
            let descriptor = FetchDescriptor<TrackedLocation>(predicate: #Predicate { $0.id == uuid })
            guard let location = try context.fetch(descriptor).first else {
#if DEBUG
                print("Could not find TrackedLocation with ID: \(region.identifier)")
#endif
                return
            }
            
            // Update the entry time
            location.entryTime = Date()
#if DEBUG
            print("Updated \(location.name) entryTime to \(location.entryTime!)")
#endif
            
            try context.save()
        } catch {
#if DEBUG
            print("Failed to handle region entry persistence: \(error)")
#endif
        }
    }
    
    /// Handles creation of a LocationLog and clearing the entry time upon region exit.
    /// - Parameter region: The region that was exited.
    private func handleRegionExit(region: CLRegion) {
        guard let context = modelContext,
              let uuid = UUID(uuidString: region.identifier) else {
#if DEBUG
            print("Context or UUID missing for region exit: \(region.identifier)")
#endif
            return
        }
        
        do {
            // Find the tracked location
            let descriptor = FetchDescriptor<TrackedLocation>(predicate: #Predicate { $0.id == uuid })
            guard let location = try context.fetch(descriptor).first,
                  let entryTime = location.entryTime else {
#if DEBUG
                print("Could not find TrackedLocation or entryTime for exit: \(region.identifier)")
#endif
                return
            }
            
            let exitTime = Date()
            
            // 1. Create and insert the LocationLog
            let newLog = LocationLog(locationName: location.name, entry: entryTime, exit: exitTime)
            context.insert(newLog)
            
            // 2. Clear the entry time on the TrackedLocation (marking it inactive)
            location.entryTime = nil
#if DEBUG
            print("Created LocationLog for \(location.name). Duration: \(newLog.durationString)")
#endif

            try context.save()
        } catch {
#if DEBUG
            print("Failed to handle region exit persistence: \(error)")
#endif
        }
    }
}
