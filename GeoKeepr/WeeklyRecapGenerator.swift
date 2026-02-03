import Foundation
import SwiftData
import SwiftUI

struct WeeklyRecap {
    let startDate: Date
    let endDate: Date
    let slides: [StorySlideType]
    let vibe: WeeklyVibe
}

enum StorySlideType: Identifiable {
    case intro(startDate: Date, endDate: Date)
    case grind(work: Double, personal: Double)
    case topSpot(name: String, visits: Int)
    case vibe(vibe: WeeklyVibe)
    case deepFocus(location: String, duration: String)
    case newHorizons(locations: [String])
    case weekendWarrior(weekendHours: Double, weekdayHours: Double)

    var id: String {
        switch self {
        case .intro: return "intro"
        case .grind: return "grind"
        case .topSpot: return "topSpot"
        case .vibe: return "vibe"
        case .deepFocus: return "deepFocus"
        case .newHorizons: return "newHorizons"
        case .weekendWarrior: return "weekendWarrior"
        }
    }
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
    static func generate(
        logs: [LocationLog], locations: [TrackedLocation], activeLocations: [TrackedLocation] = []
    ) -> WeeklyRecap? {
        let calendar = Calendar.current
        let now = Date()

        // Synthesize logs for active sessions
        let activeLogs = activeLocations.compactMap { location -> LocationLog? in
            guard let entryTime = location.entryTime else { return nil }
            return LocationLog(
                locationName: location.name,
                locationId: location.id,
                entry: entryTime,
                exit: now
            )
        }

        // Combine historical and active logs
        let allLogs = logs + activeLogs

        // Last 7 days
        guard let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: now) else {
            return nil
        }

        // Filter logs
        let recentLogs = allLogs.filter { $0.entry >= sevenDaysAgo }
        if recentLogs.isEmpty { return nil }

        // Calculate total hours
        let totalMinutes = recentLogs.reduce(0) { $0 + $1.durationInMinutes }
        let totalHours = Double(totalMinutes) / 60.0

        // Map logs to categories
        var categoryMinutes: [LocationCategory: Int] = [:]
        var locationMinutes: [String: Int] = [:]
        var locationVisits: [String: Int] = [:]

        for log in recentLogs {
            // Find category for this log
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
            locationVisits[log.locationName, default: 0] += 1
        }

        // Work vs Personal
        let workMins = categoryMinutes[.work] ?? 0
        let workHours = Double(workMins) / 60.0
        let personalMins = totalMinutes - workMins
        let personalHours = Double(personalMins) / 60.0

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

        // --- Build Slides ---
        var slides: [StorySlideType] = []

        // 1. Intro (Always)
        slides.append(.intro(startDate: sevenDaysAgo, endDate: now))

        // 2. The Grind (Work/Life Balance) - Always interesting
        slides.append(.grind(work: workHours, personal: personalHours))

        // 3. Top Spot (if available)
        if let topLocation = locationMinutes.max(by: { $0.value < $1.value }) {
            let visits = locationVisits[topLocation.key] ?? 1
            slides.append(.topSpot(name: topLocation.key, visits: visits))
        }

        // 4. Deep Focus (Longest Session)
        if let longestSession = recentLogs.max(by: { $0.durationInMinutes < $1.durationInMinutes }),
            longestSession.durationInMinutes >= 120
        {  // Only if >= 2 hours
            slides.append(
                .deepFocus(
                    location: longestSession.locationName, duration: longestSession.durationString))
        }

        // 5. New Horizons (New Locations visited this week)
        // Check if any location in recentLogs was NOT visited before sevenDaysAgo
        let oldLogs = allLogs.filter { $0.entry < sevenDaysAgo }
        let oldLocationNames = Set(oldLogs.map { $0.locationName })
        let newLocations = Set(recentLogs.map { $0.locationName }).subtracting(oldLocationNames)

        if !newLocations.isEmpty {
            slides.append(.newHorizons(locations: Array(newLocations).sorted()))
        }

        // 6. Weekend Warrior
        let weekendLogs = recentLogs.filter { calendar.isDateInWeekend($0.entry) }
        let weekendMinutes = weekendLogs.reduce(0) { $0 + $1.durationInMinutes }
        let weekdayMinutes = totalMinutes - weekendMinutes

        if Double(weekendMinutes) > Double(weekdayMinutes) * 0.5 && weekendMinutes > 120 {
            slides.append(
                .weekendWarrior(
                    weekendHours: Double(weekendMinutes) / 60.0,
                    weekdayHours: Double(weekdayMinutes) / 60.0))
        }

        // 7. Vibe (Always Last)
        slides.append(.vibe(vibe: vibe))

        return WeeklyRecap(
            startDate: sevenDaysAgo,
            endDate: now,
            slides: slides,
            vibe: vibe
        )
    }
}
