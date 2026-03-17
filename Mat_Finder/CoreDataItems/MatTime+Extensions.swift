//
//  MatTime+Extensions.swift
//  Mat_Finder
//
//  Created by Brian Romero on 3/3/26.
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
        if let custom = customStyle, !custom.isEmpty {

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
        if let custom = customStyle, !custom.isEmpty {

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

        let disciplineA = a.discipline ?? ""
        let disciplineB = b.discipline ?? ""

        if disciplineA != disciplineB {
            return disciplineA < disciplineB
        }

        let styleA = a.style ?? ""
        let styleB = b.style ?? ""

        return styleA < styleB
    }
    
    static func nextClass(from times: [MatTime], day: DayOfWeek?) -> MatTime? {

        guard let day else { return nil }

        _ = Date()

        let upcoming = times.compactMap { matTime -> (MatTime, Date)? in
            
            guard let time = matTime.time,
                  let date = MatTime.nextDate(for: day, time: time) else { return nil }

            return (matTime, date)
        }
        .sorted { $0.1 < $1.1 }

        return upcoming.first?.0
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
