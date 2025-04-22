//
//  RegionPickerView.swift
//  Seas_3
//
//  Created by Brian Romero on 11/14/24.
//

import Foundation
import SwiftUI

public struct Country: Codable, Hashable {
    let name: Name
    let cca2: String
    let flag: String

    struct Name: Codable, Hashable {
        let common: String
    }
}
