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
            Picker("Select Gym", selection: Binding(
                get: { selectedIsland },
                set: { newIsland in
                    // Only update the selectedIsland if it's really changed
                    if selectedIsland != newIsland {
                        selectedIsland = newIsland
                        print("from IslandSection1: Selected Gym Updated: \(newIsland?.islandName ?? "Unknown Gym")")
                    }
                }
            )) {
                Text("Select Gym").tag(nil as PirateIsland?)

                ForEach(islands, id: \.islandID) { island in
                    Text(island.islandName ?? "Unknown Gym")
                        .tag(island as PirateIsland?)
                }
            }
            .onAppear {
                // Set showReview to true only if it's the first time selecting an island
                if selectedIsland != nil {
                    showReview = true
                    print("FROM IslandSection2: Initial selected island: \(selectedIsland?.islandName ?? "Unknown Gym")")
                }
            }
            .onChange(of: selectedIsland) { newIsland in
                // Show the review UI only if the island changes
                if let newIsland = newIsland {
                    showReview = true
                    print("FROM IslandSection3: Selected Gym: \(newIsland.islandName ?? "Unknown Gym")")
                }
            }
        }
    }
}


struct IslandSection_Previews: PreviewProvider {
    static var previews: some View {
        Preview()
    }
}

struct Preview: View {
    @State var islands: [PirateIsland] = []

    var body: some View {
        IslandSection(islands: islands, selectedIsland: .constant(nil), showReview: .constant(false))
            .previewLayout(.sizeThatFits)
            .padding()
            .previewDisplayName("Gym Section Preview")
            .task {
                do {
                    islands = try await PersistenceController.preview.fetchAllPirateIslands()
                } catch {
                    print("Error fetching pirate islands: \(error.localizedDescription)")
                }
            }
    }
}
