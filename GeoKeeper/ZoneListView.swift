import CoreLocation
import SwiftData
import SwiftUI

struct ZoneListView: View {
    @Query(sort: \TrackedLocation.name) var trackedLocations: [TrackedLocation]
    @EnvironmentObject var locationManager: LocationManager
    @Environment(\.modelContext) var modelContext

    var body: some View {
        NavigationStack {
            List {
                if trackedLocations.isEmpty {
                    ContentUnavailableView(
                        "No Zones Tracked",
                        systemImage: "mappin.slash.circle",
                        description: Text("Go to the Map tab to add new zones.")
                    )
                } else {
                    ForEach(trackedLocations) { location in
                        ZoneRowView(location: location)
                    }
                    .onDelete(perform: deleteLocation)
                }
            }
            .navigationTitle("Tracked Zones")
            .listStyle(.insetGrouped)
        }
    }

    private func deleteLocation(at offsets: IndexSet) {
        for index in offsets {
            let location = trackedLocations[index]
            locationManager.stopMonitoring(location: location)
            modelContext.delete(location)
        }

        do {
            try modelContext.save()
        } catch {
            print("Failed to delete location: \(error)")
        }
    }
}

struct ZoneRowView: View {
    let location: TrackedLocation

    var isInside: Bool {
        location.entryTime != nil
    }

    var body: some View {
        HStack(spacing: 16) {
            // Icon
            Image(systemName: location.iconName)
                .font(.title2)
                .foregroundColor(.white)
                .frame(width: 44, height: 44)
                .background(isInside ? Color.green : Color.indigo)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(location.name)
                        .font(.headline)

                    if isInside {
                        Text("ACTIVE")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.2))
                            .foregroundColor(.green)
                            .clipShape(Capsule())
                    }
                }

                Text("\(Int(location.radius))m radius")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(
                    "\(String(format: "%.4f", location.latitude)), \(String(format: "%.4f", location.longitude))"
                )
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .monospacedDigit()
            }

            Spacer()

            if isInside, let entryTime = location.entryTime {
                VStack(alignment: .trailing) {
                    Text("Entered")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(entryTime, style: .time)
                        .font(.caption)
                        .bold()
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ZoneListView()
        .environmentObject(LocationManager())
        .modelContainer(for: TrackedLocation.self, inMemory: true)
}
