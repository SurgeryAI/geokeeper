import Foundation
import SwiftData

struct CategoryReportGenerator {

    // MARK: - Report Data Structures

    struct DailyReport {
        let date: Date
        let sessions: [SessionDetail]
        let totalMinutes: Int
        let notes: String?

        var totalHours: Double {
            Double(totalMinutes) / 60.0
        }
    }

    struct SessionDetail {
        let startTime: Date
        let endTime: Date
        let durationMinutes: Int

        var durationHours: Double {
            Double(durationMinutes) / 60.0
        }
    }

    struct ReportSummary {
        let categoryName: String
        let startDate: Date
        let endDate: Date
        let totalHours: Double
        let totalDays: Int
        let averageDailyHours: Double
        let sessionCount: Int
        let averageSessionDuration: Double
    }

    // MARK: - Report Generation

    static func generateEmailReport(
        category: LocationCategory,
        logs: [LocationLog],
        startDate: Date,
        endDate: Date
    ) -> (subject: String, body: String) {

        let calendar = Calendar.current

        // Filter logs to date range
        let filteredLogs = logs.filter { log in
            log.entry >= startDate && log.entry <= endDate
        }

        // Group logs by day
        var dailyReports: [DailyReport] = []
        let logsByDay = Dictionary(grouping: filteredLogs) { log in
            calendar.startOfDay(for: log.entry)
        }

        // Create daily reports
        var currentDate = calendar.startOfDay(for: startDate)
        let endOfPeriod = calendar.startOfDay(for: endDate)

        while currentDate <= endOfPeriod {
            let dayStart = currentDate
            guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { break }

            // FIX: Find logs that overlap with this day (handling overnight sessions)
            // We check if the log overlaps [dayStart, dayEnd]
            let overlappingLogs = filteredLogs.filter { log in
                log.entry < dayEnd && log.exit > dayStart
            }

            let sessions = overlappingLogs.compactMap { log -> SessionDetail? in
                // Clip the session to this day
                let start = max(log.entry, dayStart)
                let end = min(log.exit, dayEnd)

                guard start < end else { return nil }

                let durationMinutes = Int(end.timeIntervalSince(start) / 60)
                return SessionDetail(
                    startTime: start,
                    endTime: end,
                    durationMinutes: durationMinutes
                )
            }.sorted { $0.startTime < $1.startTime }

            let mergedSessions = mergeSessions(sessions)

            let totalMinutes = mergedSessions.reduce(0) { $0 + $1.durationMinutes }

            dailyReports.append(
                DailyReport(
                    date: currentDate,
                    sessions: mergedSessions,
                    totalMinutes: totalMinutes,
                    notes: nil
                ))

            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
        }

        // Calculate summary stats
        // FIX: Use the daily reports (which have merged sessions) to calculate total time
        // This prevents double-counting when zones overlap
        let totalMinutes = dailyReports.reduce(0) { $0 + $1.totalMinutes }
        let totalHours = Double(totalMinutes) / 60.0

        let daysWithActivity = dailyReports.filter { $0.totalMinutes > 0 }.count
        let averageDailyHours = daysWithActivity > 0 ? totalHours / Double(daysWithActivity) : 0

        // Session count is still useful from raw logs to know how many "events" occurred,
        // but for duration we must use the merged view.
        let sessionCount = filteredLogs.count
        let averageSessionDuration = sessionCount > 0 ? totalHours / Double(sessionCount) : 0

        let summary = ReportSummary(
            categoryName: category.rawValue,
            startDate: startDate,
            endDate: endDate,
            totalHours: totalHours,
            totalDays: daysWithActivity,
            averageDailyHours: averageDailyHours,
            sessionCount: sessionCount,
            averageSessionDuration: averageSessionDuration
        )

        // Generate email
        let subject =
            "\(category.rawValue) Time Report - \(formatDate(startDate)) to \(formatDate(endDate))"
        let body = generateHTMLBody(summary: summary, dailyReports: dailyReports)

        return (subject, body)
    }

