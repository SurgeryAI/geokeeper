import SwiftUI
import Charts
import SwiftData
import Combine // <-- FIX: Added missing import for Timer.publish().autoconnect()

struct ReportView: View {
    // Query for all logs (completed durations)
    @Query(sort: \LocationLog.entry, order: .reverse) var logs: [LocationLog]
    
    // Query for all tracked locations (to check for active zones)
    @Query var trackedLocations: [TrackedLocation]
    
    @State private var timeRange: TimeRange = .week
    // Timer to update the "Currently Active" time every second
    @State private var timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    // State for empty state animation
    @State private var emptyStateAnimation = false
    
    enum TimeRange: String, CaseIterable {
        case week = "Last 7 Days"
        case all = "All Time"
    }
    
    var filteredLogs: [LocationLog] {
        switch timeRange {
        case .all:
            return logs
        case .week:
            let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
            return logs.filter { $0.entry > cutoff }
        }
    }
    
    // Find locations the user is currently inside
    var activeZones: [TrackedLocation] {
        trackedLocations.filter { $0.entryTime != nil }
    }
    
    var aggregatedData: [String: Int] {
        var report: [String: Int] = [:]
        for log in filteredLogs {
            let currentTotal = report[log.locationName] ?? 0
            report[log.locationName] = currentTotal + log.durationInMinutes
        }
        return report
    }
    
