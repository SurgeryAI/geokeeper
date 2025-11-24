import CoreLocation
import MapKit
import SwiftData
import SwiftUI

struct MapSetupView: View {
    static let defaultRadius: Double = 100
    static let minRadius: Double = 50
    static let maxRadius: Double = 1000
    static let radiusStep: Double = 10
    static let defaultIconName: String = "mappin.circle.fill"
    static let defaultMapDistance: CLLocationDistance = 1000

    @EnvironmentObject var locationManager: LocationManager
    @Environment(\.modelContext) var modelContext

    // Live query of existing locations
    @Query var trackedLocations: [TrackedLocation]

    @State private var position: MapCameraPosition = .userLocation(fallback: .automatic)
    @State private var newLocationName: String = ""
    @State private var newLocationCoordinate: CLLocationCoordinate2D?
    @State private var newLocationRadius: Double = Self.defaultRadius
    @State private var isShowingSaveSuccess = false
    @State private var selectedIcon: String = Self.defaultIconName

    // State to hold the location currently being edited
    @State private var editingLocation: TrackedLocation?

    // New state for collapsible card expansion
    @State private var isExpanded = false

    // MARK: - Categorized Icon Choices for improved Menu structure
    let categorizedIconChoices: [String: [String]] = [
        "Home & Daily": [
            "house.fill",
            "bed.double.fill",
            "cup.and.saucer.fill",  // Cafe/Coffee
            "pawprint.fill",  // Pet/Vets
            "dumbbell.fill",
        ],
        "Work & Study": [
            "briefcase.fill",
            "graduationcap.fill",
            "building.2.fill",  // General Building/Office
        ],
        "Shopping & Health": [
            "bag.fill",  // Shopping
            "heart.text.square.fill",  // Health/Clinic
        ],
        "Travel & Outdoors": [
            "car.fill",
            "airplane",  // Travel/Airport
            "tree.fill",  // Park/Nature
            "bolt.fill",  // Activity/Misc
            "fork.knife",
        ],
        "General": [
            Self.defaultIconName  // Default
        ],
    ]

    // UI Constants
    let cardBackground = Material.ultraThinMaterial
    let brandColor = Color.indigo

    // Validation: Replace isSaveButtonDisabled with canSaveLocation
    private var canSaveLocation: Bool {
        let trimmedName = newLocationName.trimmingCharacters(in: .whitespacesAndNewlines)
        let isNameValid = !trimmedName.isEmpty && trimmedName.count >= 2
        let isCoordinateSet = newLocationCoordinate != nil
        let isRadiusValid = (Self.minRadius...Self.maxRadius).contains(newLocationRadius)
        return isNameValid && isCoordinateSet && isRadiusValid
    }

    // MARK: - Actions

    func resetCard(animate: Bool = true) {
        if animate {
            withAnimation {
                newLocationName = ""
                newLocationCoordinate = nil
                newLocationRadius = Self.defaultRadius
                editingLocation = nil
                selectedIcon = Self.defaultIconName  // Reset icon
                isExpanded = false
            }
        } else {
            newLocationName = ""
            newLocationCoordinate = nil
            newLocationRadius = Self.defaultRadius
            editingLocation = nil
            selectedIcon = Self.defaultIconName  // Reset icon
            isExpanded = false
        }
    }

