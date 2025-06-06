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
    @Binding var selectedIsland: PirateIsland?
    @Binding var showReview: Bool

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
                // If selectedIsland is nil, set it to the first island from the list
                if selectedIsland == nil, !islands.isEmpty {
                    selectedIsland = islands.first
                }
                print("FROM IslandSection2: Initial selected island: \(selectedIsland?.islandName ?? "No island selected initially.")")
            }
            .onChange(of: islands) { _ in
                // If islands change and selectedIsland is nil, set to the first one
                if !islands.isEmpty, selectedIsland == nil {
                    selectedIsland = islands.first
                }
            }
            .onChange(of: selectedIsland) { newIsland in
                // Handle selected island change
                print("FROM IslandSection3: Selected Gym: \(newIsland?.islandName ?? "No island selected.")")
            }
        }
        .id(selectedIsland?.islandID ?? UUID()) // Use UUID to force view reload on islandID change
    }
}
