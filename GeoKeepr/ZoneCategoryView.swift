import Charts
import MessageUI
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

        // 1. Group logs by day(s) they touch (O(N))
        // A log can belong to multiple days if it spans midnight
        var logsByDay: [Date: [LocationLog]] = [:]
        for log in categoryLogs {
            let startDay = calendar.startOfDay(for: log.entry)
            let endDay = calendar.startOfDay(for: log.exit)

            var currentDay = startDay
            while currentDay <= endDay {
                logsByDay[currentDay, default: []].append(log)
                guard let next = calendar.date(byAdding: .day, value: 1, to: currentDay) else {
                    break
                }
                currentDay = next
            }
        }

        for dayOffset in (0..<30).reversed() {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: now) else {
                continue
            }
            let startOfDay = calendar.startOfDay(for: date)
            guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
                continue
            }

            // Logs for this day (using pre-grouped map)
            let logsForDay = logsByDay[startOfDay] ?? []

            // Calculate intersection with the day to handle overnight sessions
            let minutesFromLogs = logsForDay.reduce(0) { total, log in
                let start = max(log.entry, startOfDay)
                let end = min(log.exit, endOfDay)
                guard start < end else { return total }
                return total + Int(end.timeIntervalSince(start) / 60)
            }

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

    // MARK: - Email Report State

    @State private var showingMailCompose = false
    @State private var showingDateRangePicker = false
    @State private var mailComposeResult: Result<MFMailComposeResult, Error>?
    @State private var reportStartDate: Date = Date()  // Initialize with dummy, update in onAppear
    @State private var reportEndDate = Date()
    @State private var showingMailUnavailableAlert = false

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

                    if !category.description.isEmpty {
                        Text(category.description)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
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

                // Email Report Button
                if !categoryLogs.isEmpty {
                    VStack(spacing: 12) {
                        Button(action: {
                            showingDateRangePicker = true
                        }) {
                            HStack {
                                Image(systemName: "envelope.fill")
                                    .font(.title3)
                                Text("Email Time Report")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                LinearGradient(
                                    colors: [.indigo, .purple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .foregroundColor(.white)
                            .cornerRadius(12)
                            .shadow(radius: 3)
                        }

                        Text("Generate a detailed report.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)
                }

                // Chart
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

                // Zone List
                VStack(alignment: .leading, spacing: 12) {
                    Text("Zones within Category")
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
                                                .italic()
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
        .sheet(isPresented: $showingDateRangePicker) {
            NavigationStack {
                Form {
                    Section("Report Period") {
                        DatePicker(
                            "Start Date",
                            selection: $reportStartDate,
                            displayedComponents: .date
                        )
                        DatePicker(
                            "End Date",
                            selection: $reportEndDate,
                            displayedComponents: .date
                        )
                    }

                    Section {
                        Button("Generate Report") {
                            showingDateRangePicker = false
                            // Small delay to allow sheet to dismiss before checking mail capability
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                if MailComposeView.canSendMail() {
                                    showingMailCompose = true
                                } else {
                                    showingMailUnavailableAlert = true
                                }
                            }
                        }
                        .bold()
                    }
                }
                .navigationTitle("Report Options")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            showingDateRangePicker = false
                        }
                    }
                }
            }
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $showingMailCompose) {
            let report = CategoryReportGenerator.generateEmailReport(
                category: category,
                logs: categoryLogs,
                activeLocations: categoryLocations,  // Pass active locations for current session tracking
                startDate: reportStartDate,
                endDate: reportEndDate
            )

            MailComposeView(
                result: $mailComposeResult,
                subject: report.subject,
                messageBody: report.body,
                isHTML: true
            )
        }
        .alert("Cannot Send Email", isPresented: $showingMailUnavailableAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(
                "This device is not configured to send emails. Please set up an email account in Settings."
            )
        }
    }

    private func updateReportStartDate() {
        let calendar = Calendar.current
        let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: Date()) ?? Date()

        // Find the earliest data point
        let earliestLog = categoryLogs.last?.entry
        let earliestActive = categoryLocations.compactMap { $0.entryTime }.min()

        let dataStart: Date
        if let logStart = earliestLog, let activeStart = earliestActive {
            dataStart = min(logStart, activeStart)
        } else {
            dataStart = earliestLog ?? earliestActive ?? Date()
        }

        // Use the LATER of 30 days ago or data start
        // This ensures we don't default to a date before data existed
        // But also defaults to a reasonable range (last 30 days) if data is old

        // Wait, user said: "it should never go back further than the first day that data was collected."
        // So if data started 10 days ago, start date should be 10 days ago.
        // If data started 1 year ago, default to 30 days ago.

        if dataStart > thirtyDaysAgo {
            reportStartDate = dataStart
        } else {
            reportStartDate = thirtyDaysAgo
        }
    }
}
