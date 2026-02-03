import Combine
import Foundation
import SwiftData
import SwiftUI

class ReportViewModel: ObservableObject {
    @Published var timeRange: TimeRange = .week

    enum TimeRange: String, CaseIterable {
        case week = "Last 7 Days"
        case all = "All Time"
    }

    // MARK: - Logic

    func filterLogs(_ logs: [LocationLog]) -> [LocationLog] {
        switch timeRange {
        case .all:
            return logs
        case .week:
            let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
            return logs.filter { $0.entry >= cutoff }
        }
    }

    func calculateAggregatedData(from logs: [LocationLog]) -> [String: Int] {
        var report: [String: Int] = [:]
        for log in logs {
            let currentTotal = report[log.locationName] ?? 0
            report[log.locationName] = currentTotal + log.durationInMinutes
        }
        return report
    }

    func calculateTotalTime(from logs: [LocationLog]) -> Int {
        logs.reduce(0) { $0 + $1.durationInMinutes }
    }

    func formatTotalTime(_ totalMinutes: Int) -> String {
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    func formatTimeInterval(_ interval: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        formatter.zeroFormattingBehavior = .pad
        return formatter.string(from: interval) ?? "0m 0s"
    }
}
