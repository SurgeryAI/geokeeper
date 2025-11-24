import SwiftUI
import CoreLocation
import SwiftData

struct ContentView: View {
    // Requires environment object
    @EnvironmentObject var locationManager: LocationManager
    @Environment(\.modelContext) var modelContext
    
    var body: some View {
        TabView {
            // Setup Tab
            MapSetupView()
                .tabItem {
                    Label("Zones", systemImage: "map.fill")
                }
            
            // Reports Tab
            ReportView()
                .tabItem {
                    Label("History", systemImage: "chart.pie.fill")
                }
        }
        .tint(.indigo) // Professional Brand Color
        .onAppear {
            // Pass database context to logic controller
            locationManager.updateContext(context: modelContext)
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
