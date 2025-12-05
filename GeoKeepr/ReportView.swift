import Charts
import Combine  // <-- FIX: Added missing import for Timer.publish().autoconnect()
import SwiftData
import SwiftUI

struct ReportView: View {
    // Query for all logs (completed durations)
    @Query(sort: \LocationLog.entry, order: .reverse) var logs: [LocationLog]

    // Query for all tracked locations (to check for active zones)
    @Query var trackedLocations: [TrackedLocation]

    @State private var timeRange: TimeRange = .week
    // Timer to update the "Currently Active" time every second (for display only)
    @State private var activeZoneTimer = Timer.publish(every: 1, on: .main, in: .common)
        .autoconnect()
    @State private var activeZoneNow = Date()

    // State for empty state animation
    @State private var emptyStateAnimation = false

    // State for Weekly Story
    @State private var showingStory = false
    @State private var weeklyRecap: WeeklyRecap?

    enum TimeRange: String, CaseIterable {
        case week = "Last 7 Days"
        case month = "Last 30 Days"
        case year = "Last Year"
        case all = "All Time"
    }

    var filteredLogs: [LocationLog] {
        let calendar = Calendar.current
        let now = Date()
        switch timeRange {
        case .all:
            return logs
        case .week:
            let cutoff = calendar.date(byAdding: .day, value: -7, to: now)!
            return logs.filter { $0.entry > cutoff }
        case .month:
            let cutoff = calendar.date(byAdding: .day, value: -30, to: now)!
            return logs.filter { $0.entry > cutoff }
        case .year:
            let cutoff = calendar.date(byAdding: .year, value: -1, to: now)!
            return logs.filter { $0.entry > cutoff }
        }
    }

    // Find locations the user is currently inside
    var activeZones: [TrackedLocation] {
        trackedLocations.filter { $0.entryTime != nil }
    }

    var aggregatedData: [String: Int] {
        var report: [String: Int] = [:]
        // Add completed logs
        for log in filteredLogs {
            let currentTotal = report[log.locationName] ?? 0
            report[log.locationName] = currentTotal + log.durationInMinutes
        }
        // Add active sessions
        for zone in activeZones {
            if let entryTime = zone.entryTime {
                // Only include if it matches the time range
                // Only include if it matches the time range
                let calendar = Calendar.current
                let now = Date()
                var cutoff: Date?

                switch timeRange {
                case .week:
                    cutoff = calendar.date(byAdding: .day, value: -7, to: now)
                case .month:
                    cutoff = calendar.date(byAdding: .day, value: -30, to: now)
                case .year:
                    cutoff = calendar.date(byAdding: .year, value: -1, to: now)
                case .all:
                    cutoff = nil
                }

                if let cutoff = cutoff, entryTime < cutoff { continue }

                let duration = Int(Date().timeIntervalSince(entryTime) / 60)
                let currentTotal = report[zone.name] ?? 0
                report[zone.name] = currentTotal + duration
            }
        }
        return report
    }

