//
//  RegionPickerView.swift
//  Mat_Finder
//
//  Created by Brian Romero on 11/14/24.
//


import Foundation
import SwiftUI

public struct Country: Codable, Hashable, Identifiable {

    public var id: String { cca2 }

    let name: Name
    let cca2: String
    let flag: String?

    public struct Name: Codable, Hashable {
        let common: String
    }

    private enum CodingKeys: String, CodingKey {
        case name, cca2, flag
    }
}
