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
                            Text(island.islandName ?? "Unnamed Island")
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
                .padding(.horizontal, -20) // Remove extra padding
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
            (island.islandName?.lowercased().contains(lowercasedQuery) ?? false) ||
            (island.islandLocation?.lowercased().contains(lowercasedQuery) ?? false) ||
            (island.gymWebsite?.absoluteString.lowercased().contains(lowercasedQuery) ?? false) ||
            (String(island.latitude).contains(lowercasedQuery)) ||
            (String(island.longitude).contains(lowercasedQuery))
        }
        showNoMatchAlert = filteredIslands.isEmpty && !searchQuery.isEmpty
    }

    
    private func logFetch() {
        let fetchRequest: NSFetchRequest<PirateIsland> = PirateIsland.fetchRequest()
        do {
            let results = try viewContext.fetch(fetchRequest)
            print("Fetched \(results.count) PirateIsland objects.")
        } catch {
            print("Failed to fetch PirateIsland: \(error)")
        }
    }
}

struct EditExistingIslandList_Previews: PreviewProvider {
    static var previews: some View {
        let persistenceController = PersistenceController.shared

        // Example island for preview
        let context = persistenceController.container.viewContext
        let island = PirateIsland(context: context)
        island.islandName = "Sample Island"
        // Set other properties as needed...

        return NavigationView {
            EditExistingIslandList()
                .environment(\.managedObjectContext, context)
        }
    }
}
