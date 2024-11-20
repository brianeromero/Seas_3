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
                Text("Select Gym").tag(nil as PirateIsland?)

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
            .onChange(of: selectedIsland) {
                print("Selected Gym: \(selectedIsland?.islandName ?? "Unknown Gym")")
                showReview = true
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
