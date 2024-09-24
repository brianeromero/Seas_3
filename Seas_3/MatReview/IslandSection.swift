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
    @Binding var selectedIsland: PirateIsland?
    let islands: FetchedResults<PirateIsland>

    var body: some View {
        Section(header: Text("Select Island")) {
            Picker("Select an Island", selection: Binding(
                get: { selectedIsland?.objectID },
                set: { newID in
                    if let newID = newID {
                        selectedIsland = islands.first(where: { $0.objectID == newID })
                    } else {
                        selectedIsland = nil
                    }
                }
            )) {
                Text("Select an Island").tag(nil as NSManagedObjectID?) // Default option
                ForEach(islands, id: \.objectID) { island in
                    Text(island.islandName ?? "Unknown Island")
                        .tag(island.objectID) // Tag the objectID directly
                }
            }
            .pickerStyle(MenuPickerStyle())
            .onChange(of: selectedIsland) { newIsland in
                print("Selected Island: \(newIsland?.islandName ?? "None")")
            }
        }
        .onAppear {
            print("Current selected island on appear: \(selectedIsland?.islandName ?? "None")")
        }
    }
}
