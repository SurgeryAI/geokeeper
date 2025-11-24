import SwiftUI
import SwiftData

@main
struct GeoKeeperApp: App {
    // CRITICAL FIX: Initialize the LocationManager
    @StateObject var locationManager = LocationManager()

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            TrackedLocation.self,
            LocationLog.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                // CRITICAL FIX: Inject the LocationManager into the environment
                .environmentObject(locationManager)
        }
        .modelContainer(sharedModelContainer)
    }
}
