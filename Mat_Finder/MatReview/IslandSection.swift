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
            .onChange(of: islands) { oldIslands, newIslands in
                if !newIslands.isEmpty, selectedIsland == nil {
                    selectedIsland = newIslands.first
                }
                print("Islands updated. Old count: \(oldIslands.count), New count: \(newIslands.count)")
            }
            .onChange(of: selectedIsland) { oldIsland, newIsland in
                print("FROM IslandSection3: Selected Gym changed from \(oldIsland?.islandName ?? "none") to \(newIsland?.islandName ?? "none")")
            }

        }

    }
}
