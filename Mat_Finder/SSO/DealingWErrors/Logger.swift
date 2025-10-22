//
//  Logger.swift
//  Mat_Finder
//
//  Created by Brian Romero on 11/25/24.
//

import Foundation

class Logger {
    static var loggingCounter = 0
    
    static func log(_ message: String, view: String) {
        loggingCounter += 1
        print("(\(loggingCounter)) [\(view)] \(message)")
    }
    
    static func logCreatedByIdEvent(createdByUserId: String, fileName: String, functionName: String) {
        loggingCounter += 1
        print("(\(loggingCounter)) Setting createdByUserId in \(fileName).\(functionName): \(createdByUserId)")
    }
    
    static func logError(_ error: Error, view: String = "Unknown") {
        loggingCounter += 1
        print("ERROR (\(loggingCounter)) [\(view)] \(error.localizedDescription)")
    }
}