    var totalTimeMinutes: Int {
        let logMinutes = filteredLogs.reduce(0) { $0 + $1.durationInMinutes }

        let activeMinutes = activeZones.reduce(0) { total, zone in
            guard let entryTime = zone.entryTime else { return total }

            // Only include if it matches the time range
            // Only include if it matches the time range
            let calendar = Calendar.current
            let now = Date()
            var cutoff: Date?

            switch timeRange {
            case .week:
                cutoff = calendar.date(byAdding: .day, value: -7, to: now)
            case .month:
                cutoff = calendar.date(byAdding: .day, value: -30, to: now)
            case .year:
                cutoff = calendar.date(byAdding: .year, value: -1, to: now)
            case .all:
                cutoff = nil
            }

            if let cutoff = cutoff, entryTime < cutoff { return total }

            return total + Int(Date().timeIntervalSince(entryTime) / 60)
        }

        return logMinutes + activeMinutes
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

    // MARK: - New Insights

    // Most time spent (top zone)
    var topZone: (name: String, minutes: Int)? {
        guard !aggregatedData.isEmpty else { return nil }
        let sorted = aggregatedData.sorted { $0.value > $1.value }
        if let top = sorted.first { return (name: top.key, minutes: top.value) } else { return nil }
    }

    // Average daily time across all logs (based on date range in logs)
    var averageDailyMinutes: Int {
        guard !filteredLogs.isEmpty else { return 0 }
        // Determine unique days with logs
        let daysSet = Set(filteredLogs.map { Calendar.current.startOfDay(for: $0.entry) })
        if daysSet.isEmpty { return 0 }
        let total = filteredLogs.reduce(0) { $0 + $1.durationInMinutes }
        return total / daysSet.count
    }

    var formattedAverageDailyTime: String {
        let hours = averageDailyMinutes / 60
        let minutes = averageDailyMinutes % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    // Longest single session
    var longestSession: LocationLog? {
        filteredLogs.max(by: { $0.durationInMinutes < $1.durationInMinutes })
    }

    // First visit date from all logs
    var firstVisitDate: Date? {
        logs.min(by: { $0.entry < $1.entry })?.entry
    }

    // Most recent visit date from all logs
    var mostRecentVisitDate: Date? {
        logs.max(by: { $0.entry < $1.entry })?.entry
    }
    // Add these computed properties to your ReportView struct:

    // Add these computed properties to your ReportView struct:

    // 1. Hours spent at work in the last full work week (Monday through Sunday)
    var workHoursLastWeek: (hours: Double, isComplete: Bool)? {
        let calendar = Calendar.current
        let now = Date()

        // Find the most recent Sunday (end of last week)
        guard
            let endOfLastWeek = calendar.date(
                byAdding: .day, value: -calendar.component(.weekday, from: now), to: now)
        else {
            return nil
        }

        // Find the Monday of that week (start of last week)
        guard let startOfLastWeek = calendar.date(byAdding: .day, value: -6, to: endOfLastWeek)
        else {
            return nil
        }

        // Get all work logs from last week
        let workLogs = filteredLogs.filter { log in
            // You'll need to identify work zones - this assumes zones named "Work" or containing "work"
            let isWorkZone =
                log.locationName.lowercased().contains("work")
                || log.locationName.lowercased().contains("office")
                || log.locationName.lowercased().contains("job")
            return isWorkZone && log.entry >= startOfLastWeek && log.entry <= endOfLastWeek
        }

        // Calculate total work hours
        let totalMinutes = workLogs.reduce(0) { $0 + $1.durationInMinutes }
        let totalHours = Double(totalMinutes) / 60.0

        // Check if we have data for all 7 days (basic completeness check)
        let daysWithData = Set(workLogs.map { calendar.startOfDay(for: $0.entry) })
        let isCompleteWeek = daysWithData.count >= 5  // At least 5 days of data

        return totalHours > 0 ? (totalHours, isCompleteWeek) : nil
    }

    // 2. Average work hours per week over last 30 days
    var averageWorkHoursPerWeek: (average: Double, weeksCount: Int)? {
        let calendar = Calendar.current
        let now = Date()
        let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: now)!

        // Get all work logs from last 30 days
        let workLogs = filteredLogs.filter { log in
            let isWorkZone =
                log.locationName.lowercased().contains("work")
                || log.locationName.lowercased().contains("office")
                || log.locationName.lowercased().contains("job")
            return isWorkZone && log.entry >= thirtyDaysAgo && log.entry <= now
        }

        guard !workLogs.isEmpty else { return nil }

        // Group logs by week
        var weeklyHours: [Double] = []
        let weekGroups = Dictionary(grouping: workLogs) { log in
            calendar.component(.yearForWeekOfYear, from: log.entry)
        }

        for (_, weekLogs) in weekGroups {
            let weekMinutes = weekLogs.reduce(0) { $0 + $1.durationInMinutes }
            let weekHours = Double(weekMinutes) / 60.0
            weeklyHours.append(weekHours)
        }

        guard !weeklyHours.isEmpty else { return nil }

        let average = weeklyHours.reduce(0, +) / Double(weeklyHours.count)
        return (average, weeklyHours.count)
    }

    // Helper function to format hours with completeness indicator
    private func formatWorkHours(_ hours: Double, isComplete: Bool) -> String {
        let formattedHours = String(format: "%.1fh", hours)
        return isComplete ? formattedHours : "~\(formattedHours)"
    }

    // Helper function to format average hours with week count
    private func formatAverageWorkHours(_ average: Double, weeksCount: Int) -> String {
        let formattedAverage = String(format: "%.1fh", average)
        return weeksCount >= 2 ? formattedAverage : "~\(formattedAverage)"
    }

    // MARK: - Chart data for zone-specific hours per day (last 7 days)
    struct ZoneHours: Identifiable {
        let id = UUID()
        let zoneName: String
        let day: Date
        let hours: Double
    }

    var zoneHoursData: [ZoneHours] {
        let calendar = Calendar.current
        var data: [ZoneHours] = []

        // Get all unique zone names
        let allZoneNames = Set(filteredLogs.map { $0.locationName })

        for offset in (0..<7).reversed() {
            guard let date = calendar.date(byAdding: .day, value: -offset, to: Date()) else {
                continue
            }
            let startOfDay = calendar.startOfDay(for: date)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

            // Calculate hours per zone for this day
            var zoneMinutes: [String: Int] = [:]

            // Add completed logs
            let logsForDay = filteredLogs.filter {
                $0.entry >= startOfDay && $0.entry < endOfDay
            }
            for log in logsForDay {
                zoneMinutes[log.locationName, default: 0] += log.durationInMinutes
            }

            // Add active sessions - include time spent TODAY regardless of when they entered
            for zone in activeZones {
                guard let entryTime = zone.entryTime else { continue }

                // Calculate how much time was spent in this zone during this specific day
                let sessionStart = max(entryTime, startOfDay)
                let sessionEnd = min(Date(), endOfDay)

                if sessionStart < sessionEnd {
                    let minutesThisDay = Int(sessionEnd.timeIntervalSince(sessionStart) / 60)
                    zoneMinutes[zone.name, default: 0] += minutesThisDay
                }
            }

            // Convert to hours and create ZoneHours entries
            // Sort zone names to ensure consistent ordering in the stacked chart
            if zoneMinutes.isEmpty {
                // For days with no data, add a placeholder entry with 0 hours
                // This ensures the day still appears on the chart's x-axis
                data.append(ZoneHours(zoneName: "", day: startOfDay, hours: 0))
            } else {
                for (zoneName, minutes) in zoneMinutes.sorted(by: { $0.key < $1.key }) {
                    let hours = Double(minutes) / 60.0
                    data.append(ZoneHours(zoneName: zoneName, day: startOfDay, hours: hours))
                }
            }
        }
        return data
    }

    // Get unique zone names for color mapping (sorted for consistent ordering)
    var uniqueZoneNames: [String] {
        // Use sorted array to ensure consistent ordering across updates
        // Include both logged locations and currently active zones
        let loggedZones = Set(filteredLogs.map { $0.locationName })
        let activeZoneNames = Set(activeZones.map { $0.name })
        return loggedZones.union(activeZoneNames).sorted()
    }

    // Color palette for zones
    func colorForZone(_ zoneName: String) -> Color {
        if zoneName.isEmpty { return .clear }

        let colors: [Color] = [
            .indigo, .purple, .blue, .cyan, .teal, .green,
            .mint, .orange, .pink, .red, .yellow, .brown,
            .gray, .primary,
        ]

        if let index = uniqueZoneNames.firstIndex(of: zoneName) {
            return colors[index % colors.count]
        }

        // Fallback for unknown zones (shouldn't happen often)
        return colors[abs(zoneName.hashValue) % colors.count]
    }

    // MARK: - Chart data for category-specific hours per day (last 7 days)
    struct CategoryHours: Identifiable {
        let id = UUID()
        let category: LocationCategory
        let day: Date
        let hours: Double
    }

    var categoryHoursData: [CategoryHours] {
        let calendar = Calendar.current
        var data: [CategoryHours] = []

        for offset in (0..<7).reversed() {
            guard let date = calendar.date(byAdding: .day, value: -offset, to: Date()) else {
                continue
            }
            let startOfDay = calendar.startOfDay(for: date)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

            // Calculate hours per category for this day
            var categoryMinutes: [LocationCategory: Int] = [:]

            // Add completed logs
            let logsForDay = filteredLogs.filter {
                $0.entry >= startOfDay && $0.entry < endOfDay
            }
            for log in logsForDay {
                // Find the tracked location to get its category
                if let location = trackedLocations.first(where: { $0.name == log.locationName }) {
                    let category = location.fallbackCategory
                    categoryMinutes[category, default: 0] += log.durationInMinutes
                }
            }

            // Add active sessions - include time spent TODAY regardless of when they entered
            for zone in activeZones {
                guard let entryTime = zone.entryTime else { continue }

                // Calculate how much time was spent in this zone during this specific day
                let sessionStart = max(entryTime, startOfDay)
                let sessionEnd = min(Date(), endOfDay)

                if sessionStart < sessionEnd {
                    let minutesThisDay = Int(sessionEnd.timeIntervalSince(sessionStart) / 60)
                    let category = zone.fallbackCategory
                    categoryMinutes[category, default: 0] += minutesThisDay
                }
            }

            // Convert to hours and create CategoryHours entries
            if categoryMinutes.isEmpty {
                // For days with no data, add a placeholder entry with 0 hours
                data.append(CategoryHours(category: .other, day: startOfDay, hours: 0))
            } else {
                for (category, minutes) in categoryMinutes.sorted(by: {
                    $0.key.rawValue < $1.key.rawValue
                }) {
                    let hours = Double(minutes) / 60.0
                    data.append(CategoryHours(category: category, day: startOfDay, hours: hours))
                }
            }
        }
        return data
    }

    // Get unique categories for color mapping (sorted for consistent ordering)
    var uniqueCategories: [LocationCategory] {
        // Get all categories from both logged locations and active zones
        let loggedCategories = Set(
            filteredLogs.compactMap { log in
                trackedLocations.first(where: { $0.name == log.locationName })?.fallbackCategory
            })
        let activeCategories = Set(activeZones.map { $0.fallbackCategory })
        return loggedCategories.union(activeCategories).sorted(by: { $0.rawValue < $1.rawValue })
    }

    // Color palette for categories
    func colorForCategory(_ category: LocationCategory) -> Color {
        switch category {
        case .home: return .indigo
        case .work: return .blue
        case .social: return .pink
        case .fitness: return .green
        case .leisure: return .purple
        case .errands: return .orange
        case .dining: return .red
        case .travel: return .cyan
        case .nature: return .mint
        case .other: return .gray
        }
    }

    // MARK: - Daily Breakdown Data

    // Aggregates total time per category for each day of the week (1=Sunday, ..., 7=Saturday)
    // Aggregates total time per category for each day of the week (1=Sunday, ..., 7=Saturday)
    var aggregatedDailyBreakdown: [Int: [LocationCategory: Double]] {
        var breakdown: [Int: [LocationCategory: Double]] = [:]
        let calendar = Calendar.current
        let now = Date()

        // Initialize empty dicts for all days to ensure we have entries
        for i in 1...7 {
            breakdown[i] = [:]
        }

        // Process logs
        for log in filteredLogs {
            let weekday = calendar.component(.weekday, from: log.entry)
            // Find category
            if let location = trackedLocations.first(where: { $0.name == log.locationName }) {
                let category = location.fallbackCategory
                breakdown[weekday, default: [:]][category, default: 0] +=
                    Double(log.durationInMinutes) / 60.0
            }
        }

        // Process active zones
        let currentWeekday = calendar.component(.weekday, from: now)
        for zone in activeZones {
            guard let entryTime = zone.entryTime else { continue }
            let durationMinutes = now.timeIntervalSince(entryTime) / 60.0
            let category = zone.fallbackCategory
            breakdown[currentWeekday, default: [:]][category, default: 0] += durationMinutes / 60.0
        }

        // Normalize by number of days in range
        let rangeStartDate: Date
        switch timeRange {
        case .week:
            rangeStartDate = calendar.date(byAdding: .day, value: -6, to: now)!
        case .month:
            rangeStartDate = calendar.date(byAdding: .day, value: -29, to: now)!
        case .year:
            rangeStartDate = calendar.date(byAdding: .year, value: -1, to: now)!
        case .all:
            rangeStartDate = logs.last?.entry ?? now
        }

        // Determine the actual start of data collection to avoid penalizing for time before the app was used
        let earliestLogDate = logs.last?.entry
        let earliestActiveDate = activeZones.compactMap { $0.entryTime }.min()

        let dataStartDate: Date
        if let logDate = earliestLogDate, let activeDate = earliestActiveDate {
            dataStartDate = min(logDate, activeDate)
        } else {
            dataStartDate = earliestLogDate ?? earliestActiveDate ?? now
        }

        // Use the LATER of the two dates (range start or data start)
        // But ensure we don't go into the future (though dataStartDate shouldn't be in future)
        let effectiveStartDate = max(rangeStartDate, dataStartDate)

        let weekdayCounts = countWeekdays(from: effectiveStartDate, to: now)

        for (day, categories) in breakdown {
            let count = max(1, weekdayCounts[day] ?? 1)
            for (cat, hours) in categories {
                breakdown[day]?[cat] = hours / Double(count)
            }
        }

        return breakdown
    }

    private func countWeekdays(from start: Date, to end: Date) -> [Int: Int] {
        var counts: [Int: Int] = [:]
        let calendar = Calendar.current
        // Normalize to start of day to avoid partial day issues
        let startDay = calendar.startOfDay(for: start)
        let endDay = calendar.startOfDay(for: end)

        var current = startDay
        while current <= endDay {
            let weekday = calendar.component(.weekday, from: current)
            counts[weekday, default: 0] += 1
            guard let next = calendar.date(byAdding: .day, value: 1, to: current) else { break }
            current = next
        }
        return counts
    }

    // Helper to get day name from weekday number (1=Sun)
    func dayName(for weekday: Int) -> String {
        let formatter = DateFormatter()
        // weekday symbols are 0-indexed in array, but 1-indexed in component
        // calendar.weekdaySymbols[0] is Sunday
        return formatter.weekdaySymbols[weekday - 1]
    }

    // Helper function to format TimeInterval into H:M:S string
    private func formatTimeInterval(_ interval: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        formatter.zeroFormattingBehavior = .pad
        return formatter.string(from: interval) ?? "0m 0s"
    }

    // Date formatter for banner
    private func bannerDateFormatter(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {

                    // MARK: - Insights Cards Top Section
                    if !logs.isEmpty || !activeZones.isEmpty {
                        VStack(spacing: 16) {
                            // NEW: Weekly Life-Log Card
                            Button(action: {
                                if let recap = WeeklyRecapGenerator.generate(
                                    logs: logs,
                                    locations: trackedLocations,
                                    activeLocations: activeZones
                                ) {
                                    showingStory = true
                                    weeklyRecap = recap
                                }
                            }) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Weekly Life-Log")
                                            .font(.headline)
                                            .foregroundColor(.white)
                                        Text("Tap for your weekly story")
                                            .font(.caption)
                                            .foregroundColor(.white.opacity(0.8))
                                    }
                                    Spacer()
                                    Image(systemName: "play.circle.fill")
                                        .font(.title)
                                        .foregroundColor(.white)
                                }
                                .padding()
                                .background(
                                    LinearGradient(
                                        colors: [.pink, .orange], startPoint: .topLeading,
                                        endPoint: .bottomTrailing)
                                )
                                .cornerRadius(16)
                                .shadow(radius: 5)
                            }
                            .padding(.horizontal)

                            // Top Zone Card
                            if let topZone {
                                InsightCardView(
                                    icon: Image(systemName: "crown.fill"),
                                    iconColor: .yellow,
                                    title: "Most Time Spent",
                                    mainText: topZone.name,
                                    detailText: "\(topZone.minutes) min"
                                )
                                .accessibilityElement(children: .combine)
                                .accessibilityLabel(
                                    "Most time spent in \(topZone.name), \(topZone.minutes) minutes"
                                )
                                .transition(.scale.combined(with: .opacity))
                                .animation(.easeOut, value: topZone.minutes)
                            }

                            // Longest Session Card
                            if let longestSession {
                                InsightCardView(
                                    icon: Image(systemName: "flame.fill"),
                                    iconColor: .red,
                                    title: "Longest Session",
                                    mainText: longestSession.locationName,
                                    detailText: longestSession.durationString
                                )
                                .accessibilityElement(children: .combine)
                                .accessibilityLabel(
                                    "Longest single session was at \(longestSession.locationName), lasting \(longestSession.durationString)"
                                )
                                .transition(.scale.combined(with: .opacity))
                                .animation(.easeOut, value: longestSession.durationInMinutes)
                            }
                            if let workHours = workHoursLastWeek {
                                InsightCardView(
                                    icon: Image(systemName: "briefcase.fill"),
                                    iconColor: .blue,
                                    title: "Work Hours Last Week",
                                    mainText: formatWorkHours(
                                        workHours.hours, isComplete: workHours.isComplete),
                                    detailText: workHours.isComplete
                                        ? "Complete week" : "Partial data"
                                )
                                .accessibilityElement(children: .combine)
                                .accessibilityLabel(
                                    "Work hours last week: \(formatWorkHours(workHours.hours, isComplete: workHours.isComplete)), \(workHours.isComplete ? "complete week" : "partial data")"
                                )
                                .transition(.scale.combined(with: .opacity))
                                .animation(.easeOut, value: workHours.hours)
                            }

                            // NEW: Average Work Hours Card
                            if let avgWorkHours = averageWorkHoursPerWeek {
                                InsightCardView(
                                    icon: Image(systemName: "chart.line.uptrend.xyaxis"),
                                    iconColor: .green,
                                    title: "Avg Work Hours/Week",
                                    mainText: formatAverageWorkHours(
                                        avgWorkHours.average, weeksCount: avgWorkHours.weeksCount),
                                    detailText:
                                        "Last \(avgWorkHours.weeksCount) week\(avgWorkHours.weeksCount == 1 ? "" : "s")"
                                )
                                .accessibilityElement(children: .combine)
                                .accessibilityLabel(
                                    "Average work hours per week: \(formatAverageWorkHours(avgWorkHours.average, weeksCount: avgWorkHours.weeksCount)) over last \(avgWorkHours.weeksCount) week\(avgWorkHours.weeksCount == 1 ? "" : "s")"
                                )
                                .transition(.scale.combined(with: .opacity))
                                .animation(.easeOut, value: avgWorkHours.average)
                            }
                        }
                        .padding(.horizontal)
                    }

