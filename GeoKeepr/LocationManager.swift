import Combine  // <-- FIX: Added to resolve ObservableObject/Published errors
import CoreLocation
import Foundation
import SwiftData  // Required for ModelContext and model types
import SwiftUI
import UserNotifications  // Required for local notifications

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

        // Defer heavy setup to allow app launch to complete UI rendering first
        DispatchQueue.main.async {
            // Request necessary permissions
            self.manager.requestAlwaysAuthorization()

            // Energy Optimization: Use significant changes for background tracking
            // This is much more battery efficient than startUpdatingLocation()
            self.manager.startMonitoringSignificantLocationChanges()

            // Request notification permissions
            self.requestNotificationPermission()
        }
    }

    // MARK: - Energy Optimization

    /// Starts high-precision location updates. Call this when the Map is visible.
    func startForegroundUpdates() {
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.startUpdatingLocation()
        print("[GeoKeeper] ⚡️ Started high-precision foreground updates")
    }

    /// Stops high-precision updates and reverts to significant change monitoring. Call this when the Map disappears.
    func stopForegroundUpdates() {
        manager.stopUpdatingLocation()
        // Ensure significant changes are still being monitored for geofencing
        manager.startMonitoringSignificantLocationChanges()
        print("[GeoKeeper] 🍃 Stopped foreground updates (reverted to significant changes)")
    }

    // MARK: - Notifications

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) {
            granted, error in
            if let error = error {
                print("Notification permission error: \(error)")
            }
        }
    }

    private func sendNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - SwiftData Integration

    /// Injects the ModelContext from the App's environment.
    /// - Parameter context: The SwiftData ModelContext for data operations.
    func updateContext(context: ModelContext) async {
        print("[GeoKeeper] updateContext called")
        self.modelContext = context
        print("[GeoKeeper] ✅ ModelContext set successfully")
        // Load existing regions and start monitoring them only once the context is set
        await loadAndStartMonitoringRegions()
    }

    /// Loads all existing TrackedLocations from SwiftData and starts Core Location monitoring for each.
    private func loadAndStartMonitoringRegions() async {
        print("[GeoKeeper] loadAndStartMonitoringRegions called")
        guard let context = modelContext else {
            print("[GeoKeeper] ❌ ERROR: ModelContext not set. Cannot load regions.")
            return
        }

        do {
            let descriptor = FetchDescriptor<TrackedLocation>()
            let existingLocations = try context.fetch(descriptor)
            print("[GeoKeeper] Found \(existingLocations.count) existing tracked locations")

            // Clear any old regions first (optional, but safer)
            for region in manager.monitoredRegions {
                manager.stopMonitoring(for: region)
            }

            // Start monitoring on main thread (Core Location requires this)
            await MainActor.run {
                for location in existingLocations {
                    startMonitoring(location: location)
                }
            }
            print(
                "[GeoKeeper] ✅ Finished loading and monitoring \(existingLocations.count) regions")
        } catch {
            print("[GeoKeeper] ❌ ERROR: Failed to load existing TrackedLocations: \(error)")
        }
    }

    // MARK: - Geofencing

    /// Starts monitoring a geofence region for a given tracked location.
    /// - Parameter location: The TrackedLocation whose region should be monitored.
    func startMonitoring(location: TrackedLocation) {
        // Check for region limit (20)
        if manager.monitoredRegions.count >= 20 {
            // Simple eviction policy: Remove an arbitrary region to make space
            if let regionToRemove = manager.monitoredRegions.first {
                manager.stopMonitoring(for: regionToRemove)
                #if DEBUG
                    print("Region limit reached. Stopped monitoring: \(regionToRemove.identifier)")
                #endif
            }
        }

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

    /// Checks if the user is in the specified zone. If so, triggers region entry logic for that zone.
    func checkIfUserIsInZone(_ location: TrackedLocation) {
        guard let userLocation = userLocation else { return }
        let region = location.region
        if region.contains(userLocation.coordinate) && location.entryTime == nil {
            handleRegionEntry(region: region)
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

        if let location = userLocation {
            print(
                "[GeoKeeper] Location updated: \(location.coordinate.latitude), \(location.coordinate.longitude)"
            )

            // Reliability Check: Manually verify zone states
            // This catches missed exit events using significant location changes
            checkZones(for: location)
        }
    }

    /// Checks all tracked zones against the current location to catch missed entry/exit events.
    private func checkZones(for currentLocation: CLLocation) {
        guard let context = modelContext else { return }

        do {
            // Fetch all tracked locations
            let descriptor = FetchDescriptor<TrackedLocation>()
            let trackedLocations = try context.fetch(descriptor)

            for location in trackedLocations {
                // Check for missed EXITS
                // If we think we are inside (entryTime != nil) but we are physically outside
                if location.entryTime != nil {
                    let region = location.region
                    if !region.contains(currentLocation.coordinate) {
                        print(
                            "[GeoKeeper] ⚠️ Detected missed exit for \(location.name). Correcting..."
                        )
                        handleRegionExit(region: region)
                    }
                }
                // Check for missed ENTRIES
                // If we think we are outside (entryTime == nil) but we are physically inside
                else {
                    let region = location.region
                    if region.contains(currentLocation.coordinate) {
                        print(
                            "[GeoKeeper] ⚠️ Detected missed entry for \(location.name). Correcting..."
                        )
                        handleRegionEntry(region: region)
                    }
                }
            }
        } catch {
            print("[GeoKeeper] ❌ Error checking zones: \(error)")
        }
    }

    func locationManager(
        _ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus
    ) {
        self.authorizationStatus = status
        print("[GeoKeeper] Authorization status changed to: \(status.rawValue)")

        if status != .authorizedAlways {
            print(
                "[GeoKeeper] ⚠️ WARNING: Geofencing requires 'Always' authorization. Current: \(status.rawValue)"
            )
        } else {
            print("[GeoKeeper] ✅ 'Always' authorization granted")
        }
    }

    func locationManager(
        _ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error
    ) {
        print(
            "[GeoKeeper] ❌ ERROR: Monitoring failed for region \(region?.identifier ?? "unknown"): \(error.localizedDescription)"
        )
    }

    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        print("[GeoKeeper] 🟢 Did Enter Region: \(region.identifier)")
        handleRegionEntry(region: region)
    }

    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        print("[GeoKeeper] 🔴 Did Exit Region: \(region.identifier)")
        handleRegionExit(region: region)
    }

    // MARK: - Persistence Handlers

    /// Handles updating the entry time of a tracked location upon region entry.
    /// - Parameter region: The region that was entered.
    private func handleRegionEntry(region: CLRegion) {
        print("[GeoKeeper] handleRegionEntry called for region: \(region.identifier)")

        guard let context = modelContext else {
            print("[GeoKeeper] ❌ ERROR: ModelContext is nil in handleRegionEntry")
            return
        }

        guard let uuid = UUID(uuidString: region.identifier) else {
            print("[GeoKeeper] ❌ ERROR: Invalid UUID in region identifier: \(region.identifier)")
            return
        }

        do {
            // Find the tracked location using its UUID ID
            let descriptor = FetchDescriptor<TrackedLocation>(
                predicate: #Predicate { $0.id == uuid })
            guard let location = try context.fetch(descriptor).first else {
                print(
                    "[GeoKeeper] ❌ ERROR: Could not find TrackedLocation with ID: \(region.identifier)"
                )
                return
            }

            // Update the entry time
            location.entryTime = Date()
            print("[GeoKeeper] ✅ Updated \(location.name) entryTime to \(location.entryTime!)")

            try context.save()
            print("[GeoKeeper] ✅ Context saved successfully after entry")

            // Send Notification
            sendNotification(
                title: "Arrived at \(location.name)", body: "Welcome back! Tracking started.")
        } catch {
            print("[GeoKeeper] ❌ ERROR: Failed to handle region entry persistence: \(error)")
        }
    }

    /// Handles creation of a LocationLog and clearing the entry time upon region exit.
    /// - Parameter region: The region that was exited.
    private func handleRegionExit(region: CLRegion) {
        print("[GeoKeeper] handleRegionExit called for region: \(region.identifier)")

        guard let context = modelContext else {
            print("[GeoKeeper] ❌ ERROR: ModelContext is nil in handleRegionExit")
            return
        }

        guard let uuid = UUID(uuidString: region.identifier) else {
            print("[GeoKeeper] ❌ ERROR: Invalid UUID in region identifier: \(region.identifier)")
            return
        }

        do {
            // Find the tracked location
            let descriptor = FetchDescriptor<TrackedLocation>(
                predicate: #Predicate { $0.id == uuid })
            guard let location = try context.fetch(descriptor).first else {
                print(
                    "[GeoKeeper] ❌ ERROR: Could not find TrackedLocation with ID: \(region.identifier)"
                )
                return
            }

            guard let entryTime = location.entryTime else {
                print(
                    "[GeoKeeper] ⚠️ WARNING: No entryTime found for \(location.name) - user may not have entered this zone"
                )
                return
            }

            let exitTime = Date()
            let duration = exitTime.timeIntervalSince(entryTime)

            // 1. Check duration threshold (1 minute)
            if duration < 60 {
                print(
                    "[GeoKeeper] ⏱️ Visit to \(location.name) was too short (< 1 min). Discarding log."
                )
                // Still need to clear entryTime to reset state
                location.entryTime = nil
                try context.save()
                return
            }

            // 2. Create and insert the LocationLog
            let newLog = LocationLog(
                locationName: location.name, locationId: location.id, entry: entryTime,
                exit: exitTime)
            context.insert(newLog)
            print(
                "[GeoKeeper] ✅ Created LocationLog for \(location.name). Duration: \(newLog.durationString)"
            )

            // 3. Clear the entry time on the TrackedLocation (marking it inactive)
            location.entryTime = nil

            try context.save()
            print("[GeoKeeper] ✅ Context saved successfully after exit - LocationLog persisted")

            // Send Notification
            sendNotification(
                title: "Left \(location.name)", body: "Duration: \(newLog.durationString)")
        } catch {
            print("[GeoKeeper] ❌ ERROR: Failed to handle region exit persistence: \(error)")
        }
    }

    // MARK: - Debug Methods

    /// Debug method to simulate entry notification (for testing in DebugView)
    func debugSimulateEntry(for location: TrackedLocation) {
        print("[GeoKeeper Debug] Simulating entry notification for \(location.name)")
        sendNotification(
            title: "Arrived at \(location.name)", body: "Welcome back! Tracking started.")
    }

    /// Debug method to simulate exit notification (for testing in DebugView)
    func debugSimulateExit(for location: TrackedLocation, duration: String) {
        print("[GeoKeeper Debug] Simulating exit notification for \(location.name)")
        sendNotification(
            title: "Left \(location.name)", body: "Duration: \(duration)")
    }
}
