//
//  IslandSection.swift
//  Mat_Finder
//
//  Created by Brian Romero on 9/22/24.
//

import Foundation
import SwiftUI
import CoreData

struct IslandSection: View {
    var islands: [PirateIsland]
    @Binding var selectedIslandID: UUID?
    @Binding var showReview: Bool

    var body: some View {
        Section(header: Text("Select A Gym")) {
            Picker("Select Gym", selection: $selectedIslandID) {
                Text("Select a Gym").tag(nil as UUID?)

                ForEach(islands, id: \.islandID) { island in
                    Text(island.islandName ?? "Unknown Gym")
                        .tag(island.islandID)
                }
            }
            .onChange(of: selectedIslandID) { oldID, newID in
                print("Selected Gym changed from \(oldID?.uuidString ?? "none") to \(newID?.uuidString ?? "none")")
            }
        }
    }
}
