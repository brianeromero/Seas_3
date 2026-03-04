//
//  MatTime+Extensions.swift
//  Mat_Finder
//
//  Created by Brian Romero on 3/3/26.
//

import Foundation

extension MatTime {

    func formattedHeader(includeDay: Bool = true) -> String {

        var parts: [String] = []

        if includeDay,
           let day = appDayOfWeek?.day {
            parts.append(day.capitalized)
        }

        if kids {
            parts.append("Kids")
        }

        if womensOnly {
            parts.append("Women's")
        }

        if openMat {
            parts.append("Open Mat")
        } else {
            if gi { parts.append("Gi") }
            if noGi { parts.append("NoGi") }
        }

        return parts.isEmpty
            ? (type ?? "Class")
            : parts.joined(separator: " ")
    }
}
