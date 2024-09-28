//
//  EditExistingIslandList.swift
//  Seas_3
//
//  Created by Brian Romero on 6/26/24.
//

import Foundation
import SwiftUI
import CoreData

struct EditExistingIslandList: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        entity: PirateIsland.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \PirateIsland.createdTimestamp, ascending: true)]
    ) private var islands: FetchedResults<PirateIsland>

    @State private var searchQuery: String = ""
    @State private var showNoMatchAlert: Bool = false
    @State private var filteredIslands: [PirateIsland] = []

    var body: some View {
        NavigationView {
            VStack(alignment: .leading) {
                Text("Search by: gym name, zip code, or address/location")
                    .font(.headline)
                    .padding(.bottom, 4)
                    .foregroundColor(.gray)

                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)

                    TextField("Search...", text: $searchQuery)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(Color(.systemGray6))
                        .cornerRadius(8.0)
                        .textFieldStyle(PlainTextFieldStyle())
                        .onChange(of: searchQuery) { newValue in
                            updateFilteredIslands()
                        }
                }
                .padding(.bottom, 16)

                List {
                    ForEach(filteredIslands) { island in
                        NavigationLink(destination: EditExistingIsland(island: island)) {
                            VStack(alignment: .leading) {
                                Text(island.islandName ?? "Unknown Gym")
                                    .font(.headline)
                                Text(island.islandLocation ?? "")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .listStyle(PlainListStyle())
                .navigationTitle("Edit Existing Gyms")
                .alert(isPresented: $showNoMatchAlert) {
                    Alert(
                        title: Text("No Match Found"),
                        message: Text("No gyms match your search criteria."),
                        dismissButton: .default(Text("OK"))
                    )
                }
            }
            .padding()
            .onAppear {
                updateFilteredIslands()
                logFetch() // Log fetch results on appearance
            }
        }
    }

    private func updateFilteredIslands() {
        let lowercasedQuery = searchQuery.lowercased()
        filteredIslands = islands.filter { island in
            let nameMatches = (island.islandName?.lowercased().contains(lowercasedQuery) ?? false)
            let locationMatches = (island.islandLocation?.lowercased().contains(lowercasedQuery) ?? false)
            let websiteMatches = (island.gymWebsite?.absoluteString.lowercased().contains(lowercasedQuery) ?? false)
            let latitudeMatches = (String(island.latitude).contains(lowercasedQuery))
            let longitudeMatches = (String(island.longitude).contains(lowercasedQuery))

            return nameMatches || locationMatches || websiteMatches || latitudeMatches || longitudeMatches
        }
        showNoMatchAlert = filteredIslands.isEmpty && !searchQuery.isEmpty
    }

    private func logFetch() {
        print("Fetched \(islands.count) Gym objects.")
    }
}

struct EditExistingIslandList_Previews: PreviewProvider {
    static var previews: some View {
        let persistenceController = PersistenceController.shared

        // Example island for preview
        let context = persistenceController.viewContext
        let island = PirateIsland(context: context)
        island.islandName = "Sample Gym"
        // Set other properties as needed...

        return NavigationView {
            EditExistingIslandList()
                .environment(\.managedObjectContext, context)
        }
    }
}
