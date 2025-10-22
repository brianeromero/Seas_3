//
//  Extensions.swift
//  Mat_Finder
//
//  Created by Brian Romero on 8/25/24.
//

import Foundation

func == (lhs: (PirateIsland, [MatTime]), rhs: (PirateIsland, [MatTime])) -> Bool {
    lhs.0 == rhs.0 && lhs.1 == rhs.1
}

func == (lhs: [(PirateIsland, [MatTime])], rhs: [(PirateIsland, [MatTime])]) -> Bool {
    lhs.elementsEqual(rhs) { $0 == $1 }
}

func == (lhs: [DayOfWeek: [(PirateIsland, [MatTime])]], rhs: [DayOfWeek: [(PirateIsland, [MatTime])]]) -> Bool {
    lhs.elementsEqual(rhs) { $0.key == $1.key && $0.value == $1.value }
}
