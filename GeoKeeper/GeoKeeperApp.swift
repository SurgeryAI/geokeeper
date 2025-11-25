import SwiftData
import SwiftUI

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
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            print("[GeoKeeper] ✅ ModelContainer created successfully")
            return container
        } catch {
            print("[GeoKeeper] ❌ FATAL: Could not create ModelContainer: \(error)")
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                // CRITICAL FIX: Inject the LocationManager into the environment
                .environmentObject(locationManager)
                .onAppear {
                    print("[GeoKeeper] App appeared, model container ready")
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
