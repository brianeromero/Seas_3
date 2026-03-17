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

        // 1️⃣ Sort by stored HH:mm time
        let dateA = a.time.flatMap { AppDateFormatter.twentyFourHour.date(from: $0) } ?? Date.distantFuture
        let dateB = b.time.flatMap { AppDateFormatter.twentyFourHour.date(from: $0) } ?? Date.distantFuture

        if dateA != dateB {
            return dateA < dateB
        }

        // 2️⃣ Sort by discipline
        let disciplineA = a.discipline ?? ""
        let disciplineB = b.discipline ?? ""

        if disciplineA != disciplineB {
            return disciplineA < disciplineB
        }

        // 3️⃣ Sort by style
        let styleA = a.style ?? ""
        let styleB = b.style ?? ""

        return styleA < styleB
    }
}

