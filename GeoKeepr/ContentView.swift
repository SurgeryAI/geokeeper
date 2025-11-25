import CoreLocation
import SwiftData
import SwiftUI

struct ContentView: View {
    // Requires environment object
    @EnvironmentObject var locationManager: LocationManager
    @Environment(\.modelContext) var modelContext

    var body: some View {
        TabView {
            // Setup Tab
            MapSetupView()
                .tabItem {
                    Label("Map", systemImage: "map.fill")
                }

            // Zones List Tab
            ZoneListView()
                .tabItem {
                    Label("Zones", systemImage: "list.bullet.circle.fill")
                }

            // Reports Tab
            ReportView()
                .tabItem {
                    Label("History", systemImage: "chart.pie.fill")
                }

            #if DEBUG
                // Debug Tab (only in DEBUG builds)
                DebugView()
                    .tabItem {
                        Label("Debug", systemImage: "hammer.fill")
                    }
            #endif
        }
        .tint(.indigo)  // Professional Brand Color
        .onAppear {
            print("[GeoKeeper] ContentView appeared, passing context to LocationManager")
            // Pass database context to logic controller
            locationManager.updateContext(context: modelContext)
            print("[GeoKeeper] Context passed to LocationManager")
        }
    }
}

// FIX: Add a Preview struct that satisfies the environment dependencies
#Preview {
    // Mock Container for SwiftData and mock LocationManager for @EnvironmentObject
    ContentView()
        .environmentObject(LocationManager())
        .modelContainer(for: [TrackedLocation.self, LocationLog.self], inMemory: true)
}
