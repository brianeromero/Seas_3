//
//  HashedPassword.swift
//  Seas_3
//
//  Created by Brian Romero on 4/25/25.
//

import Foundation
import SwiftUI
import CoreData

public struct HashedPassword: Codable {
    public let hash: Data
    public let salt: Data
    public let iterations: Int

    public init(hash: Data, salt: Data, iterations: Int) {
        self.hash = hash
        self.salt = salt
        self.iterations = iterations
    }
}