    var totalTimeMinutes: Int {
        filteredLogs.reduce(0) { $0 + $1.durationInMinutes }
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
    
    // Consecutive days streak of any zone visits (based on any day with a log, consecutive days before today)
    var consecutiveDaysStreak: Int {
        let calendar = Calendar.current
        let sortedDays = Set(logs.map { calendar.startOfDay(for: $0.entry) }).sorted(by: >)
        guard !sortedDays.isEmpty else { return 0 }
        var streak = 1
        for i in 1..<sortedDays.count {
            let previousDay = sortedDays[i - 1]
            let currentDay = sortedDays[i]
            if calendar.dateComponents([.day], from: currentDay, to: previousDay).day == 1 {
                streak += 1
            } else {
                break
            }
        }
        // If the last day in sortedDays is not today, streak ends at last day
        if let mostRecent = sortedDays.first,
           !calendar.isDateInToday(mostRecent) {
            return streak
        }
        return streak
    }
    
    // MARK: - Chart data for day-by-day total minutes (last 7 days)
    struct DayMinutes: Identifiable {
        let id = UUID()
        let day: Date
        let minutes: Int
    }
    
    var dayByDayData: [DayMinutes] {
        let calendar = Calendar.current
        let now = Date()
        var days: [DayMinutes] = []
        for offset in (0..<7).reversed() {
            guard let date = calendar.date(byAdding: .day, value: -offset, to: now) else { continue }
            let startOfDay = calendar.startOfDay(for: date)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
            
            let totalMinutesForDay = filteredLogs.filter {
                $0.entry >= startOfDay && $0.entry < endOfDay
            }.reduce(0) { $0 + $1.durationInMinutes }
            
            days.append(DayMinutes(day: startOfDay, minutes: totalMinutesForDay))
        }
        return days
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
                    if !logs.isEmpty {
                        VStack(spacing: 16) {
                            HStack(spacing: 16) {
                                
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
                                    .accessibilityLabel("Most time spent in \(topZone.name), \(topZone.minutes) minutes")
                                    .transition(.scale.combined(with: .opacity))
                                    .animation(.easeOut, value: topZone.minutes)
                                }
                                
                                // Average Daily Time Card
                                InsightCardView(
                                    icon: Image(systemName: "calendar"),
                                    iconColor: .indigo,
                                    title: "Avg Daily Time",
                                    mainText: formattedAverageDailyTime,
                                    detailText: "Across logged days"
                                )
                                .accessibilityElement(children: .combine)
                                .accessibilityLabel("Average daily time tracked is \(formattedAverageDailyTime)")
                                .transition(.scale.combined(with: .opacity))
                                .animation(.easeOut, value: averageDailyMinutes)
                            }
                            
                            HStack(spacing: 16) {
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
                                    .accessibilityLabel("Longest single session was at \(longestSession.locationName), lasting \(longestSession.durationString)")
                                    .transition(.scale.combined(with: .opacity))
                                    .animation(.easeOut, value: longestSession.durationInMinutes)
                                }
                                
                                // Empty space filler if needed for symmetry
                                if longestSession == nil {
                                    Spacer()
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // MARK: - Banner for First & Most Recent Visit + Streak
                    if !logs.isEmpty {
                        VStack(spacing: 8) {
                            HStack {
                                // Streak banner
                                HStack(spacing: 6) {
                                    Image(systemName: "badge.plus.radiowaves.forward")
                                        .foregroundColor(.white)
                                    Text("\(consecutiveDaysStreak) Day Streak")
                                        .bold()
                                        .foregroundColor(.white)
                                }
                                .padding(10)
                                .background(LinearGradient(colors: [Color.pink, Color.red], startPoint: .leading, endPoint: .trailing))
                                .clipShape(Capsule())
                                .accessibilityLabel("Consecutive days streak of \(consecutiveDaysStreak)")
                                
                                Spacer()
                            }
                            .padding(.horizontal)
                            
                            HStack(spacing: 16) {
                                if let firstDate = firstVisitDate {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("First Visit")
                                            .font(.callout)
                                            .foregroundStyle(.secondary)
                                        Text(bannerDateFormatter(firstDate))
                                            .font(.headline)
                                            .bold()
                                    }
                                    .accessibilityElement(children: .combine)
                                    .accessibilityLabel("First visit was on \(bannerDateFormatter(firstDate))")
                                }
                                
                                Spacer()
                                
                                if let recentDate = mostRecentVisitDate {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Most Recent Visit")
                                            .font(.callout)
                                            .foregroundStyle(.secondary)
                                        Text(bannerDateFormatter(recentDate))
                                            .font(.headline)
                                            .bold()
                                    }
                                    .accessibilityElement(children: .combine)
                                    .accessibilityLabel("Most recent visit was on \(bannerDateFormatter(recentDate))")
                                }
                            }
                            .padding()
                            .background(.ultraThinMaterial)
                            .cornerRadius(16)
                            .padding(.horizontal)
                        }
                        .transition(.opacity)
                        .animation(.easeOut, value: logs.count)
                    }
                    
                    // MARK: - Day-by-Day Chart (last 7 days)
                    if !logs.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Daily Activity")
                                .font(.title2)
                                .bold()
                                .padding(.horizontal)
                            
                            Chart {
                                ForEach(dayByDayData) { dayData in
                                    BarMark(
                                        x: .value("Day", dayData.day, unit: .day),
                                        y: .value("Minutes", dayData.minutes)
                                    )
                                    .foregroundStyle(LinearGradient(colors: [Color.indigo.opacity(0.7), Color.purple], startPoint: .bottom, endPoint: .top))
                                    .cornerRadius(6)
                                    .annotation(position: .top) {
                                        if dayData.minutes > 0 {
                                            Text("\(dayData.minutes)")
                                                .font(.caption2)
                                                .foregroundColor(.indigo)
                                                .bold()
                                        }
                                    }
                                }
                            }
                            .chartXAxis {
                                AxisMarks(values: .stride(by: .day)) { _ in
                                    AxisGridLine()
                                    AxisTick()
                                    AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                                }
                            }
                            .chartYAxis {
                                AxisMarks(position: .leading)
                            }
                            .frame(height: 200)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(LinearGradient(colors: [Color.indigo.opacity(0.15), Color.purple.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing))
                            )
                            .padding(.horizontal)
                            .animation(.easeOut, value: dayByDayData.map { $0.minutes })
                            .transition(.scale)
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
                                        .fontWeight(.semibold)
                                    Spacer()
                                    // Display time in zone, forced to update by timer
                                    if let entryTime = zone.entryTime {
                                        let timeSinceEntry = Date().timeIntervalSince(entryTime)
                                        Text(formatTimeInterval(timeSinceEntry))
                                            .font(.callout)
                                            .monospacedDigit()
                                            .foregroundColor(.green)
                                            .accessibilityLabel("Time in \(zone.name): \(formatTimeInterval(timeSinceEntry))")
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
                        .onReceive(timer) { _ in
                            // Do nothing, but receiving the timer forces the view to redraw and update the time
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
                                .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: emptyStateAnimation)
                                .accessibilityHidden(true)
                            
                            ContentUnavailableView {
                                Label("No Data Yet", systemImage: "chart.bar.xaxis")
                                    .font(.title2)
                            } description: {
                                Text("Visit your zones or exit an active zone to generate duration logs.")
                                    .font(.callout)
                            }
                        }
                        .padding(.top, 50)
                        .onAppear {
                            emptyStateAnimation = true
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("No data yet. Visit your zones or exit an active zone to generate duration logs.")
                    } else {
                        // MARK: - Summary Card
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
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Distribution")
                                .font(.title3)
                                .bold()
                                .padding(.leading)
                            
                            Chart {
                                ForEach(aggregatedData.sorted(by: { $0.value > $1.value }), id: \.key) { (name, minutes) in
                                    BarMark(
                                        x: .value("Location", name),
                                        y: .value("Minutes", minutes)
                                    )
                                    .foregroundStyle(LinearGradient(colors: [.indigo, .purple], startPoint: .bottom, endPoint: .top))
                                    .cornerRadius(5)
                                    .annotation(position: .top) {
                                        Text("\(minutes)")
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
                                                .fontWeight(.medium)
                                            Text(log.entry.formatted(date: .abbreviated, time: .omitted))
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
                                            Text("\(log.entry.formatted(date: .omitted, time: .shortened)) - \(log.exit.formatted(date: .omitted, time: .shortened))")
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
            .background(Color(UIColor.systemGroupedBackground)) // nice light gray background
            .navigationTitle("Reports")
        }
    }
}

// MARK: - Insight Card View
fileprivate struct InsightCardView: View {
    let icon: Image
    let iconColor: Color
    let title: String
    let mainText: String
    let detailText: String
    
    var body: some View {
        HStack(spacing: 12) {
            icon
                .font(.title2)
                .foregroundColor(iconColor)
                .frame(width: 36, height: 36)
                .background(iconColor.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                .accessibilityHidden(true)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Text(mainText)
                    .font(.headline)
                    .bold()
                Text(detailText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: iconColor.opacity(0.3), radius: 6, x: 0, y: 3)
        .accessibilityElement(children: .combine)
    }
}

