import Charts
import SwiftData
import SwiftUI

struct ZoneCategoryView: View {
    let category: LocationCategory

    @Query private var allLocations: [TrackedLocation]
    @Query(sort: \LocationLog.entry, order: .reverse) private var allLogs: [LocationLog]

    var categoryLocations: [TrackedLocation] {
        allLocations.filter { $0.fallbackCategory == category }
    }

    var categoryLogs: [LocationLog] {
        let locationNames = Set(categoryLocations.map { $0.name })
        return allLogs.filter { locationNames.contains($0.locationName) }
    }

    // MARK: - Insights

    var totalTimeMinutes: Int {
        categoryLogs.reduce(0) { $0 + $1.durationInMinutes }
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
        guard !categoryLogs.isEmpty else { return 0 }
        return totalTimeMinutes / categoryLogs.count
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

    var mostVisitedZone: (name: String, count: Int)? {
        guard !categoryLogs.isEmpty else { return nil }
        var counts: [String: Int] = [:]
        for log in categoryLogs {
            counts[log.locationName, default: 0] += 1
        }
        if let max = counts.max(by: { $0.value < $1.value }) {
            return (max.key, max.value)
        }
        return nil
    }

    // MARK: - Chart Data

    struct DailyHours: Identifiable {
        let id = UUID()
        let date: Date
        let hours: Double
    }

    var dailyHoursData: [DailyHours] {
        let calendar = Calendar.current
        let now = Date()
        var data: [DailyHours] = []

        // Pre-compute active sessions for this category
        let activeSessions: [(start: Date, end: Date)] = categoryLocations.compactMap { loc in
            guard let entry = loc.entryTime else { return nil }
            return (entry, now)
        }

        for dayOffset in (0..<30).reversed() {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: now) else {
                continue
            }
            let startOfDay = calendar.startOfDay(for: date)
            guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
                continue
            }

            // Logs for this day
            let logsForDay = categoryLogs.filter { log in
                log.entry >= startOfDay && log.entry < endOfDay
            }
            let minutesFromLogs = logsForDay.map { $0.durationInMinutes }.reduce(0, +)

            // Active sessions for this day
            var minutesFromActive = 0
            for session in activeSessions {
                let sessionStart = max(session.start, startOfDay)
                let sessionEnd = min(session.end, endOfDay)
                if sessionStart < sessionEnd {
                    let interval = sessionEnd.timeIntervalSince(sessionStart)
                    minutesFromActive += Int(interval / 60)
                }
            }

            let totalMinutes = minutesFromLogs + minutesFromActive
            let hours = Double(totalMinutes) / 60.0
            let daily = DailyHours(date: startOfDay, hours: hours)
            data.append(daily)
        }

        return data
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: category.icon)
                        .font(.system(size: 50))
                        .foregroundStyle(.white)
                        .frame(width: 80, height: 80)
                        .background(Color.indigo)
                        .clipShape(Circle())
                        .shadow(radius: 5)

                    Text(category.rawValue)
                        .font(.title)
                        .bold()

                    Text(category.description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top)

                // Insights
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

                    if let mostVisited = mostVisitedZone {
                        InsightCardView(
                            icon: Image(systemName: "crown.fill"),
                            iconColor: .yellow,
                            title: "Top Zone",
                            mainText: mostVisited.name,
                            detailText: "\(mostVisited.count) visits"
                        )
                    }

                    InsightCardView(
                        icon: Image(systemName: "mappin.and.ellipse"),
                        iconColor: .blue,
                        title: "Zones",
                        mainText: "\(categoryLocations.count)",
                        detailText: "In category"
                    )
                }
                .padding(.horizontal)

                // Chart
                VStack(alignment: .leading, spacing: 12) {
                    Text("Hours Per Day (Last 30 Days)")
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

                // Zone List
                VStack(alignment: .leading, spacing: 12) {
                    Text("Zones in \(category.rawValue)")
                        .font(.title2)
                        .bold()
                        .padding(.horizontal)

                    if categoryLocations.isEmpty {
                        ContentUnavailableView(
                            "No Zones",
                            systemImage: "mappin.slash",
                            description: Text("No zones assigned to this category.")
                        )
                    } else {
                        LazyVStack(spacing: 0) {
                            ForEach(categoryLocations) { location in
                                NavigationLink(destination: ZoneDetailView(location: location)) {
                                    HStack {
                                        Image(systemName: location.iconName)
                                            .foregroundStyle(.indigo)
                                            .font(.title2)
                                            .frame(width: 40)

                                        VStack(alignment: .leading) {
                                            Text(location.name)
                                                .font(.headline)
                                                .foregroundStyle(.primary)

                                            Text("Radius: \(Int(location.radius))m")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }

                                        Spacer()

                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundStyle(.tertiary)
                                    }
                                    .padding()
                                    .background(Color.gray.opacity(0.05))  // Slightly lighter than container
                                }
                                Divider().padding(.leading)
                            }
                        }
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(16)
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.bottom)
        }
        .background(Color.gray.opacity(0.05))
        .navigationTitle(category.rawValue)
        .navigationBarTitleDisplayMode(.inline)
    }
}