    func saveLocation() {
        guard let coordinate = newLocationCoordinate else { return }

        let trimmedName = newLocationName.trimmingCharacters(in: .whitespacesAndNewlines)

        if let locationToUpdate = editingLocation {
            // --- EDITING MODE ---

            // 1. Stop monitoring the old region (important if name or radius changed)
            locationManager.stopMonitoring(location: locationToUpdate)

            // 2. Update model properties
            locationToUpdate.name = trimmedName
            locationToUpdate.latitude = coordinate.latitude
            locationToUpdate.longitude = coordinate.longitude
            locationToUpdate.radius = newLocationRadius
            locationToUpdate.iconName = selectedIcon  // Save the updated icon

            // 3. Start monitoring the new (updated) region
            locationManager.startMonitoring(location: locationToUpdate)

            // Optimistically set success flag
            isShowingSaveSuccess = true

        } else {
            // --- CREATION MODE ---

            // 1. Create the new location object
            let newLocation = TrackedLocation(
                name: trimmedName,
                latitude: coordinate.latitude,
                longitude: coordinate.longitude,
                radius: newLocationRadius,
                iconName: selectedIcon  // Save the new icon
            )

            // 2. Insert into Database
            modelContext.insert(newLocation)

            // 3. Tell LocationManager to start watching this region
            locationManager.startMonitoring(location: newLocation)

            // Optimistically set success flag
            isShowingSaveSuccess = true
        }

        // MARK: - Explicit SwiftData Save and Error Check
        do {
            try modelContext.save()
            print("SWIFTDATA SAVE SUCCESSFUL for location: \(trimmedName)")
        } catch {
            // If save fails, log the error and ensure the success banner is hidden
            print(
                "!!! SWIFTDATA SAVE FAILED for location: \(trimmedName). Error: \(error.localizedDescription)"
            )
            isShowingSaveSuccess = false
            // Return early if the save failed to prevent UI reset and success feedback
            return
        }

        // 5. UI Feedback & Reset (Only runs if save was successful)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        resetCard()

        // Hide success banner after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { isShowingSaveSuccess = false }
    }

    func deleteLocation(_ location: TrackedLocation) {
        // 1. Stop Core Location monitoring
        locationManager.stopMonitoring(location: location)

        // 2. Delete from SwiftData
        modelContext.delete(location)

        // 3. Explicitly save the deletion
        do {
            try modelContext.save()
        } catch {
            print("Failed to delete location: \(error.localizedDescription)")
        }

        // 4. Reset card view
        resetCard()
    }

