import SwiftUI
import SwiftData

@main
struct ChronoFenceApp: App {
    // Initialize the LocationManager
    @StateObject var locationManager = LocationManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(locationManager)
                // Inject the database context into the LocationManager so it can save data
                .onAppear {
                    // We will handle context injection inside ContentView for simplicity
                    // or via a dedicated modifier if needed.
                }
        }
        // This single line sets up the entire database for your models
        .modelContainer(for: [TrackedLocation.self, LocationLog.self])
    }
}
