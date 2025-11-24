import SwiftUI
import MapKit
import CoreLocation
import SwiftData

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
            "cup.and.saucer.fill", // Cafe/Coffee
            "pawprint.fill", // Pet/Vets
            "dumbbell.fill",
        ],
        "Work & Study": [
            "briefcase.fill",
            "graduationcap.fill",
            "building.2.fill", // General Building/Office
        ],
        "Shopping & Health": [
            "bag.fill", // Shopping
            "heart.text.square.fill", // Health/Clinic
        ],
        "Travel & Outdoors": [
            "car.fill",
            "airplane", // Travel/Airport
            "tree.fill", // Park/Nature
            "bolt.fill", // Activity/Misc
            "fork.knife",
        ],
        "General": [
            Self.defaultIconName, // Default
        ]
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
                selectedIcon = Self.defaultIconName // Reset icon
                isExpanded = false
            }
        } else {
            newLocationName = ""
            newLocationCoordinate = nil
            newLocationRadius = Self.defaultRadius
            editingLocation = nil
            selectedIcon = Self.defaultIconName // Reset icon
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
            locationToUpdate.iconName = selectedIcon // Save the updated icon
            
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
                iconName: selectedIcon // Save the new icon
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
            print("!!! SWIFTDATA SAVE FAILED for location: \(trimmedName). Error: \(error.localizedDescription)")
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
                        
                        MapCircle(center: CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude), radius: location.radius)
                            .foregroundStyle(color.opacity(isEditing ? 0.3 : 0.2))
                            .stroke(color, lineWidth: isEditing ? 2 : 1)
                        
                        // Use the saved iconName here!
                        Annotation(location.name, coordinate: CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude)) {
                            Image(systemName: location.iconName) // <-- Using location.iconName
                                .foregroundColor(color)
                                .font(isEditing ? .title : .title3)
                                .scaleEffect(isEditing ? 1.2 : 1.0)
                                .animation(.spring(response: 0.3, dampingFraction: 0.5), value: isEditing)
                                .background(Circle().fill(.white).frame(width: isEditing ? 35 : 30, height: isEditing ? 35 : 30))
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
                                            self.newLocationCoordinate = CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude)
                                            self.selectedIcon = location.iconName // Load the saved icon
                                            self.isExpanded = true
                                            
                                            // Explicitly center map on the selected location
                                            let centerCoordinate = CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude)
                                            position = .camera(MapCamera(centerCoordinate: centerCoordinate, distance: Self.defaultMapDistance))

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
                            Image(systemName: selectedIcon) // <-- Using selectedIcon
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
            .ignoresSafeArea(edges: .top) // Make map immersive
            .onAppear { // <-- Initial map centering logic
                // If there are saved locations and the user location is not yet set or known,
                // center the map on the first saved location to ensure they are visible.
                if trackedLocations.isEmpty == false,
                   locationManager.userLocation == nil,
                   let firstLocation = trackedLocations.first {
                    
                    let centerCoordinate = CLLocationCoordinate2D(
                        latitude: firstLocation.latitude,
                        longitude: firstLocation.longitude
                    )
                    
                    // Center the map with a suitable viewing distance (e.g., 1000m)
                    position = .camera(MapCamera(centerCoordinate: centerCoordinate, distance: Self.defaultMapDistance))
                }
            }
            // --- Robust centering logic when data first loads ---
            .onChange(of: trackedLocations.isEmpty) { oldIsEmpty, newIsEmpty in
                // If the list goes from empty to non-empty (i.e., the first save occurred or data loaded)
                if oldIsEmpty == true && newIsEmpty == false,
                   let firstLocation = trackedLocations.first {
                    
                    let centerCoordinate = CLLocationCoordinate2D(
                        latitude: firstLocation.latitude,
                        longitude: firstLocation.longitude
                    )
                    
                    // Center the map with a suitable viewing distance (e.g., 1000m)
                    withAnimation(.easeIn) {
                        position = .camera(MapCamera(centerCoordinate: centerCoordinate, distance: Self.defaultMapDistance))
                    }
                }
            }
            
            // MARK: - 2. Collapsible Floating Action Card
            VStack(spacing: 0) {
                // Handle bar
                Capsule()
                    .fill(Color.secondary.opacity(0.4))
                    .frame(width: 40, height: 6)
                    .padding(.top, 8)
                    .padding(.bottom, 4)
                    .onTapGesture {
                        withAnimation(.easeInOut) {
                            isExpanded.toggle()
                        }
                    }
                    .accessibilityAddTraits(.isButton)
                    .accessibilityLabel(isExpanded ? "Collapse zone card" : "Expand zone card")
                
                if isExpanded {
                    VStack(spacing: 16) {
                        // New close button row aligned top trailing
                        HStack {
                            Spacer()
                            Button {
                                withAnimation(.easeInOut) {
                                    isExpanded = false
                                }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.secondary)
                            }
                            .accessibilityLabel("Close Add Zone Panel")
                            .buttonStyle(.plain)
                        }
                        
                        if isShowingSaveSuccess {
                            HStack {
                                Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                                Text(editingLocation == nil ? "Location Saved & Monitoring Started" : "Location Updated & Monitoring Restarted")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                            }
                            .padding()
                            .background(Material.regular)
                            .cornerRadius(20)
                            .transition(.move(edge: .top).combined(with: .opacity))
                        }
                        
                        VStack(alignment: .leading, spacing: 12) {
                            Text(editingLocation == nil ? "Add New Zone" : "Edit Zone: \(editingLocation!.name)")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                            
                            // Input: Location Name
                            TextField("Location Name (e.g. Work, Gym)", text: $newLocationName)
                                .padding()
                                .background(Color(UIColor.systemBackground))
                                .cornerRadius(10)
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.secondary.opacity(0.2), lineWidth: 1))
                                .accessibilityLabel("Location Name")
                                .accessibilityHint("Enter a name for this zone, like 'Work' or 'Gym'.")
                            
                            // Validation messages for Location Name and Coordinate
                            if !canSaveLocation {
                                let trimmedName = newLocationName.trimmingCharacters(in: .whitespacesAndNewlines)
                                if trimmedName.isEmpty || trimmedName.count < 2 {
                                    Text("Please enter a longer name.")
                                        .font(.caption)
                                        .foregroundColor(.red)
                                        .padding(.horizontal, 4)
                                }
                                if newLocationCoordinate == nil {
                                    Text("Tap the map to place a pin.")
                                        .font(.caption)
                                        .foregroundColor(.red)
                                        .padding(.horizontal, 4)
                                }
                            }
                            
                            // Icon Picker now uses a Menu with Sections for categories
                            HStack {
                                Text("Icon")
                                Spacer()
                                
                                Menu {
                                    // Menu content: Iterate through categories
                                    // Sorting keys alphabetically for stable order
                                    ForEach(categorizedIconChoices.keys.sorted(), id: \.self) { category in
                                        Section(category) { // Use Section to group menu items
                                            ForEach(categorizedIconChoices[category] ?? [], id: \.self) { icon in
                                                Button {
                                                    // Action: Update the selected icon state
                                                    selectedIcon = icon
                                                } label: {
                                                    // Using explicit HStack, Image, and Text instead of Label
                                                    HStack {
                                                        Image(systemName: icon)
                                                        Text(icon.replacingOccurrences(of: ".fill", with: "")
                                                            .replacingOccurrences(of: ".", with: " ").capitalized)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                } label: {
                                    // Menu Label: The visual tap target (the badge)
                                    Image(systemName: selectedIcon)
                                        .font(.title3)
                                        .foregroundColor(brandColor)
                                        .frame(width: 40, height: 40)
                                        .background(Color.secondary.opacity(0.1))
                                        .clipShape(Circle())
                                        .accessibilityLabel("Icon Picker")
                                        .accessibilityHint("Choose an icon for this location zone.")
                                }
                                .tint(brandColor)
                                .menuStyle(.automatic) // <-- FIX 1: Explicitly set menu style
                            }
                            .padding(.horizontal, 4)
                            
                            
                            // Only show controls if a coordinate is set (either new or existing)
                            if newLocationCoordinate != nil {
                                VStack(alignment: .leading) {
                                    HStack {
                                        Text("Radius")
                                        Spacer()
                                        Text("\(Int(newLocationRadius))m")
                                            .font(.caption).bold().foregroundColor(brandColor)
                                    }
                                    Slider(value: $newLocationRadius, in: Self.minRadius...Self.maxRadius, step: Self.radiusStep)
                                        .tint(brandColor)
                                        .accessibilityLabel("Zone Radius")
                                        .accessibilityValue("\(Int(newLocationRadius)) meters")
                                        .accessibilityHint("Adjust the radius of the geofence zone in meters.")
                                }
                                .transition(.opacity)
                            } else if canSaveLocation == false && newLocationCoordinate == nil {
                                // This case is already handled above with error text; no duplicate needed here.
                            } else {
                                Text("Tap the map to place a pin.")
                                    .font(.caption)
                                    .italic()
                                    .foregroundStyle(.secondary)
                            }
                            
                            // MARK: - Button Group (FIXED LAYOUT & HEIGHTS)
                            HStack(spacing: 8) {
                                // Define a consistent minimum height for all buttons
                                let buttonMinHeight: CGFloat = 48

                                if let locationToEdit = editingLocation {
                                    // --- EDIT MODE: Three buttons sharing space ---
                                    
                                    // 1. Stop Tracking Button (Icon + single word)
                                    Button(role: .destructive, action: {
                                        deleteLocation(locationToEdit)
                                    }) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "trash")
                                            Text("Delete") // Simplified label
                                        }
                                        .frame(maxWidth: .infinity, minHeight: buttonMinHeight)
                                        .padding(.horizontal, 8)
                                        .background(Color.red.opacity(0.1))
                                        .foregroundColor(.red)
                                        .cornerRadius(12)
                                        .font(.subheadline)
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel("Delete Zone")
                                    .accessibilityHint("Remove this zone and stop monitoring it.")
                                    
                                    // 2. Cancel Edit Button (Single word)
                                    Button(action: { resetCard() }) {
                                        Text("Cancel") // Simplified label
                                            .frame(maxWidth: .infinity, minHeight: buttonMinHeight)
                                            .padding(.horizontal, 8)
                                            .background(Color.gray.opacity(0.1))
                                            .foregroundColor(.secondary)
                                            .cornerRadius(12)
                                            .font(.subheadline)
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel("Cancel Editing")
                                    .accessibilityHint("Stop editing this zone and reset the form.")
                                    
                                    // 3. Update Tracking Button (Fixed layout, same height)
                                    Button(action: saveLocation) {
                                        HStack(spacing: 4) {
                                            Text("Update") // Simplified label
                                            Image(systemName: "arrow.clockwise.circle.fill")
                                        }
                                        .frame(maxWidth: .infinity, minHeight: buttonMinHeight)
                                        .padding(.horizontal, 8)
                                        .background(!canSaveLocation ? Color.gray.opacity(0.3) : brandColor)
                                        .foregroundColor(.white)
                                        .cornerRadius(12)
                                        .font(.subheadline).bold()
                                    }
                                    .disabled(!canSaveLocation)
                                    .buttonStyle(.plain)
                                    .accessibilityLabel(editingLocation == nil ? "Start Tracking" : "Update Zone")
                                    .accessibilityHint(editingLocation == nil ? "Save this new location and begin monitoring" : "Update the selected zone's details.")
                                    
                                } else {
                                    // --- CREATE MODE: Single full-width button ---
                                    Button(action: saveLocation) {
                                        HStack {
                                            Text("Start Tracking")
                                            Image(systemName: "location.circle.fill")
                                        }
                                        .frame(maxWidth: .infinity, minHeight: buttonMinHeight)
                                        .padding()
                                        .background(!canSaveLocation ? Color.gray.opacity(0.3) : brandColor)
                                        .foregroundColor(.white)
                                        .cornerRadius(12)
                                        .font(.headline)
                                    }
                                    .disabled(!canSaveLocation)
                                    .buttonStyle(.plain)
                                    .accessibilityLabel(editingLocation == nil ? "Start Tracking" : "Update Zone")
                                    .accessibilityHint(editingLocation == nil ? "Save this new location and begin monitoring" : "Update the selected zone's details.")
                                }
                            }
                        }
                        .padding(20)
                        .background(cardBackground)
                        .cornerRadius(25)
                        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.easeInOut, value: isExpanded)
                } else {
                    // Collapsed bar label
                    HStack {
                        Text(editingLocation == nil ? "Add New Zone" : "Edit Zone: \(editingLocation!.name)")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .padding(.horizontal, 20)
                        Spacer()
                    }
                    .frame(height: 44)
                    .background(cardBackground)
                    .cornerRadius(25)
                    .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                    .onTapGesture {
                        withAnimation(.easeInOut) {
                            isExpanded.toggle()
                        }
                    }
                    .animation(.easeInOut, value: isExpanded)
                }
            }
            .padding()
            .padding(.bottom, 5) // Lift slightly for tab bar
        }
        .scrollDismissesKeyboard(.immediately) // Ensure keyboard doesn't block view
    }
}

