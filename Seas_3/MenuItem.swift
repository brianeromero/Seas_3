//
//  MenuItem.swift
//  Seas_3
//
//  Created by Brian Romero on 10/26/24.
//

import Foundation

struct MenuItem: Identifiable {
    let id = UUID()
    var title: String
    var subMenuItems: [String]
    var padding: CGFloat
}

enum IslandMenuOption: String, CaseIterable {
    case allLocations
    case currentLocation
}
