//
//  IslandSection.swift
//  Seas_3
//
//  Created by Brian Romero on 9/22/24.
//

import Foundation
import SwiftUI
import CoreData

struct IslandSection: View {
    var islands: [PirateIsland]
    @Binding var selectedIsland: PirateIsland? // This binding now points to ViewReviewforIsland's internal state
    @Binding var showReview: Bool // Unused in this snippet, but kept for context

    var body: some View {
        Section(header: Text("Select A Gym")) {
            Picker("Select Gym", selection: $selectedIsland) {
                Text("Select a Gym").tag(nil as PirateIsland?)
                ForEach(islands, id: \.islandID) { island in
                    Text(island.islandName ?? "Unknown Gym")
                        .tag(island as PirateIsland?)
                }
            }
            .onAppear {
                if selectedIsland == nil, !islands.isEmpty {
                    selectedIsland = islands.first
                }
                print("FROM IslandSection2: Initial selected island: \(selectedIsland?.islandName ?? "No island selected initially.")")
            }
            .onChange(of: islands) { _ in
                if !islands.isEmpty, selectedIsland == nil {
                    selectedIsland = islands.first
                }
            }
            .onChange(of: selectedIsland) { newIsland in
                print("FROM IslandSection3: Selected Gym: \(newIsland?.islandName ?? "No island selected.")")
            }
        }
        // >>> REMOVE THIS LINE <<<
        // .id(selectedIsland?.islandID ?? UUID()) // This was actively causing re-initializations
    }
}
