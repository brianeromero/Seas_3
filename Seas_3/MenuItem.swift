//
//  MenuItem.swift
//  Seas_3
//
//  Created by Brian Romero on 10/26/24.
//

import Foundation

struct MenuItem: Identifiable {
    let id = UUID()
    let title: String
    let subMenuItems: [String]?
}
