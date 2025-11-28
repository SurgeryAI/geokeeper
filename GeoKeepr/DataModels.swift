import CoreLocation
import Foundation
import SwiftData

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

    /// The category of the location.
    var category: LocationCategory? = .other

    /// Returns the actual category, or .other if nil (for safe UI usage)
    var fallbackCategory: LocationCategory { category ?? .other }

    /// Computed property to provide the Core Location region object.
    var region: CLCircularRegion {
        let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        // IMPORTANT: The region identifier MUST be the model's ID (UUID string) for correct lookups
        return CLCircularRegion(center: coordinate, radius: radius, identifier: id.uuidString)
    }

    init(
        id: UUID = UUID(), name: String, latitude: Double, longitude: Double, radius: Double,
        iconName: String = "mappin.circle.fill", category: LocationCategory? = .other
    ) {
        self.id = id
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.radius = radius
        self.iconName = iconName
        self.category = category
    }
}

enum LocationCategory: String, Codable, CaseIterable, Identifiable {
    case home = "Home"
    case work = "Work"
    case social = "Social"
    case fitness = "Fitness"
    case leisure = "Leisure"
    case errands = "Errands"
    case dining = "Dining"
    case travel = "Travel"
    case nature = "Nature"
    case other = "Other"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .work: return "briefcase.fill"
        case .social: return "person.2.fill"
        case .fitness: return "figure.run"
        case .leisure: return "figure.mind.and.body"
        case .errands: return "cart.fill"
        case .dining: return "fork.knife"
        case .travel: return "airplane"
        case .nature: return "leaf.fill"
        case .other: return "mappin.and.ellipse"
        }
    }

    var description: String {
        switch self {
        case .home: return "Home (Sanctuary & Residence)"
        case .other: return "Other (Catch-all for unique spots)"
        default: return rawValue
        }
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
