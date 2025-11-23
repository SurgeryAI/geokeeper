import SwiftUI
import CoreLocation
import SwiftData

struct ContentView: View {
    @EnvironmentObject var locationManager: LocationManager
    @Environment(\.modelContext) var modelContext
    
    var body: some View {
        TabView {
            // Setup Tab (Using modern NavigationStack implicitly via MapSetupView design)
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
