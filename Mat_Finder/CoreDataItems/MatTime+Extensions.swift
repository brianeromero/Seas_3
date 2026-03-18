//
//  MatTime+Extensions.swift
//  Mat_Finder
//
//  Created by Brian Romero on 3/3/26.
//
//


import Foundation

struct ClassBadge: Identifiable {
    var id: String { text }
    let text: String
    let color: String
}

extension MatTime {
    
    var badges: [ClassBadge] {
        
        var result: [ClassBadge] = []
        
        // Discipline badge
        if let disciplineRaw = discipline,
           let disciplineEnum = Discipline(rawValue: disciplineRaw) {
            
            result.append(
                ClassBadge(
                    text: disciplineEnum.displayName,
                    color: disciplineEnum.badgeColor
                )
            )
            
            if disciplineEnum == .openMat {
                return result
            }
        }
        
        // Custom style takes priority
        if let custom = customStyle,
           !custom.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            
            result.append(
                ClassBadge(
                    text: custom,
                    color: "gray"
                )
            )
            
        } else if let styleRaw = style,
                  let styleEnum = Style(rawValue: styleRaw) {
            
            result.append(
                ClassBadge(
                    text: styleEnum.displayName,
                    color: styleEnum.badgeColor
                )
            )
        }
        
        // Category badges
        if kids {
            result.append(ClassBadge(text: "Kids", color: "green"))
        }
        
        if womensOnly {
            result.append(ClassBadge(text: "Women's", color: "pink"))
        }
        
        return result
    }
    
    func formattedHeader(includeDay: Bool = true) -> String {
        
        var parts: [String] = []
        
        // Optional day
        if includeDay,
           let day = appDayOfWeek?.day {
            parts.append(day.capitalized)
        }
        
        // Category first
        if kids {
            parts.append("Kids")
        } else if womensOnly {
            parts.append("Women's")
        }
        
        // Discipline
        if let disciplineRaw = discipline,
           let disciplineEnum = Discipline(rawValue: disciplineRaw) {
            parts.append(disciplineEnum.displayName)
        }
        
        // Style
        if let custom = customStyle,
           !custom.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            parts.append(custom)
        } else if let styleRaw = style,
                  let styleEnum = Style(rawValue: styleRaw) {
            parts.append(styleEnum.displayName)
        }
        
        return parts.isEmpty ? "Class" : parts.joined(separator: " ")
    }
}

// MARK: - Schedule Sorting
extension MatTime {
    
    static func scheduleSort(_ a: MatTime, _ b: MatTime) -> Bool {
        
        let dateA = a.parsedTime ?? Date.distantFuture
        let dateB = b.parsedTime ?? Date.distantFuture
        
        if dateA != dateB {
            return dateA < dateB
        }
        
        let disciplineA = a.disciplineSortRank
        let disciplineB = b.disciplineSortRank
        
        if disciplineA != disciplineB {
            return disciplineA < disciplineB
        }
        
        let styleA = a.styleSortRank
        let styleB = b.styleSortRank
        
        if styleA != styleB {
            return styleA < styleB
        }
        
        let headerA = a.formattedHeader(includeDay: false)
        let headerB = b.formattedHeader(includeDay: false)
        
        return headerA.localizedCaseInsensitiveCompare(headerB) == .orderedAscending
    }
    
    static func nextClass(from times: [MatTime], day: DayOfWeek?) -> MatTime? {
        
        guard let day else { return nil }
        
        let upcoming = times.compactMap { matTime -> (MatTime, Date)? in
            guard let time = matTime.time,
                  let date = MatTime.nextDate(for: day, time: time) else {
                return nil
            }
            
            return (matTime, date)
        }
        .sorted { $0.1 < $1.1 }
        
        return upcoming.first?.0
    }
}

private extension MatTime {
    
    var disciplineSortRank: Int {
        guard let raw = discipline,
              let disciplineEnum = Discipline(rawValue: raw) else {
            return 99
        }
        
        switch disciplineEnum {
        case .bjjGi:
            return 0
        case .bjjNoGi:
            return 1
        case .openMat:
            return 2
        case .wrestling:
            return 3
        case .striking:
            return 4
        case .mma:
            return 5
        case .mobility:
            return 6
        case .judo:
            return 7
        }
    }
    
    var styleSortRank: Int {
        guard let raw = style,
              let styleEnum = Style(rawValue: raw) else {
            return customStyleSortRank
        }

        switch styleEnum {
        case .fundamentals:
            return 0
        case .conditioning:
            return 1
        case .drilling:
            return 2
        case .sparring:
            return 3
        case .competition:
            return 4
        case .advanced:
            return 5

        case .muayThai:
            return 10
        case .kickboxing:
            return 11
        case .boxing:
            return 12
        case .kravMaga:
            return 13
        case .selfDefense:
            return 14
        case .cardioKickboxing:
            return 15

        case .yoga:
            return 20
        case .flow:
            return 21
        case .stretching:
            return 22
        case .recovery:
            return 23

        case .custom:
            return customStyleSortRank
        }
    }
    
    var customStyleSortRank: Int {
        let custom = customStyle?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? ""

        guard !custom.isEmpty else { return 99 }

        if custom.contains("fundament") { return 0 }
        if custom.contains("conditioning") { return 1 }
        if custom.contains("drilling") { return 2 }
        if custom.contains("sparring") { return 3 }
        if custom.contains("competition") { return 4 }
        if custom.contains("advanced") { return 5 }

        if custom.contains("muay thai") { return 10 }
        if custom.contains("kickboxing") { return 11 }
        if custom.contains("boxing") { return 12 }
        if custom.contains("krav") { return 13 }
        if custom.contains("self-defense") || custom.contains("self defense") { return 14 }
        if custom.contains("cardio") { return 15 }

        if custom.contains("yoga") { return 20 }
        if custom.contains("flow") { return 21 }
        if custom.contains("stretch") { return 22 }
        if custom.contains("recovery") { return 23 }

        return 99
    }
}

extension MatTime {
    
    var displayTime: String {
        guard let time,
              let date = AppDateFormatter.stringToDate(time) else {
            return time ?? ""
        }
        
        return AppDateFormatter.twelveHour.string(from: date)
    }
    
    var nextClassLabel: String {
        guard let date = parsedTime else { return "" }
        
        let calendar = Calendar.current
        let now = Date()
        let timeString = AppDateFormatter.twelveHour.string(from: date)
        
        if calendar.isDate(date, inSameDayAs: now) {
            return "Today at \(timeString)"
        }
        
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now),
           calendar.isDate(date, inSameDayAs: tomorrow) {
            return "Tomorrow at \(timeString)"
        }
        
        let weekday = AppDateFormatter.weekdayString(from: date)
        return "\(weekday) at \(timeString)"
    }
    
    var parsedTime: Date? {
        guard let time else { return nil }
        return AppDateFormatter.stringToDate(time)
    }
}

// MARK: - Date Helpers
extension MatTime {
    
    static func nextDate(for day: DayOfWeek, time: String) -> Date? {
        
        guard let timeDate = AppDateFormatter.stringToDate(time) else { return nil }
        
        let calendar = Calendar.current
        let now = Date()
        let targetWeekday = day.number
        
        var components = calendar.dateComponents([.hour, .minute], from: timeDate)
        components.weekday = targetWeekday
        
        return calendar.nextDate(
            after: now,
            matching: components,
            matchingPolicy: .nextTime
        )
    }
}
