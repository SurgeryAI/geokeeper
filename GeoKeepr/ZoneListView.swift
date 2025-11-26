import CoreLocation
import SwiftData
import SwiftUI

struct ZoneListView: View {
    @Query(sort: \TrackedLocation.name) var trackedLocations: [TrackedLocation]
    @EnvironmentObject var locationManager: LocationManager
    @Environment(\.modelContext) var modelContext

    // Edit state
    // @State private var showingEditSheet = false // Removed
    @State private var editingLocation: TrackedLocation?
    @State private var editName = ""
    @State private var editRadius: Double = 100
    @State private var editIcon = "mappin.circle.fill"

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
                            .contentShape(Rectangle())
                            .onTapGesture {
                                startEditing(location)
                            }
                    }
                    .onDelete(perform: deleteLocation)
                }
            }
            .navigationTitle("Tracked Zones")
            .listStyle(.insetGrouped)
            .sheet(item: $editingLocation) { location in
                EditZoneSheet(
                    location: location,
                    name: $editName,
                    radius: $editRadius,
                    icon: $editIcon,
                    onSave: saveEdit,
                    onDelete: {
                        deleteLocation(location)
                        editingLocation = nil
                    },
                    onCancel: {
                        editingLocation = nil
                    }
                )
                .environmentObject(locationManager)
                .environment(\.modelContext, modelContext)
            }
        }
    }

    private func startEditing(_ location: TrackedLocation) {
        // Initialize state variables first
        editName = location.name
        editRadius = location.radius
        editIcon = location.iconName
        // Then trigger the sheet
        editingLocation = location
    }

    private func saveEdit() {
        guard let location = editingLocation else { return }

        // Stop monitoring the old region
        locationManager.stopMonitoring(location: location)

        // Update the location
        location.name = editName.trimmingCharacters(in: .whitespacesAndNewlines)
        location.radius = editRadius
        location.iconName = editIcon

        do {
            try modelContext.save()
            print("[GeoKeeper] ✅ Updated zone: \(location.name)")

            // Restart monitoring with new parameters
            locationManager.startMonitoring(location: location)

            editingLocation = nil
        } catch {
            print("[GeoKeeper] ❌ ERROR: Failed to update zone: \(error)")
        }
    }

    private func deleteLocation(at offsets: IndexSet) {
        for index in offsets {
            let location = trackedLocations[index]
            deleteLocation(location)
        }
    }

    private func deleteLocation(_ location: TrackedLocation) {
        locationManager.stopMonitoring(location: location)
        modelContext.delete(location)

        do {
            try modelContext.save()
            print("[GeoKeeper] ✅ Deleted zone: \(location.name)")
        } catch {
            print("[GeoKeeper] ❌ ERROR: Failed to delete location: \(error)")
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
                        .font(.subheadline)
                    Spacer()
                    /*if isInside {
                        Text("ACTIVE")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.2))
                            .foregroundColor(.green)
                            .clipShape(Capsule())
                    }*/
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
            } else {
                // Show edit indicator
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Edit Zone Sheet

struct EditZoneSheet: View {
    let location: TrackedLocation
    @Binding var name: String
    @Binding var radius: Double
    @Binding var icon: String
    let onSave: () -> Void
    let onDelete: () -> Void
    let onCancel: () -> Void

    @EnvironmentObject var locationManager: LocationManager
    @Environment(\.modelContext) var modelContext

    private let categorizedIconChoices: [String: [String]] = [
        "Home & Daily": [
            "house.fill",
            "bed.double.fill",
            "cup.and.saucer.fill",
            "pawprint.fill",
            "dumbbell.fill",
        ],
        "Work & Study": [
            "briefcase.fill",
            "graduationcap.fill",
            "building.2.fill",
        ],
        "Shopping & Health": [
            "bag.fill",
            "basket.fill",
            "heart.text.square.fill",
            "cross.case.fill",
        ],
        "Travel & Outdoors": [
            "car.fill",
            "bus.fill",
            "tram.fill",
            "fuelpump.fill",
            "airplane",
            "tree.fill",
            "mountain.2.fill",
            "beach.umbrella.fill",
            "tent.fill",
            "bolt.fill",
            "fork.knife",
        ],
        "General": [
            "mappin.circle.fill",
            "star.fill",
            "flag.fill",
            "bookmark.fill",
        ],
    ]

    private var canSave: Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmedName.isEmpty && trimmedName.count >= 2 && radius >= 50 && radius <= 1000
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Zone Details") {
                    TextField("Zone Name", text: $name)
                        .autocorrectionDisabled()

                    if !canSave {
                        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        if trimmedName.isEmpty || trimmedName.count < 2 {
                            Text("Name must be at least 2 characters")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                }

                Section("Icon") {
                    Picker("Select Icon", selection: $icon) {
                        ForEach(categorizedIconChoices.keys.sorted(), id: \.self) { category in
                            Section(category) {
                                ForEach(categorizedIconChoices[category] ?? [], id: \.self) {
                                    iconName in
                                    Label {
                                        Text(
                                            iconName.replacingOccurrences(of: ".fill", with: "")
                                                .replacingOccurrences(of: ".", with: " ")
                                                .capitalized)
                                    } icon: {
                                        Image(systemName: iconName)
                                    }
                                    .tag(iconName)
                                }
                            }
                        }
                    }
                    .pickerStyle(.navigationLink)

                    HStack {
                        Text("Preview")
                        Spacer()
                        Image(systemName: icon)
                            .font(.title2)
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.indigo)
                            .clipShape(Circle())
                    }
                }

                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Radius")
                            Spacer()
                            Text("\(Int(radius))m")
                                .foregroundStyle(.secondary)
                        }

                        Slider(value: $radius, in: 50...1000, step: 10)
                            .tint(.indigo)
                    }
                } header: {
                    Text("Geofence Radius")
                } footer: {
                    Text("Recommended: 100-200m for accuracy. Minimum 50m, maximum 1000m.")
                }

                Section("Location") {
                    HStack {
                        Text("Latitude")
                        Spacer()
                        Text(String(format: "%.4f", location.latitude))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }

                    HStack {
                        Text("Longitude")
                        Spacer()
                        Text(String(format: "%.4f", location.longitude))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }

                Section {
                    Button(role: .destructive, action: onDelete) {
                        HStack {
                            Spacer()
                            Label("Delete Zone", systemImage: "trash.fill")
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Edit Zone")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: onSave)
                        .disabled(!canSave)
                        .bold()
                }
            }
        }
    }
}

#Preview {
    ZoneListView()
        .environmentObject(LocationManager())
        .modelContainer(for: TrackedLocation.self, inMemory: true)
}
