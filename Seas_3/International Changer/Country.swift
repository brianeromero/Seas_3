//
//  RegionPickerView.swift
//  Seas_3
//
//  Created by Brian Romero on 11/14/24.
//

import Foundation
import SwiftUI

struct Country: Codable, Hashable {
    let name: Name
    let cca2: String

    struct Name: Codable, Hashable {
        let common: String
    }
}
