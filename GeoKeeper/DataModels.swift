import Foundation
import SwiftData
import CoreLocation

// MARK: - TrackedLocation
@Model
final class TrackedLocation: Identifiable {
    /// Unique identifier for the tracked location.
    let id: UUID
    /// Name of the location.
    var name: String
    /// Latitude coordinate.
    var latitude: Double
    /// Longitude coordinate.
    var longitude: Double
    /// Radius of the geofence region.
    var radius: Double
    
    /// Tracks the time user entered the geofence (nil if currently outside)
    var entryTime: Date?
    
    /// The icon name representing the location.
    var iconName: String = "mappin.circle.fill"

    /// Computed property to provide the Core Location region object.
    var region: CLCircularRegion {
        let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        // IMPORTANT: The region identifier MUST be the model's ID (UUID string) for correct lookups
        return CLCircularRegion(center: coordinate, radius: radius, identifier: id.uuidString)
    }

    init(id: UUID = UUID(), name: String, latitude: Double, longitude: Double, radius: Double, iconName: String = "mappin.circle.fill") {
        self.id = id
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.radius = radius
        self.iconName = iconName
    }
}

// MARK: - LocationLog
@Model
final class LocationLog: Identifiable {
    /// Unique identifier for the log entry.
    let id: UUID
    /// Name of the location logged.
    var locationName: String
    /// Entry timestamp.
    var entry: Date
    /// Exit timestamp.
    var exit: Date
    
    /// Initializes a new LocationLog instance.
    init(locationName: String, entry: Date, exit: Date) {
        self.id = UUID()
        self.locationName = locationName
        self.entry = entry
        self.exit = exit
    }
    
    /// Duration of stay in minutes.
    var durationInMinutes: Int {
        let components = Calendar.current.dateComponents([.minute], from: entry, to: exit)
        return components.minute ?? 0
    }
    
    /// Duration of stay as a formatted string.
    var durationString: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: entry, to: exit) ?? "0m"
    }
}
