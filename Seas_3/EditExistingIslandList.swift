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
    @StateObject private var persistenceController = PersistenceController.shared

    var body: some View {
        EditExistingIslandListContent(viewContext: persistenceController.viewContext)
            .padding()
    }
}

struct EditExistingIslandListContent: View {
    let viewContext: NSManagedObjectContext
    @FetchRequest(
        entity: PirateIsland.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \PirateIsland.createdTimestamp, ascending: true)]
    )
    private var islands: FetchedResults<PirateIsland>
    
    @State private var searchQuery: String = ""
    @State private var showNoMatchAlert: Bool = false
    @State private var filteredIslands: [PirateIsland] = []
    @State private var debounceTimer: Timer? = nil
    @State private var selectedIsland: PirateIsland? = nil
    @State private var showReview: Bool = false

    @StateObject private var viewModel = IslandListViewModel.shared  // Add the viewModel here

    var body: some View {
        VStack(alignment: .leading) {
            SearchHeader()
            SearchBar(text: $searchQuery)
                .onChange(of: searchQuery) { _ in
                    updateSearchResults()
                }
            IslandList(
                islands: filteredIslands,
                selectedIsland: $selectedIsland,
                showReview: $showReview,
                title: "Edit Gyms",
                viewModel: viewModel // Pass the viewModel to IslandList
            )
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
        
        return properties.compactMap { $0?.lowercased() }.contains { $0.contains(query) }
    }

    private func logFetch() {
        print("Fetched \(islands.count) Gym objects.")
    }
}


// MARK: - Previews with sample data
struct EditExistingIslandList_PreviewsWithSampleData: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.shared.viewContext
        
        // Sample islands for preview
        let island1 = PirateIsland(context: context)
        island1.islandName = "Sample Gym 1"
        island1.islandLocation = "123 Main St"
        
        let island2 = PirateIsland(context: context)
        island2.islandName = "Sample Gym 2"
        island2.islandLocation = "456 Elm St"
        
        // Save context for preview
        do {
            try context.save()
        } catch {
            print("Error saving context: \(error.localizedDescription)")
        }

        return EditExistingIslandList()
            .environment(\.managedObjectContext, context)
            .previewDisplayName("Edit Existing Gyms List with sample data")
    }
}
