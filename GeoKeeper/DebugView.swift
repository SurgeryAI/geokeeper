import SwiftData
import SwiftUI

struct DebugView: View {
    @Environment(\.modelContext) var modelContext
    @EnvironmentObject var locationManager: LocationManager
    @Query var trackedLocations: [TrackedLocation]
    @Query(sort: \LocationLog.entry, order: .reverse) var logs: [LocationLog]

    @State private var showingLogs = false
    @State private var lastAction = ""

    var body: some View {
        NavigationStack {
            List {
                Section("Test Data Persistence") {
                    Button(action: createTestLog) {
                        Label("Create Test Log", systemImage: "plus.circle.fill")
                    }

                    Button(action: clearAllLogs) {
                        Label("Clear All Logs", systemImage: "trash.fill")
                            .foregroundColor(.red)
                    }
                }

                Section("Simulate Zone Events") {
                    if trackedLocations.isEmpty {
                        Text("No zones available. Create a zone in the Map tab first.")
                            .foregroundStyle(.secondary)
                            .font(.callout)
                    } else {
                        ForEach(trackedLocations) { location in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(location.name)
                                    .font(.headline)

                                HStack(spacing: 12) {
                                    Button(action: { simulateEntry(for: location) }) {
                                        Label(
                                            "Simulate Entry", systemImage: "arrow.down.circle.fill"
                                        )
                                        .font(.caption)
                                    }
                                    .buttonStyle(.bordered)
                                    .tint(.green)
                                    .disabled(location.entryTime != nil)

                                    Button(action: { simulateExit(for: location) }) {
                                        Label("Simulate Exit", systemImage: "arrow.up.circle.fill")
                                            .font(.caption)
                                    }
                                    .buttonStyle(.bordered)
                                    .tint(.orange)
                                    .disabled(location.entryTime == nil)
                                }

                                if let entryTime = location.entryTime {
                                    Text(
                                        "Active since: \(entryTime.formatted(date: .omitted, time: .shortened))"
                                    )
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }

                Section("Database Status") {
                    HStack {
                        Text("Total Logs")
                        Spacer()
                        Text("\(logs.count)")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Total Zones")
                        Spacer()
                        Text("\(trackedLocations.count)")
                            .foregroundStyle(.secondary)
                    }

                    Button(action: { showingLogs.toggle() }) {
                        Label("View All Logs", systemImage: "list.bullet.rectangle")
                    }
                }

                if !lastAction.isEmpty {
                    Section("Last Action") {
                        Text(lastAction)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Debug Tools")
            .sheet(isPresented: $showingLogs) {
                LogsListView(logs: logs)
            }
        }
    }

    // MARK: - Debug Actions

    private func createTestLog() {
        let now = Date()
        let entry = now.addingTimeInterval(-3600)  // 1 hour ago
        let testLog = LocationLog(
            locationName: "Test Location",
            entry: entry,
            exit: now
        )

        modelContext.insert(testLog)

        do {
            try modelContext.save()
            lastAction = "✅ Created test log: 1 hour duration"
            print("[GeoKeeper Debug] Test log created successfully")
        } catch {
            lastAction = "❌ Failed to create test log: \(error.localizedDescription)"
            print("[GeoKeeper Debug] Failed to create test log: \(error)")
        }
    }

    private func clearAllLogs() {
        do {
            try modelContext.delete(model: LocationLog.self)
            try modelContext.save()
            lastAction = "✅ Cleared all logs"
            print("[GeoKeeper Debug] All logs cleared")
        } catch {
            lastAction = "❌ Failed to clear logs: \(error.localizedDescription)"
            print("[GeoKeeper Debug] Failed to clear logs: \(error)")
        }
    }

    private func simulateEntry(for location: TrackedLocation) {
        location.entryTime = Date()

        do {
            try modelContext.save()
            lastAction = "✅ Simulated entry to \(location.name)"
            print("[GeoKeeper Debug] Simulated entry to \(location.name)")

            // Also trigger the location manager's notification
            locationManager.debugSimulateEntry(for: location)
        } catch {
            lastAction = "❌ Failed to simulate entry: \(error.localizedDescription)"
            print("[GeoKeeper Debug] Failed to simulate entry: \(error)")
        }
    }

    private func simulateExit(for location: TrackedLocation) {
        guard let entryTime = location.entryTime else {
            lastAction = "❌ Cannot exit - no entry time recorded"
            return
        }

        let exitTime = Date()
        let log = LocationLog(
            locationName: location.name,
            entry: entryTime,
            exit: exitTime
        )

        modelContext.insert(log)
        location.entryTime = nil

        do {
            try modelContext.save()
            lastAction = "✅ Simulated exit from \(location.name) - Duration: \(log.durationString)"
            print(
                "[GeoKeeper Debug] Simulated exit from \(location.name), created log with duration: \(log.durationString)"
            )

            // Also trigger the location manager's notification
            locationManager.debugSimulateExit(for: location, duration: log.durationString)
        } catch {
            lastAction = "❌ Failed to simulate exit: \(error.localizedDescription)"
            print("[GeoKeeper Debug] Failed to simulate exit: \(error)")
        }
    }
}

// MARK: - Logs List View

struct LogsListView: View {
    let logs: [LocationLog]
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            List {
                if logs.isEmpty {
                    ContentUnavailableView(
                        "No Logs",
                        systemImage: "tray",
                        description: Text("No location logs found in the database")
                    )
                } else {
                    ForEach(logs) { log in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(log.locationName)
                                .font(.headline)

                            HStack {
                                Text("Entry:")
                                    .foregroundStyle(.secondary)
                                Text(log.entry.formatted(date: .abbreviated, time: .shortened))
                            }
                            .font(.caption)

                            HStack {
                                Text("Exit:")
                                    .foregroundStyle(.secondary)
                                Text(log.exit.formatted(date: .abbreviated, time: .shortened))
                            }
                            .font(.caption)

                            HStack {
                                Text("Duration:")
                                    .foregroundStyle(.secondary)
                                Text(log.durationString)
                                    .bold()
                            }
                            .font(.caption)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("All Logs (\(logs.count))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    DebugView()
        .environmentObject(LocationManager())
        .modelContainer(for: [TrackedLocation.self, LocationLog.self], inMemory: true)
}
