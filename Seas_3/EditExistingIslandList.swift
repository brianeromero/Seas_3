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
    var body: some View {
        NavigationView {
            EditExistingIslandListContent()
                .padding()
        }
    }
}


struct EditExistingIslandListContent: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        entity: PirateIsland.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \PirateIsland.createdTimestamp, ascending: true)]
    ) private var islands: FetchedResults<PirateIsland>
    
    @State private var searchQuery: String = ""
    @State private var showNoMatchAlert: Bool = false
    @State private var filteredIslands: [PirateIsland] = []
    
    @State private var debounceTimer: Timer? = nil

    var body: some View {
        VStack(alignment: .leading) {
            SearchHeader()
            SearchBar(text: $searchQuery)
                .onChange(of: searchQuery) { newValue in
                    updateSearchResults()
                }
            IslandList(islands: filteredIslands)
        }
        .alert(isPresented: $showNoMatchAlert) {
            Alert(
                title: Text("No Match Found"),
                message: Text("No gyms match your search criteria."),
                dismissButton: .default(Text("OK"))
            )
        }
        .onAppear {
            updateFilteredIslands()
            logFetch()
        }
    }
    
    private func updateSearchResults() {
        debounceTimer?.invalidate()
        debounceTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
            self.updateFilteredIslands()
        }
    }
    
    private func updateFilteredIslands() {
        let lowercasedQuery = searchQuery.lowercased()
        filteredIslands = islands.filter { matchesIsland($0, query: lowercasedQuery) }
        showNoMatchAlert = filteredIslands.isEmpty && !searchQuery.isEmpty
    }
    
    private func matchesIsland(_ island: PirateIsland, query: String) -> Bool {
        let properties = [
            island.islandName,
            island.islandLocation,
            island.gymWebsite?.absoluteString,
            String(island.latitude),
            String(island.longitude)
        ]
        
        return properties.compactMap { $0?.lowercased() }.contains { $0.contains(query.lowercased()) }
    }
    
    private func logFetch() {
        print("Fetched \(islands.count) Gym objects.")
    }
}


struct SearchHeader: View {
    var body: some View {
        Text("Search by: gym name, zip code, or address/location")
            .font(.headline)
            .padding(.bottom, 4)
            .foregroundColor(.gray)
    }
}

struct IslandList: View {
    @Environment(\.managedObjectContext) private var viewContext
    let islands: [PirateIsland]
    let persistenceController = PersistenceController.shared

    var body: some View {
        List {
            ForEach(islands) { island in
                NavigationLink(destination: EditExistingIsland(island: island, islandViewModel: PirateIslandViewModel(persistenceController: persistenceController))) {
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
    }
}

struct EditExistingIslandList_Previews: PreviewProvider {
    static var previews: some View {
        let persistenceController = PersistenceController.shared
        
        // Create example islands for preview
        let context = persistenceController.viewContext
        let island1 = PirateIsland(context: context)
        island1.islandName = "Sample Gym 1"
        island1.islandLocation = "123 Main St"
        
        let island2 = PirateIsland(context: context)
        island2.islandName = "Sample Gym 2"
        island2.islandLocation = "456 Elm St"
        
        // Save context changes
        try? context.save()
        
        return EditExistingIslandList()
            .environment(\.managedObjectContext, context)
            .previewDisplayName("Edit Existing Gyms List")
    }
}
