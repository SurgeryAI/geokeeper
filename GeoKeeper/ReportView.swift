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
    
    // Helper function to format TimeInterval into H:M:S string
    private func formatTimeInterval(_ interval: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        formatter.zeroFormattingBehavior = .pad
        return formatter.string(from: interval) ?? "0m 0s"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    
                    // MARK: - Filter Picker
                    Picker("Time Range", selection: $timeRange) {
                        ForEach(TimeRange.allCases, id: \.self) { range in
                            Text(range.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    
                    // MARK: - Currently Active Zones (New Section)
                    if !activeZones.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Currently Active Zones")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .textCase(.uppercase)
                                .foregroundColor(.secondary)
                            
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
                                    }
                                }
                                .padding()
                                .background(Color.green.opacity(0.1))
                                .cornerRadius(12)
                            }
                        }
                        .padding(.horizontal)
                        .transition(.opacity)
                        .onReceive(timer) { _ in
                            // Do nothing, but receiving the timer forces the view to redraw and update the time
                        }
                    }
                    
                    if logs.isEmpty && activeZones.isEmpty {
                        // MARK: - Empty State
                        ContentUnavailableView {
                            Label("No Data Yet", systemImage: "chart.bar.xaxis")
                        } description: {
                            Text("Visit your zones or exit an active zone to generate duration logs.")
                        }
                        .padding(.top, 50)
                    } else {
                        // MARK: - Summary Card
                        VStack(spacing: 5) {
                            Text("Total Time Tracked")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)
                            
                            Text(formattedTotalTime)
                                .font(.system(size: 42, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.indigo)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(16)
                        .padding(.horizontal)

                        // MARK: - Chart Section
                        VStack(alignment: .leading) {
                            Text("Distribution")
                                .font(.headline)
                                .padding(.leading)
                            
                            Chart {
                                ForEach(aggregatedData.sorted(by: { $0.value > $1.value }), id: \.key) { (name, minutes) in
                                    BarMark(
                                        x: .value("Location", name),
                                        y: .value("Minutes", minutes)
                                    )
                                    .foregroundStyle(LinearGradient(colors: [.indigo, .purple], startPoint: .bottom, endPoint: .top))
                                    .cornerRadius(5)
                                }
                            }
                            .frame(height: 250)
                            .padding()
                        }
                        .background(Color(UIColor.systemBackground))
                        .cornerRadius(16)
                        .shadow(color: .black.opacity(0.05), radius: 5)
                        .padding(.horizontal)
                        
                        // MARK: - Detailed List
                        VStack(alignment: .leading) {
                            Text("Recent Logs")
                                .font(.headline)
                                .padding(.leading)
                            
                            LazyVStack(spacing: 0) {
                                ForEach(filteredLogs) { log in
                                    HStack {
                                        VStack(alignment: .leading) {
                                            Text(log.locationName)
                                                .font(.body)
                                                .fontWeight(.medium)
                                            Text(log.entry.formatted(date: .abbreviated, time: .omitted))
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        VStack(alignment: .trailing) {
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
                    }
                }
                .padding(.vertical)
            }
            .background(Color(UIColor.systemGroupedBackground)) // nice light gray background
            .navigationTitle("Reports")
        }
    }
}
