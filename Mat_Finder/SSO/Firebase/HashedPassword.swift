//
//  HashedPassword.swift
//  Mat_Finder
//
//  Created by Brian Romero on 4/25/25.
//

import Foundation
import SwiftUI
import CoreData

public struct HashedPassword: Codable, Sendable {   // 👈 Add Sendable here
    public let hash: Data
    public let salt: Data
    public let iterations: Int

    public init(hash: Data, salt: Data, iterations: Int) {
        self.hash = hash
        self.salt = salt
        self.iterations = iterations
    }
}