    // MARK: - View Body
    var body: some View {
        ZStack(alignment: .bottom) {
            // MARK: - 1. Full Screen Map
            MapReader { proxy in
                Map(position: $position) {
                    // Draw Existing Saved Locations (Blue/Green for selection)
                    ForEach(trackedLocations) { location in
                        let isEditing = location.id == editingLocation?.id
                        let color = isEditing ? Color.green : brandColor

                        MapCircle(
                            center: CLLocationCoordinate2D(
                                latitude: location.latitude, longitude: location.longitude),
                            radius: location.radius
                        )
                        .foregroundStyle(color.opacity(isEditing ? 0.3 : 0.2))
                        .stroke(color, lineWidth: isEditing ? 2 : 1)

                        // Use the saved iconName here!
                        Annotation(
                            location.name,
                            coordinate: CLLocationCoordinate2D(
                                latitude: location.latitude, longitude: location.longitude)
                        ) {
                            Image(systemName: location.iconName)  // <-- Using location.iconName
                                .foregroundColor(color)
                                .font(isEditing ? .title : .title3)
                                .scaleEffect(isEditing ? 1.2 : 1.0)
                                .animation(
                                    .spring(response: 0.3, dampingFraction: 0.5), value: isEditing
                                )
                                .background(
                                    Circle().fill(.white).frame(
                                        width: isEditing ? 35 : 30, height: isEditing ? 35 : 30)
                                )
                                .padding(2)
                                .onTapGesture {
                                    if isEditing {
                                        // Tap again to cancel editing
                                        resetCard()
                                    } else {
                                        // Tap to select for editing
                                        withAnimation {
                                            self.editingLocation = location
                                            self.newLocationName = location.name
                                            self.newLocationRadius = location.radius
                                            self.newLocationCoordinate = CLLocationCoordinate2D(
                                                latitude: location.latitude,
                                                longitude: location.longitude)
                                            self.selectedIcon = location.iconName  // Load the saved icon
                                            self.isExpanded = true

                                            // Explicitly center map on the selected location
                                            let centerCoordinate = CLLocationCoordinate2D(
                                                latitude: location.latitude,
                                                longitude: location.longitude)
                                            position = .camera(
                                                MapCamera(
                                                    centerCoordinate: centerCoordinate,
                                                    distance: Self.defaultMapDistance))

                                        }
                                        let impact = UIImpactFeedbackGenerator(style: .medium)
                                        impact.impactOccurred()
                                    }
                                }
                        }
                    }

                    // Draw New Location being created (Red)
                    if editingLocation == nil, let coordinate = newLocationCoordinate {
                        Annotation("New", coordinate: coordinate) {
                            Image(systemName: selectedIcon)  // <-- Using selectedIcon
                                .foregroundColor(.red)
                                .font(.title)
                                .shadow(radius: 2)
                                .background(Circle().fill(.white).frame(width: 35, height: 35))
                                .padding(2)
                        }
                        MapCircle(center: coordinate, radius: newLocationRadius)
                            .foregroundStyle(Color.red.opacity(0.15))
                            .stroke(Color.red, style: StrokeStyle(lineWidth: 2, dash: [5]))
                    }
                }
                .mapControls {
                    MapUserLocationButton()
                    MapCompass()
                    MapScaleView()
                }
                .onTapGesture { screenPoint in
                    if editingLocation == nil {
                        // Only allow placing a new pin if NOT in editing mode
                        if let coordinate = proxy.convert(screenPoint, from: .local) {
                            withAnimation(.spring) { self.newLocationCoordinate = coordinate }
                            // Haptic feedback for placing pin
                            let impact = UIImpactFeedbackGenerator(style: .light)
                            impact.impactOccurred()
                        }
                    }
                }
            }
            .ignoresSafeArea(edges: .top)  // Make map immersive
            .onAppear {  // <-- Initial map centering logic
                // If there are saved locations and the user location is not yet set or known,
                // center the map on the first saved location to ensure they are visible.
                if trackedLocations.isEmpty == false,
                    locationManager.userLocation == nil,
                    let firstLocation = trackedLocations.first
                {

                    let centerCoordinate = CLLocationCoordinate2D(
                        latitude: firstLocation.latitude,
                        longitude: firstLocation.longitude
                    )

                    // Center the map with a suitable viewing distance (e.g., 1000m)
                    position = .camera(
                        MapCamera(
                            centerCoordinate: centerCoordinate, distance: Self.defaultMapDistance))
                }
            }
            // --- Robust centering logic when data first loads ---
            .onChange(of: trackedLocations.isEmpty) { oldIsEmpty, newIsEmpty in
                // If the list goes from empty to non-empty (i.e., the first save occurred or data loaded)
                if oldIsEmpty == true && newIsEmpty == false,
                    let firstLocation = trackedLocations.first
                {

                    let centerCoordinate = CLLocationCoordinate2D(
                        latitude: firstLocation.latitude,
                        longitude: firstLocation.longitude
                    )

                    // Center the map with a suitable viewing distance (e.g., 1000m)
                    withAnimation(.easeIn) {
                        position = .camera(
                            MapCamera(
                                centerCoordinate: centerCoordinate,
                                distance: Self.defaultMapDistance))
                    }
                }
            }

            // MARK: - 2. Collapsible Floating Action Card
            LocationEditCard(
                isExpanded: $isExpanded,
                isShowingSaveSuccess: $isShowingSaveSuccess,
                editingLocation: $editingLocation,
                locationName: $newLocationName,
                locationCoordinate: $newLocationCoordinate,
                locationRadius: $newLocationRadius,
                selectedIcon: $selectedIcon,
                onSave: saveLocation,
                onDelete: deleteLocation,
                onCancel: { resetCard() },
                minRadius: Self.minRadius,
                maxRadius: Self.maxRadius,
                radiusStep: Self.radiusStep
            )
        }
        .scrollDismissesKeyboard(.immediately)  // Ensure keyboard doesn't block view
    }
}
