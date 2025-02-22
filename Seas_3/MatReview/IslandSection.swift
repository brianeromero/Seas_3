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
            .onChange(of: islands) { _ in
                if !islands.isEmpty, selectedIsland == nil {
                    selectedIsland = islands.first
                }
            }
            .onAppear {
                print("FROM IslandSection2: Initial selected island: \(selectedIsland?.islandName ?? "No island selected initially.")")
            }
            .onChange(of: selectedIsland) { newIsland in
                print("FROM IslandSection3: Selected Gym: \(newIsland?.islandName ?? "No island selected.")")
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
