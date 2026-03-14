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

        // Discipline badge first
        if let disciplineString = discipline,
           let disciplineEnum = Discipline(rawValue: disciplineString) {

            result.append(
                ClassBadge(
                    text: disciplineEnum.displayName,
                    color: disciplineEnum.badgeColor
                )
            )
        }

        // Style badge second
        if let styleString = style,
           let styleEnum = Style(rawValue: styleString),
           styleEnum != .openMat {

            result.append(
                ClassBadge(
                    text: styleEnum.displayName,
                    color: styleEnum.badgeColor
                )
            )

        }
        // ⭐ Custom style badge (only if it is not already a defined Style)
        else if let custom = customStyle,
                !custom.isEmpty,
                Style(rawValue: custom.lowercased()) == nil {

            result.append(
                ClassBadge(
                    text: custom,
                    color: "gray"
                )
            )
        }

        // Category badges last
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
        
        if includeDay,
           let day = appDayOfWeek?.day {
            parts.append(day.capitalized)
        }
        
        // Class category
        if kids {
            parts.append("Kids")
        } else if womensOnly {
            parts.append("Women's")
        }
        
        parts.append(scheduleType())
        
        return parts.isEmpty
        ? "Class"
        : parts.joined(separator: " ")
    }
    
    func scheduleType() -> String {

        if let custom = customStyle, !custom.isEmpty {
            return custom
        }

        if openMat {
            return "Open Mat"
        }

        guard let disciplineString = discipline,
              let disciplineEnum = Discipline(rawValue: disciplineString)
        else {
            return style ?? "Class"
        }

        if let styleValue = style,
           let styleEnum = Style(rawValue: styleValue) {

            return "\(disciplineEnum.displayName) \(styleEnum.displayName)"
        }

        return disciplineEnum.displayName
    }
}
