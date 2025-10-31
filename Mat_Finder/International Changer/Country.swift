//
//  RegionPickerView.swift
//  Mat_Finder
//
//  Created by Brian Romero on 11/14/24.
//


import Foundation
import SwiftUI

public struct Country: Codable, Hashable, Identifiable {
    // Only for SwiftUI List usage
    public var id = UUID() // generated locally, not from JSON

    let name: Name
    let cca2: String
    let flag: String? // optional to avoid decoding errors

    public struct Name: Codable, Hashable {
        let common: String
    }

    // CodingKeys to ignore `id` during decoding/encoding
    private enum CodingKeys: String, CodingKey {
        case name, cca2, flag
    }
}
