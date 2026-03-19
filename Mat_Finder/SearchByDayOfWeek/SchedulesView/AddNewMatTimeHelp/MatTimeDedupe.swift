//
//  MatTimeDedupe.swift
//  Mat_Finder
//
//  Created by Brian Romero on 3/19/26.
//

import Foundation
import CoreData
 

enum MatTimeDedupe {

    static func raw(_ value: String?) -> String {
        value ?? ""
    }

    static func normalize(_ value: String?) -> String {
        raw(value)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func normalizeLower(_ value: String?) -> String {
        normalize(value).lowercased()
    }

    static func normalizeTime(_ value: String?) -> String {
        let raw = normalize(value)

        if raw.range(of: #"^\d{2}:\d{2}$"#, options: .regularExpression) != nil {
            return raw
        }

        if raw.range(of: #"^\d{1}:\d{2}$"#, options: .regularExpression) != nil {
            let parts = raw.split(separator: ":")
            if parts.count == 2, let hour = Int(parts[0]) {
                return String(format: "%02d:%@", hour, String(parts[1]))
            }
        }

        let pattern = #"^(\d{1,2}):(\d{2})\s*(AM|PM)$"#
        if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
            let nsRange = NSRange(raw.startIndex..<raw.endIndex, in: raw)
            if let match = regex.firstMatch(in: raw, options: [], range: nsRange),
               let hourRange = Range(match.range(at: 1), in: raw),
               let minuteRange = Range(match.range(at: 2), in: raw),
               let ampmRange = Range(match.range(at: 3), in: raw),
               var hour = Int(raw[hourRange]) {

                let minute = String(raw[minuteRange])
                let ampm = raw[ampmRange].uppercased()

                if ampm == "AM" {
                    if hour == 12 { hour = 0 }
                } else {
                    if hour != 12 { hour += 12 }
                }

                return String(format: "%02d:%@", hour, minute)
            }
        }

        return raw
    }

    static func normalizeRestriction(_ value: String?) -> String {
        normalizeLower(value)
            .replacingOccurrences(
                of: #"\byrs?\.\b"#,
                with: "years",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: #"\byrs?\b"#,
                with: "years",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: #"\byr\.\b"#,
                with: "year",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: #"\byr\b"#,
                with: "year",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: #"\s+"#,
                with: " ",
                options: .regularExpression
            )
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func normalizedDiscipline(_ value: String?) -> String {
        let normalized = normalize(value)
        return normalized.isEmpty
            ? Discipline.bjjGi.rawValue
            : normalized
    }

    static func predicate(
        appDayID: String,
        time: String?,
        discipline: String?,
        style: String?,
        customStyle: String?,
        type: String?,
        restrictionDescription: String?,
        kids: Bool,
        womensOnly: Bool,
        goodForBeginners: Bool,
        restrictions: Bool
    ) -> NSPredicate {

        let normalizedTime = normalizeTime(time)
        let normalizedDiscipline = normalizedDiscipline(discipline)
        let normalizedStyle = normalizeLower(style)
        let normalizedCustomStyle = normalizeLower(customStyle)
        let normalizedType = normalizeLower(type)
        let normalizedRestriction = normalizeRestriction(restrictionDescription)

        return NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "appDayOfWeekID == %@", appDayID),
            NSPredicate(format: "time == %@", normalizedTime),
            NSPredicate(format: "discipline == %@", normalizedDiscipline),
            NSPredicate(format: "((style == nil AND %@ == '') OR style == %@)", normalizedStyle, normalizedStyle),
            NSPredicate(format: "((customStyle == nil AND %@ == '') OR customStyle == %@)", normalizedCustomStyle, normalizedCustomStyle),
            NSPredicate(format: "((type == nil AND %@ == '') OR type == %@)", normalizedType, normalizedType),
            NSPredicate(format: "((restrictionDescription == nil AND %@ == '') OR restrictionDescription == %@)", normalizedRestriction, normalizedRestriction),
            NSPredicate(format: "kids == %@", NSNumber(value: kids)),
            NSPredicate(format: "womensOnly == %@", NSNumber(value: womensOnly)),
            NSPredicate(format: "goodForBeginners == %@", NSNumber(value: goodForBeginners)),
            NSPredicate(format: "restrictions == %@", NSNumber(value: restrictions))
        ])
    }
}