                    // MARK: - Banner for First & Most Recent Visit + Streak

                    // MARK: - Zone Activity Chart (last 7 days)
                    if !logs.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Zone Activity")
                                .font(.title3)
                                .bold()
                                .padding(.horizontal)

                            Chart(zoneHoursData) { zoneData in
                                BarMark(
                                    x: .value("Day", zoneData.day, unit: .day),
                                    y: .value("Hours", zoneData.hours)
                                )
                                .foregroundStyle(by: .value("Zone", zoneData.zoneName))
                            }
                            .chartXAxis {
                                AxisMarks(values: .stride(by: .day, count: 1)) { value in
                                    AxisGridLine()
                                    AxisTick()
                                    AxisValueLabel(format: .dateTime.weekday(.narrow))
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
                            .chartForegroundStyleScale { zoneName in
                                colorForZone(zoneName)
                            }
                            .chartLegend(position: .bottom, alignment: .leading) {
                                LazyVGrid(
                                    columns: [
                                        GridItem(.adaptive(minimum: 100, maximum: 150), spacing: 12)
                                    ],
                                    alignment: .leading,
                                    spacing: 8
                                ) {
                                    ForEach(uniqueZoneNames, id: \.self) { zoneName in
                                        HStack(spacing: 6) {
                                            RoundedRectangle(cornerRadius: 3)
                                                .fill(colorForZone(zoneName))
                                                .frame(width: 12, height: 12)
                                            Text(zoneName)
                                                .font(.caption)
                                                .italic()
                                                .foregroundColor(.secondary)
                                                .lineLimit(1)
                                        }
                                    }
                                }
                                .padding(.top, 8)
                            }
                            .frame(height: 250)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color.indigo.opacity(0.08),
                                                Color.purple.opacity(0.05),
                                            ], startPoint: .topLeading, endPoint: .bottomTrailing))
                            )
                            .padding(.horizontal)
                        }
                    }

                    // MARK: - Category Activity Chart (last 7 days)
                    if !logs.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Category Activity")
                                .font(.title3)
                                .bold()
                                .padding(.horizontal)

                            Chart(categoryHoursData) { categoryData in
                                BarMark(
                                    x: .value("Day", categoryData.day, unit: .day),
                                    y: .value("Hours", categoryData.hours)
                                )
                                .foregroundStyle(
                                    by: .value("Category", categoryData.category.rawValue))
                            }
                            .chartXAxis {
                                AxisMarks(values: .stride(by: .day, count: 1)) { value in
                                    AxisGridLine()
                                    AxisTick()
                                    AxisValueLabel(format: .dateTime.weekday(.narrow))
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
                            .chartForegroundStyleScale { categoryName in
                                // Find the category enum from the raw value
                                if let category = LocationCategory(rawValue: categoryName) {
                                    colorForCategory(category)
                                } else {
                                    Color.gray
                                }
                            }
                            .chartLegend(position: .bottom, alignment: .leading) {
                                LazyVGrid(
                                    columns: [
                                        GridItem(.adaptive(minimum: 100, maximum: 150), spacing: 12)
                                    ],
                                    alignment: .leading,
                                    spacing: 8
                                ) {
                                    ForEach(uniqueCategories, id: \.self) { category in
                                        HStack(spacing: 6) {
                                            RoundedRectangle(cornerRadius: 3)
                                                .fill(colorForCategory(category))
                                                .frame(width: 12, height: 12)
                                            Text(category.rawValue)
                                                .font(.caption)
                                                .bold()
                                                .foregroundColor(.secondary)
                                                .lineLimit(1)
                                        }
                                    }
                                }
                                .padding(.top, 8)
                            }
                            .frame(height: 250)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color.blue.opacity(0.08),
                                                Color.cyan.opacity(0.05),
                                            ], startPoint: .topLeading, endPoint: .bottomTrailing))
                            )
                            .padding(.horizontal)
                        }
                    }

                    // MARK: - Daily Breakdown (Pie Charts)
                    if !logs.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Daily Breakdown")
                                .font(.title3)
                                .bold()
                                .padding(.horizontal)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 16) {
                                    // Iterate 1...7 (Sun...Sat) or reorder to start with Mon?
                                    // Let's start with Monday (2) -> Saturday (7) -> Sunday (1)
                                    let orderedWeekdays = [2, 3, 4, 5, 6, 7, 1]

                                    ForEach(orderedWeekdays, id: \.self) { weekday in
                                        let dayData = aggregatedDailyBreakdown[weekday] ?? [:]
                                        let totalHours = dayData.values.reduce(0, +)

                                        VStack {
                                            Text(dayName(for: weekday))
                                                .font(.headline)

                                            Chart {
                                                ForEach(
                                                    dayData.sorted(by: {
                                                        $0.key.rawValue < $1.key.rawValue
                                                    }), id: \.key
                                                ) { category, hours in
                                                    SectorMark(
                                                        angle: .value("Hours", hours),
                                                        innerRadius: .ratio(0.6),
                                                        angularInset: 1.5
                                                    )
                                                    .cornerRadius(3)
                                                    .foregroundStyle(colorForCategory(category))
                                                }

                                                // Untracked Segment
                                                let untracked = max(0, 24.0 - totalHours)
                                                if untracked > 0.1 {
                                                    SectorMark(
                                                        angle: .value("Hours", untracked),
                                                        innerRadius: .ratio(0.6),
                                                        angularInset: 1.5
                                                    )
                                                    .cornerRadius(3)
                                                    .foregroundStyle(Color.gray.opacity(0.2))
                                                }
                                            }
                                            .frame(width: 120, height: 120)
                                        }
                                        .padding()
                                        .background(Color.gray.opacity(0.1))  // Use system background approximation
                                        .shadow(radius: 2)
                                    }
                                }
                                .padding(.horizontal)
                                .padding(.bottom, 10)  // Space for shadow
                            }

                            // Legend
                            LazyVGrid(
                                columns: [
                                    GridItem(.adaptive(minimum: 100, maximum: 150), spacing: 12)
                                ],
                                alignment: .leading,
                                spacing: 8
                            ) {
                                ForEach(uniqueCategories, id: \.self) { category in
                                    HStack(spacing: 6) {
                                        RoundedRectangle(cornerRadius: 3)
                                            .fill(colorForCategory(category))
                                            .frame(width: 12, height: 12)
                                        Text(category.rawValue)
                                            .font(.caption)
                                            .bold()
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }

                    // MARK: - Filter Picker
                    Picker("Time Range", selection: $timeRange) {
                        ForEach(TimeRange.allCases, id: \.self) { range in
                            Text(range.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .animation(.easeOut, value: timeRange)

                    // MARK: - Currently Active Zones (New Section)
                    if !activeZones.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Currently Active Zones")
                                .font(.headline)
                                .fontWeight(.medium)
                                .textCase(.uppercase)
                                .foregroundColor(.secondary)
                                .padding(.horizontal)

                            ForEach(activeZones) { zone in
                                HStack {
                                    Image(systemName: "location.fill")
                                        .foregroundColor(.green)
                                    Text(zone.name)
                                        .italic()
                                        .fontWeight(.semibold)
                                    Spacer()
                                    // Display time in zone, forced to update by timer
                                    if let entryTime = zone.entryTime {
                                        let timeSinceEntry = activeZoneNow.timeIntervalSince(
                                            entryTime)
                                        Text(formatTimeInterval(timeSinceEntry))
                                            .font(.callout)
                                            .monospacedDigit()
                                            .foregroundColor(.green)
                                            .accessibilityLabel(
                                                "Time in \(zone.name): \(formatTimeInterval(timeSinceEntry))"
                                            )
                                    }
                                }
                                .padding()
                                .background(Color.green.opacity(0.12))
                                .cornerRadius(12)
                                .padding(.horizontal)
                                .transition(.opacity)
                                .animation(.easeOut, value: zone.entryTime)
                            }
                        }
                        .onReceive(activeZoneTimer) { input in
                            activeZoneNow = input
                        }
                    }

                    if logs.isEmpty && activeZones.isEmpty {
                        // MARK: - Empty State with animation
                        VStack(spacing: 20) {
                            Image(systemName: "chart.bar.xaxis")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 80, height: 80)
                                .foregroundColor(.indigo.opacity(0.6))
                                .rotationEffect(.degrees(emptyStateAnimation ? 10 : -10))
                                .opacity(emptyStateAnimation ? 1 : 0.6)
                                .animation(
                                    .easeInOut(duration: 2).repeatForever(autoreverses: true),
                                    value: emptyStateAnimation
                                )
                                .accessibilityHidden(true)

                            ContentUnavailableView {
                                Label("No Data Yet", systemImage: "chart.bar.xaxis")
                                    .font(.title3)
                            } description: {
                                Text(
                                    "If you have not already, setup a zone in the Map tab or visit your zones or exit an active zone to generate duration logs."
                                )
                                .font(.callout)
                            }
                        }
                        .padding(.top, 50)
                        .onAppear {
                            emptyStateAnimation = true
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel(
                            "If you have not already, setup a zone in the Map tab or visit your zones or exit an active zone to generate duration logs."
                        )
                    } else {
                        // MARK: - Summary Card
                        /*
                        VStack(spacing: 8) {
                            Text("Total Time Tracked")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)
                        
                            Text(formattedTotalTime)
                                .font(.system(size: 42, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.indigo)
                                .accessibilityLabel("Total time tracked is \(formattedTotalTime)")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(16)
                        .padding(.horizontal)
                        .animation(.easeOut, value: formattedTotalTime)
                        
                        // MARK: - Chart Section
                        */
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Distribution")
                                .font(.title3)
                                .bold()
                                .padding(.leading)

                            Chart {
                                ForEach(
                                    aggregatedData.sorted(by: { $0.value > $1.value }), id: \.key
                                ) { (name, minutes) in
                                    let hours = Double(minutes) / 60.0
                                    BarMark(
                                        x: .value("Location", name),
                                        y: .value("Hours", hours)
                                    )
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [.indigo, .purple], startPoint: .bottom,
                                            endPoint: .top)
                                    )
                                    .cornerRadius(5)
                                    .annotation(position: .top) {
                                        Text(String(format: "%.1fh", hours))
                                            .font(.caption2)
                                            .foregroundColor(.indigo)
                                            .bold()
                                    }
                                }
                            }
                            .frame(height: 250)
                            .padding()
                        }
                        .background(.ultraThinMaterial)
                        .cornerRadius(16)
                        .shadow(color: .black.opacity(0.05), radius: 5)
                        .padding(.horizontal)
                        .animation(.easeOut, value: aggregatedData)

                        // MARK: - Detailed List
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Recent Logs")
                                .font(.title3)
                                .bold()
                                .padding(.leading)

                            LazyVStack(spacing: 0) {
                                ForEach(filteredLogs) { log in
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(log.locationName)
                                                .font(.body)
                                                .italic()
                                                .fontWeight(.medium)
                                            Text(
                                                log.entry.formatted(
                                                    date: .abbreviated, time: .omitted)
                                            )
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        VStack(alignment: .trailing, spacing: 2) {
                                            Text(log.durationString)
                                                .font(.callout)
                                                .monospacedDigit()
                                                .bold()
                                                .foregroundColor(.indigo)
                                            Text(
                                                "\(log.entry.formatted(date: .omitted, time: .shortened)) - \(log.exit.formatted(date: .omitted, time: .shortened))"
                                            )
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                        }
                                    }
                                    .padding()
                                    .background(Color(UIColor.systemBackground))
                                    Divider().padding(.leading)
                                }
                            }
                            .background(Color(UIColor.systemBackground))
                            .cornerRadius(16)
                            .shadow(color: .black.opacity(0.05), radius: 5)
                            .padding(.horizontal)
                        }
                        .animation(.easeOut, value: filteredLogs.count)
                    }
                }
                .padding(.vertical)
            }
            .background(Color(UIColor.systemGroupedBackground))  // nice light gray background
            .navigationTitle("Reports")
        }
        .fullScreenCover(isPresented: $showingStory) {
            if let recap = weeklyRecap {
                StoryView(recap: recap) {
                    showingStory = false
                }
            }
        }
    }
}

// MARK: - Insight Card View
