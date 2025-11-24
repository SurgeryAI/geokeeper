import Foundation
import SwiftData
import CoreLocation

// MARK: - TrackedLocation
@Model
final class TrackedLocation: Identifiable {
    var id: UUID
    var name: String
    var latitude: Double
    var longitude: Double
    var radius: Double
    
    // Tracks the time user entered the geofence (nil if currently outside)
    var entryTime: Date?
    
    var iconName: String = "mappin.circle.fill"

    // Computed property to provide the Core Location region object
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
class LocationLog: Identifiable {
    var id: UUID
    var locationName: String
    var entry: Date
    var exit: Date
    
    init(locationName: String, entry: Date, exit: Date) {
        self.id = UUID()
        self.locationName = locationName
        self.entry = entry
        self.exit = exit
    }
    
    // Computed properties
    var durationInMinutes: Int {
        let components = Calendar.current.dateComponents([.minute], from: entry, to: exit)
        return components.minute ?? 0
    }
    
    var durationString: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: entry, to: exit) ?? "0m"
    }
}
