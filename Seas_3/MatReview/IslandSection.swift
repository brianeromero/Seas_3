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
            Picker("Select an Island", selection: $selectedIsland) {
                Text("Select an Island").tag(nil as PirateIsland?) // Default option

                ForEach(islands, id: \.self) { island in
                    Text(island.islandName ?? "Unknown Island")
                        .tag(island as PirateIsland?)
                }
            }
            .onChange(of: selectedIsland) { newIsland in
                print("Selected Island: \(newIsland?.islandName ?? "Unknown Island")")
            }

        }
    }
}

struct IslandSection_Previews: PreviewProvider {
    static var previews: some View {
        @State var selectedIsland: PirateIsland? = nil
        let islands = PersistenceController.preview.fetchAllPirateIslands()

        return Group {
            IslandSection(islands: islands, selectedIsland: $selectedIsland)
                .previewLayout(.sizeThatFits)
                .padding()
                .previewDisplayName("Island Section Preview")
        }
    }
}
