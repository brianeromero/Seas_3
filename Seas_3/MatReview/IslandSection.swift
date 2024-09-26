//
//  IslandSection.swift
//  Seas_3
//
//  Created by Brian Romero on 9/22/24.
//

import Foundation
import SwiftUI
import CoreData

/// A SwiftUI View representing a Picker for selecting a `PirateIsland`.
struct IslandSection: View {
    var islands: [PirateIsland]
    @Binding var selectedIsland: PirateIsland?

    var body: some View {
        Section(header: Text("Select Island")) {
            Picker("Select an Island", selection: Binding<NSManagedObjectID?>(
                get: { selectedIsland?.objectID },
                set: { newID in
                    // Match the selected objectID to the correct PirateIsland.
                    if let newID = newID {
                        if let selected = islands.first(where: { $0.objectID == newID }) {
                            selectedIsland = selected // Directly assign the selected island
                        }
                    } else {
                        selectedIsland = nil // Handle the nil case
                    }
                }
            )) {
                Text("Select an Island").tag(nil as NSManagedObjectID?) // Default option

                ForEach(islands, id: \.objectID) { island in
                    Text(island.islandName ?? "Unknown Island")
                        .tag(island.objectID) // Use objectID for tagging
                }
            }
            .onChange(of: selectedIsland) { newIsland in
                if let island = newIsland {
                    print("Selected Island: \(island.islandName ?? "Unknown Island")")
                } else {
                    print("No Island selected")
                }
            }
        }
    }
}


struct IslandSection_Previews: PreviewProvider {
    static var previews: some View {
        // Create a Binding for selectedIsland
        @State var selectedIsland: PirateIsland? = nil

        // Fetch the mock islands from the preview context
        let islands = PersistenceController.preview.fetchAllPirateIslands()

        // Return the IslandSection view for preview
        return Group {
            IslandSection(islands: islands, selectedIsland: $selectedIsland)
                .previewLayout(.sizeThatFits)
                .padding()
                .previewDisplayName("Island Section Preview")
        }
    }
}
