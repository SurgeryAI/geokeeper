import Foundation
import SwiftData
import SwiftUI

struct WeeklyRecap {
    let startDate: Date
    let endDate: Date
    let totalHours: Double
    let workHours: Double
    let personalHours: Double
    let topLocationName: String?
    let vibe: WeeklyVibe
}

enum WeeklyVibe: String {
    case grinder = "The Grinder"
    case balanced = "Zen Master"
    case socialite = "Social Butterfly"
    case homebody = "Homebody"
    case adventurer = "Adventurer"
    case unknown = "Mystery"

    var emoji: String {
        switch self {
        case .grinder: return "💼"
        case .balanced: return "🧘"
        case .socialite: return "🥳"
        case .homebody: return "🏠"
        case .adventurer: return "🗺️"
        case .unknown: return "❓"
        }
    }

    var description: String {
        switch self {
        case .grinder: return "You put in the work this week!"
        case .balanced: return "Perfectly balanced, as all things should be."
        case .socialite: return "You were out and about!"
        case .homebody: return "There's no place like home."
        case .adventurer: return "Always on the move!"
        case .unknown: return "Not enough data to vibe check."
        }
    }

    var color: Color {
        switch self {
        case .grinder: return .blue
        case .balanced: return .green
        case .socialite: return .purple
        case .homebody: return .orange
        case .adventurer: return .red
        case .unknown: return .gray
        }
    }
}

struct WeeklyRecapGenerator {
    static func generate(logs: [LocationLog], locations: [TrackedLocation]) -> WeeklyRecap? {
        let calendar = Calendar.current
        let now = Date()

        // Last 7 days
        guard let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: now) else {
            return nil
        }

        // Filter logs
        let recentLogs = logs.filter { $0.entry >= sevenDaysAgo }
        if recentLogs.isEmpty { return nil }

        // Calculate total hours
        let totalMinutes = recentLogs.reduce(0) { $0 + $1.durationInMinutes }
        let totalHours = Double(totalMinutes) / 60.0

        // Map logs to categories
        var categoryMinutes: [LocationCategory: Int] = [:]
        var locationMinutes: [String: Int] = [:]

        for log in recentLogs {
            // Find category for this log
            // Note: This relies on name matching since logs store name.
            // Ideally we use locationId if available, falling back to name.
            let category: LocationCategory
            if let loc = locations.first(where: { $0.id == log.locationId }) {
                category = loc.fallbackCategory
            } else if let loc = locations.first(where: { $0.name == log.locationName }) {
                category = loc.fallbackCategory
            } else {
                category = .other
            }

            categoryMinutes[category, default: 0] += log.durationInMinutes
            locationMinutes[log.locationName, default: 0] += log.durationInMinutes
        }

        // Work vs Personal
        let workMins = categoryMinutes[.work] ?? 0
        let workHours = Double(workMins) / 60.0

        let personalMins = totalMinutes - workMins
        let personalHours = Double(personalMins) / 60.0

        // Top Location
        let topLocation = locationMinutes.max(by: { $0.value < $1.value })?.key

        // Determine Vibe
        let vibe: WeeklyVibe
        if totalHours < 1 {
            vibe = .unknown
        } else if Double(workMins) > Double(totalMinutes) * 0.6 {
            vibe = .grinder
        } else if categoryMinutes[.home, default: 0] > Int(Double(totalMinutes) * 0.7) {
            vibe = .homebody
        } else if (categoryMinutes[.social, default: 0] + categoryMinutes[.dining, default: 0])
            > Int(Double(totalMinutes) * 0.3)
        {
            vibe = .socialite
        } else if categoryMinutes[.travel, default: 0] > 0
            || categoryMinutes[.nature, default: 0] > 0
        {
            vibe = .adventurer
        } else {
            vibe = .balanced
        }

        return WeeklyRecap(
            startDate: sevenDaysAgo,
            endDate: now,
            totalHours: totalHours,
            workHours: workHours,
            personalHours: personalHours,
            topLocationName: topLocation,
            vibe: vibe
        )
    }
}
