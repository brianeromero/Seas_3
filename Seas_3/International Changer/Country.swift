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
    let flag: String // Add this property


    struct Name: Codable, Hashable {
        let common: String
    }

    // You can add a computed property if needed to access the country name easily
    var countryName: String {
        return name.common
    }
}
