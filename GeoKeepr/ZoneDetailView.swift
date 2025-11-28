import Charts
import SwiftData
import SwiftUI

struct ZoneDetailView: View {
    @Bindable var location: TrackedLocation
    @Query(sort: \LocationLog.entry, order: .reverse) private var allLogs: [LocationLog]
    var locationLogs: [LocationLog] { allLogs.filter { $0.locationName == location.name } }
    @Environment(\.modelContext) var modelContext
    @EnvironmentObject var locationManager: LocationManager

    // Edit Sheet State
    @State private var showingEditSheet = false
    @State private var editName = ""
    @State private var editRadius: Double = 100
    @State private var editIcon = "mappin.circle.fill"
    @State private var editCategory: LocationCategory = .other

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
    
    var mostVisitedWeekdayInfo: (day: String, hours: Double)? {
        guard !locationLogs.isEmpty else { return nil }
        let calendar = Calendar.current
        // Dictionary: weekday (1...7) : total minutes
        var weekdayTotals: [Int: Int] = [:]
        for log in locationLogs {
            let weekday = calendar.component(.weekday, from: log.entry)
            weekdayTotals[weekday, default: 0] += log.durationInMinutes
        }
        if let (maxWeekday, maxMinutes) = weekdayTotals.max(by: { $0.value < $1.value }) {
            let formatter = DateFormatter()
            formatter.locale = Locale.current
            let weekdayName = formatter.weekdaySymbols[(maxWeekday - 1 + 7) % 7]
            let hours = Double(maxMinutes) / 60.0
            return (weekdayName, hours)
        }
        return nil
    }

    var isInside: Bool {
        location.entryTime != nil
    }

    // MARK: - Chart Data for Past Month
    struct DailyHours: Identifiable {
        let id = UUID()
        let date: Date
        let hours: Double
    }

    var dailyHoursData: [DailyHours] {
        let calendar = Calendar.current
        let now = Date()
        var data: [DailyHours] = []

        for dayOffset in (0..<30).reversed() {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: now) else { continue }
            let startOfDay = calendar.startOfDay(for: date)
            guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else { continue }

            // Break up filtering and accumulation for clarity and compiler friendliness
            let logsForDay = locationLogs.filter { log in
                log.entry >= startOfDay && log.entry < endOfDay
            }
            let minutesFromLogs = logsForDay.map { $0.durationInMinutes }.reduce(0, +)

            // Compute minutes from active session (if any)
            var minutesFromCurrentSession = 0
            if isInside, let entryTime = location.entryTime {
                let sessionStart = max(entryTime, startOfDay)
                let sessionEnd = min(now, endOfDay)
                if sessionStart < sessionEnd {
                    let interval = sessionEnd.timeIntervalSince(sessionStart)
                    minutesFromCurrentSession = Int(interval / 60)
                }
            }

            let totalMinutes = minutesFromLogs + minutesFromCurrentSession
            let hours = Double(totalMinutes) / 60.0
            let daily = DailyHours(date: startOfDay, hours: hours)
            data.append(daily)
        }

        return data
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerView
                insightsGridView
                
                // MARK: - New Monthly Chart Section
                if !locationLogs.isEmpty || isInside {
                    chartSection
                }
                
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
                category: $editCategory,
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

    // MARK: - Chart Section (Extracted to separate computed property)
    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Hours Per Day")
                .font(.title2)
                .bold()
                .padding(.horizontal)
            
            Chart(dailyHoursData) { day in
                BarMark(
                    x: .value("Date", day.date, unit: .day),
                    y: .value("Hours", day.hours)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [.indigo, .purple],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )
                .cornerRadius(4)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 7)) { value in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel(format: .dateTime.month().day())
                        .font(.system(size: 9))
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel {
                        if let hours = value.as(Double.self) {
                            Text("\(Int(hours))h")
                        }
                    }
                }
            }
            .frame(height: 200)
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(16)
            .padding(.horizontal)
        }
    }

    // MARK: - Subviews

    private var headerView: some View {
        VStack(spacing: 16) {
            HStack () {
                Image(systemName: location.iconName)
                    .font(.system(size: 60))
                    .foregroundColor(.white)
                    .frame(width: 100, height: 100)
                    .background(isInside ? Color.green : Color.indigo)
                    .clipShape(Circle())
                    .shadow(radius: 10)
                
                VStack () {
                    Text(("Radius"))
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Color.indigo.opacity(0.7))

                    Text("\(Int(location.radius))m")
                        .font(.caption)
                        .foregroundColor(.blue)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 2)
                        .clipShape(Capsule())
                    
                }
            }

            if isInside {
                Text("Currently Within")
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

            if let info = mostVisitedWeekdayInfo {
                InsightCardView(
                    icon: Image(systemName: "calendar"),
                    iconColor: .purple,
                    title: "Busiest Day",
                    mainText: info.day,
                    detailText: String(format: "%.1fh total", info.hours)
                )
            } else {
                InsightCardView(
                    icon: Image(systemName: "calendar"),
                    iconColor: .purple,
                    title: "Busiest Day",
                    mainText: "--",
                    detailText: "No data"
                )
            }
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
        editCategory = location.fallbackCategory
        showingEditSheet = true
    }

    private func saveEdit() {
        // Stop monitoring old region
        locationManager.stopMonitoring(location: location)

        // Update
        location.name = editName.trimmingCharacters(in: .whitespacesAndNewlines)
        location.radius = editRadius
        location.iconName = editIcon
        location.category = editCategory

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

