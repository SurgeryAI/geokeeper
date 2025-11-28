import CoreLocation
import SwiftData
import SwiftUI

struct LocationEditCard: View {
    // MARK: - Bindings
    @Binding var isExpanded: Bool
    @Binding var isShowingSaveSuccess: Bool
    @Binding var editingLocation: TrackedLocation?
    @Binding var locationName: String
    @Binding var locationCoordinate: CLLocationCoordinate2D?
    @Binding var locationRadius: Double
    @Binding var selectedIcon: String
    @Binding var selectedCategory: LocationCategory

    // MARK: - Actions
    var onSave: () -> Void
    var onDelete: (TrackedLocation) -> Void
    var onCancel: () -> Void

    // MARK: - Configuration
    let minRadius: Double
    let maxRadius: Double
    let radiusStep: Double

    // MARK: - Constants
    private let brandColor = Color.indigo
    private let cardBackground = Material.ultraThinMaterial

    @State private var isShowingIconPicker = false

    // MARK: - Icon Choices
    let categorizedIconChoices: [String: [String]] = [
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

    // MARK: - Validation
    private var canSaveLocation: Bool {
        let trimmedName = locationName.trimmingCharacters(in: .whitespacesAndNewlines)
        let isNameValid = !trimmedName.isEmpty && trimmedName.count >= 2
        let isCoordinateSet = locationCoordinate != nil
        let isRadiusValid = (minRadius...maxRadius).contains(locationRadius)
        return isNameValid && isCoordinateSet && isRadiusValid
    }

    var body: some View {
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
                expandedContent
            } else {
                collapsedContent
            }
        }
        .padding()
        .padding(.bottom, 5)  // Lift slightly for tab bar
    }

    // MARK: - Subviews

    private var collapsedContent: some View {
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
    }

    private var expandedContent: some View {
        VStack(spacing: 16) {
            // Close button row
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
                    Text(
                        editingLocation == nil
                            ? "Location Saved & Monitoring Started"
                            : "Location Updated & Monitoring Restarted"
                    )
                    .font(.subheadline)
                    .fontWeight(.semibold)
                }
                .padding()
                .background(Material.regular)
                .cornerRadius(20)
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            VStack(alignment: .leading, spacing: 12) {
                Text(
                    editingLocation == nil ? "Add New Zone" : "Edit Zone: \(editingLocation!.name)"
                )
                .font(.headline)
                .foregroundStyle(.secondary)

                // Input: Location Name
                TextField("Location Name (e.g. Work, Gym)", text: $locationName)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10).stroke(
                            Color.secondary.opacity(0.2), lineWidth: 1)
                    )
                    .accessibilityLabel("Location Name")
                    .accessibilityHint("Enter a name for this zone, like 'Work' or 'Gym'.")

                // Input: Category Picker
                VStack(alignment: .leading, spacing: 4) {
                    Text("Category")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Menu {
                        Picker("Category", selection: $selectedCategory) {
                            ForEach(LocationCategory.allCases) { category in
                                Label(category.rawValue, systemImage: category.icon)
                                    .tag(category)
                            }
                        }
                    } label: {
                        HStack {
                            Label(selectedCategory.rawValue, systemImage: selectedCategory.icon)
                                .foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(10)
                    }
                }

                // Validation messages
                if !canSaveLocation {
                    let trimmedName = locationName.trimmingCharacters(in: .whitespacesAndNewlines)
                    /*if trimmedName.isEmpty || trimmedName.count < 2 {
                        Text("Please enter a longer name.")
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(.horizontal, 4)
                    } */
                    if locationCoordinate == nil {
                        Text("Tap the map to place a zone.")
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(.horizontal, 4)
                    }
                }

                // Icon Picker
                HStack {
                    Text("Icon")
                    Spacer()

                    Button {
                        isShowingIconPicker = true
                    } label: {
                        Image(systemName: selectedIcon)
                            .font(.title3)
                            .foregroundColor(brandColor)
                            .frame(width: 40, height: 40)
                            .background(Color.secondary.opacity(0.1))
                            .clipShape(Circle())
                            .accessibilityLabel("Icon Picker")
                            .accessibilityHint("Choose an icon for this location zone.")
                    }
                    .sheet(isPresented: $isShowingIconPicker) {
                        IconPickerSheet(
                            selectedIcon: $selectedIcon, categorizedIcons: categorizedIconChoices)
                    }
                }
                .padding(.horizontal, 4)

                // Radius Slider
                if locationCoordinate != nil {
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Radius")
                            Spacer()
                            Text("\(Int(locationRadius))m")
                                .font(.caption).bold().foregroundColor(brandColor)
                        }
                        Slider(value: $locationRadius, in: minRadius...maxRadius, step: radiusStep)
                            .tint(brandColor)
                            .accessibilityLabel("Zone Radius")
                            .accessibilityValue("\(Int(locationRadius)) meters")
                            .accessibilityHint("Adjust the radius of the geofence zone in meters.")
                    }
                    .transition(.opacity)
                } else if canSaveLocation == false && locationCoordinate == nil {
                    // Handled above
                } else {
                    Text("Tap the map to place a pin.")
                        .font(.caption)
                        .italic()
                        .foregroundStyle(.secondary)
                }

                // Action Buttons
                actionButtons
            }
            .padding(20)
            .background(cardBackground)
            .cornerRadius(25)
            .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .animation(.easeInOut, value: isExpanded)
    }

    private var actionButtons: some View {
        HStack(spacing: 8) {
            let buttonMinHeight: CGFloat = 48

            if let locationToEdit = editingLocation {
                // DELETE
                Button(
                    role: .destructive,
                    action: {
                        onDelete(locationToEdit)
                    }
                ) {
                    HStack(spacing: 4) {
                        Image(systemName: "trash")
                        Text("Delete")
                    }
                    .frame(maxWidth: .infinity, minHeight: buttonMinHeight)
                    .padding(.horizontal, 8)
                    .background(Color.red.opacity(0.1))
                    .foregroundColor(.red)
                    .cornerRadius(12)
                    .font(.subheadline)
                }
                .buttonStyle(.plain)

                // CANCEL
                Button(action: onCancel) {
                    Text("Cancel")
                        .frame(maxWidth: .infinity, minHeight: buttonMinHeight)
                        .padding(.horizontal, 8)
                        .background(Color.gray.opacity(0.1))
                        .foregroundColor(.secondary)
                        .cornerRadius(12)
                        .font(.subheadline)
                }
                .buttonStyle(.plain)

                // UPDATE
                Button(action: onSave) {
                    HStack(spacing: 4) {
                        Text("Update")
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

            } else {
                // CREATE
                Button(action: onSave) {
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
            }
        }
    }
}
