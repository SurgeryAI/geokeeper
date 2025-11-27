import Charts
import SwiftData
import SwiftUI

struct ZoneDetailView: View {
    @Bindable var location: TrackedLocation
    @Query private var allLogs: [LocationLog]
    @Environment(\.modelContext) var modelContext
    @EnvironmentObject var locationManager: LocationManager

    // Edit Sheet State
    @State private var showingEditSheet = false
    @State private var editName = ""
    @State private var editRadius: Double = 100
    @State private var editIcon = "mappin.circle.fill"

    // Filter logs for this specific location
    var locationLogs: [LocationLog] {
        allLogs.filter { $0.locationName == location.name }
            .sorted { $0.entry > $1.entry }
    }

    // MARK: - Computed Stats

    var totalTimeMinutes: Int {
        locationLogs.reduce(0) { $0 + $1.durationInMinutes }
    }

    var formattedTotalTime: String {
        let hours = totalTimeMinutes / 60
        let minutes = totalTimeMinutes % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    var averageDurationMinutes: Int {
        guard !locationLogs.isEmpty else { return 0 }
        return totalTimeMinutes / locationLogs.count
    }

    var formattedAverageDuration: String {
        let hours = averageDurationMinutes / 60
        let minutes = averageDurationMinutes % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    var visitCount: Int {
        locationLogs.count
    }

    var isInside: Bool {
        location.entryTime != nil
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerView
                insightsGridView
                recentHistoryView
            }
            .padding(.bottom)
        }
        .background(Color.gray.opacity(0.05))
        .navigationTitle(location.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") {
                    startEditing()
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            EditZoneSheet(
                location: location,
                name: $editName,
                radius: $editRadius,
                icon: $editIcon,
                onSave: saveEdit,
                onDelete: {
                    // Delete is handled by parent usually, but we can do it here and dismiss
                    deleteLocation()
                },
                onCancel: {
                    showingEditSheet = false
                }
            )
            .environmentObject(locationManager)
            .environment(\.modelContext, modelContext)
        }
    }

    // MARK: - Subviews

    private var headerView: some View {
        VStack(spacing: 16) {
            Image(systemName: location.iconName)
                .font(.system(size: 60))
                .foregroundColor(.white)
                .frame(width: 100, height: 100)
                .background(isInside ? Color.green : Color.indigo)
                .clipShape(Circle())
                .shadow(radius: 10)

            VStack(spacing: 4) {
                Text(location.name)
                    .font(.largeTitle)
                    .bold()

                if isInside {
                    Text("Currently Inside")
                        .font(.headline)
                        .foregroundColor(.green)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.15))
                        .clipShape(Capsule())
                } else {
                    Text("Outside")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.top)
    }

    private var insightsGridView: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            InsightCardView(
                icon: Image(systemName: "clock.fill"),
                iconColor: .indigo,
                title: "Total Time",
                mainText: formattedTotalTime,
                detailText: "All time"
            )

            InsightCardView(
                icon: Image(systemName: "hourglass"),
                iconColor: .orange,
                title: "Avg Visit",
                mainText: formattedAverageDuration,
                detailText: "Per session"
            )

            InsightCardView(
                icon: Image(systemName: "number"),
                iconColor: .blue,
                title: "Total Visits",
                mainText: "\(visitCount)",
                detailText: "Sessions"
            )

            InsightCardView(
                icon: Image(systemName: "ruler.fill"),
                iconColor: .purple,
                title: "Radius",
                mainText: "\(Int(location.radius))m",
                detailText: "Geofence size"
            )
        }
        .padding(.horizontal)
    }

    private var recentHistoryView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent History")
                .font(.title2)
                .bold()
                .padding(.horizontal)

            if locationLogs.isEmpty {
                ContentUnavailableView(
                    "No Visits Yet",
                    systemImage: "clock.arrow.circlepath",
                    description: Text("Visits will appear here once recorded.")
                )
                .padding(.vertical, 40)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(locationLogs) { log in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(
                                    log.entry.formatted(
                                        date: .abbreviated, time: .shortened)
                                )
                                .font(.body)
                                .fontWeight(.medium)
                                Text(log.durationString)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(log.exit.formatted(date: .omitted, time: .shortened))
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        Divider().padding(.leading)
                    }
                }
                .background(Color.gray.opacity(0.1))
                .cornerRadius(16)
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Edit Logic

    private func startEditing() {
        editName = location.name
        editRadius = location.radius
        editIcon = location.iconName
        showingEditSheet = true
    }

    private func saveEdit() {
        // Stop monitoring old region
        locationManager.stopMonitoring(location: location)

        // Update
        location.name = editName.trimmingCharacters(in: .whitespacesAndNewlines)
        location.radius = editRadius
        location.iconName = editIcon

        do {
            try modelContext.save()
            // Restart monitoring
            locationManager.startMonitoring(location: location)
            showingEditSheet = false
        } catch {
            print("Error saving zone edit: \(error)")
        }
    }

    private func deleteLocation() {
        locationManager.stopMonitoring(location: location)
        modelContext.delete(location)
        do {
            try modelContext.save()
            // Dismissing the view will happen automatically if the object is deleted
        } catch {
            print("Error deleting zone: \(error)")
        }
    }
}