    private static func mergeSessions(_ sessions: [SessionDetail]) -> [SessionDetail] {
        guard !sessions.isEmpty else { return [] }

        var merged: [SessionDetail] = []
        var currentSession = sessions[0]

        for nextSession in sessions.dropFirst() {
            // If next session starts before (or at) current session ends, they overlap
            if nextSession.startTime <= currentSession.endTime {
                // Extend current session if next session ends later
                if nextSession.endTime > currentSession.endTime {
                    let newDuration = Int(
                        nextSession.endTime.timeIntervalSince(currentSession.startTime) / 60)
                    currentSession = SessionDetail(
                        startTime: currentSession.startTime,
                        endTime: nextSession.endTime,
                        durationMinutes: newDuration
                    )
                }
                // If next session is fully contained, we just ignore it (currentSession already covers it)
            } else {
                // No overlap, push current and start new
                merged.append(currentSession)
                currentSession = nextSession
            }
        }
        merged.append(currentSession)

        return merged
    }

    // MARK: - HTML Generation

    private static func generateHTMLBody(summary: ReportSummary, dailyReports: [DailyReport])
        -> String
    {
        var html = """
            <!DOCTYPE html>
            <html>
            <head>
                <meta charset="UTF-8">
                <style>
                    body {
                        font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Helvetica, Arial, sans-serif;
                        line-height: 1.6;
                        color: #333;
                        max-width: 800px;
                        margin: 0 auto;
                        padding: 20px;
                    }
                    h1 {
                        color: #1a1a1a;
                        border-bottom: 3px solid #007AFF;
                        padding-bottom: 10px;
                    }
                    h2 {
                        color: #333;
                        margin-top: 30px;
                        border-bottom: 2px solid #e0e0e0;
                        padding-bottom: 5px;
                    }
                    .summary-table {
                        width: 100%;
                        border-collapse: collapse;
                        margin: 20px 0;
                        background: #f9f9f9;
                    }
                    .summary-table th {
                        background: #007AFF;
                        color: white;
                        padding: 12px;
                        text-align: left;
                        font-weight: 600;
                    }
                    .summary-table td {
                        padding: 10px 12px;
                        border-bottom: 1px solid #e0e0e0;
                    }
                    .summary-table tr:last-child td {
                        border-bottom: none;
                    }
                    .detail-table {
                        width: 100%;
                        border-collapse: collapse;
                        margin: 20px 0;
                    }
                    .detail-table th {
                        background: #333;
                        color: white;
                        padding: 10px;
                        text-align: left;
                        font-weight: 600;
                        font-size: 14px;
                    }
                    .detail-table td {
                        padding: 8px 10px;
                        border-bottom: 1px solid #e0e0e0;
                        font-size: 14px;
                    }
                    .detail-table tr:nth-child(even) {
                        background: #f9f9f9;
                    }
                    .day-total {
                        background: #e8f4ff !important;
                        font-weight: 600;
                    }
                    .weekend {
                        background: #fff3e0 !important;
                    }
                    .no-activity {
                        color: #999;
                        font-style: italic;
                    }
                    .session-indent {
                        padding-left: 30px;
                    }
                    .stats-box {
                        background: #f0f7ff;
                        border-left: 4px solid #007AFF;
                        padding: 15px;
                        margin: 20px 0;
                    }
                    .footer {
                        margin-top: 40px;
                        padding-top: 20px;
                        border-top: 2px solid #e0e0e0;
                        color: #666;
                        font-size: 12px;
                    }
                </style>
            </head>
            <body>
                <h1>\(summary.categoryName) Time Report</h1>
                
                <h2>Summary</h2>
                <table class="summary-table">
                    <tr>
                        <th>Metric</th>
                        <th>Value</th>
                    </tr>
                    <tr>
                        <td><strong>Reporting Period</strong></td>
                        <td>\(formatDate(summary.startDate)) – \(formatDate(summary.endDate))</td>
                    </tr>
                    <tr>
                        <td><strong>Zone Category</strong></td>
                        <td>\(summary.categoryName)</td>
                    </tr>
                    <tr>
                        <td><strong>Total Tracked Hours</strong></td>
                        <td>\(formatHoursAndMinutes(summary.totalHours))</td>
                    </tr>
                    <tr>
                        <td><strong>Total Active Days</strong></td>
                        <td>\(summary.totalDays) days</td>
                    </tr>
                    <tr>
                        <td><strong>Average Daily Hours</strong></td>
                        <td>\(formatHoursAndMinutes(summary.averageDailyHours))</td>
                    </tr>
                </table>
            """

        // Session Statistics
        html += """
                
                <div class="stats-box">
                    <h3 style="margin-top: 0;">Session Statistics</h3>
                    <p><strong>Number of Distinct Sessions:</strong> \(summary.sessionCount)</p>
                    <p><strong>Average Session Duration:</strong> \(formatHoursAndMinutes(summary.averageSessionDuration))</p>
                    <p><em>All hours were logged within the defined \(summary.categoryName) zone coordinates via GeoKeepr tracking.</em></p>
                </div>
            """

        // Daily Time Detail
        html += """
                
                <h2>Daily Time Detail</h2>
                <table class="detail-table">
                    <thead>
                        <tr>
                            <th>Date</th>
                            <th>Start Time</th>
                            <th>End Time</th>
                            <th>Duration</th>
                            <th>Notes</th>
                        </tr>
                    </thead>
                    <tbody>
            """

        let calendar = Calendar.current
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MM/dd/yyyy (EEE)"

        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mm a"

        for dailyReport in dailyReports {
            let dateString = dateFormatter.string(from: dailyReport.date)
            let isWeekend = calendar.isDateInWeekend(dailyReport.date)
            let rowClass = isWeekend ? " class=\"weekend\"" : ""

            if dailyReport.sessions.isEmpty {
                // No activity
                html += """
                            <tr\(rowClass)>
                                <td>\(dateString)</td>
                                <td colspan="3" class="no-activity">No Activity</td>
                                <td class="no-activity">\(isWeekend ? "Weekend" : "Day Off")</td>
                            </tr>
                    """
            } else {
                // First session for the day
                let firstSession = dailyReport.sessions[0]
                html += """
                            <tr\(rowClass)>
                                <td rowspan="\(dailyReport.sessions.count + 1)">\(dateString)</td>
                                <td>\(timeFormatter.string(from: firstSession.startTime))</td>
                                <td>\(timeFormatter.string(from: firstSession.endTime))</td>
                                <td>\(formatHoursAndMinutes(firstSession.durationHours))</td>
                                <td></td>
                            </tr>
                    """

                // Additional sessions
                for session in dailyReport.sessions.dropFirst() {
                    html += """
                                <tr\(rowClass)>
                                    <td>\(timeFormatter.string(from: session.startTime))</td>
                                    <td>\(timeFormatter.string(from: session.endTime))</td>
                                    <td>\(formatHoursAndMinutes(session.durationHours))</td>
                                    <td></td>
                                </tr>
                        """
                }

                // Daily total
                html += """
                            <tr class="day-total">
                                <td colspan="3"><strong>Daily Total</strong></td>
                                <td><strong>\(formatHoursAndMinutes(dailyReport.totalHours))</strong></td>
                                <td></td>
                            </tr>
                    """
            }
        }

        html += """
                    </tbody>
                </table>
                
                <div class="footer">
                    <p><strong>GeoKeepr Time Tracking Report</strong></p>
                    <p>Generated on \(formatDateTime(Date()))</p>
                    <p>This report was automatically generated from geofence-based time tracking data.</p>
                </div>
            </body>
            </html>
            """

        return html
    }

    // MARK: - Formatting Helpers

    private static func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    private static func formatDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private static func formatHoursAndMinutes(_ hours: Double) -> String {
        let totalMinutes = Int(hours * 60)
        let h = totalMinutes / 60
        let m = totalMinutes % 60
        return "\(h)h \(m)m"
    }
}
