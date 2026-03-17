//
//  Utilities.swift
//  Mat_Finder
//

import Foundation
import SwiftUI
import CoreData

public enum AppDateFormatter {

    // MARK: - Time only (24h)
    public static let twentyFourHour: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    // MARK: - Time only (12h)
    public static let twelveHour: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    // MARK: - Full date + time
    public static let full: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd/yyyy HH:mm:ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    // MARK: - Medium style date + time
    public static let mediumDateTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, h:mm a"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    // MARK: - Timestamp for AppDayOfWeek
    public static let timestamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
    
    // MARK: - Weekday Formatter
    public static let weekday: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
    
    static func weekdayString(from date: Date) -> String {
        let calendar = Calendar.current
        return weekday.weekdaySymbols[
            calendar.component(.weekday, from: date) - 1
        ]
    }
}

extension AppDateFormatter {
    // Converts 24h or 12h string to Date
    static func stringToDate(_ string: String) -> Date? {
        twentyFourHour.date(from: string) ?? twelveHour.date(from: string)
    }
    
    // Converts Date to 24h string
    static func dateToString(_ date: Date) -> String {
        twentyFourHour.string(from: date)
    }
}
