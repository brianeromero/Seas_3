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
            Picker("Select b Gym", selection: $selectedIsland) {
                Text("Select c Gym").tag(nil as PirateIsland?)

                ForEach(islands, id: \.self) { island in
                    Text(island.islandName ?? "Unknown Gym")
                        .tag(island)
                }
            }
            .id(selectedIsland) // Add this line
            .onAppear {
                print("Initial selected island: \(selectedIsland?.islandName ?? "Unknown Gym")")
                showReview = true
            }
            .onChange(of: selectedIsland) { newIsland in
                print("Selected Gym: \(newIsland?.islandName ?? "Unknown Gym")")
                showReview = true
            }
        }
    }
}

struct IslandSection_Previews: PreviewProvider {
    static var previews: some View {
        @State var selectedIsland: PirateIsland? = nil
        @State var showReview: Bool = false
        let islands = PersistenceController.preview.fetchAllPirateIslands()

        return Group {
            IslandSection(islands: islands, selectedIsland: $selectedIsland, showReview: $showReview)
                .previewLayout(.sizeThatFits)
                .padding()
                .previewDisplayName("Gym Section Preview")
        }
    }
}
