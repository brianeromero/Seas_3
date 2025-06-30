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
    @State private var selectedIsland: PirateIsland? = nil
    
    // ✅ Change to @EnvironmentObject for consistency
    @EnvironmentObject private var authViewModel: AuthViewModel

    var body: some View {
        EditExistingIslandListContent(
            viewContext: persistenceController.viewContext,
            selectedIsland: $selectedIsland,
            authViewModel: _authViewModel
        )
        .padding()
    }
}



struct EditExistingIslandListContent: View {
    let viewContext: NSManagedObjectContext // This is correct for CoreData access
    @Binding var selectedIsland: PirateIsland?

    // ✅ Use @EnvironmentObject for shared view models
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var enterZipCodeViewModel: EnterZipCodeViewModel // Assuming this is also provided via Environment

    // ✅ Use @StateObject for the new ViewModel
    @StateObject private var viewModel = EditExistingIslandListViewModel()

    @FetchRequest(
        entity: PirateIsland.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \PirateIsland.createdTimestamp, ascending: true)]
    )
    private var islands: FetchedResults<PirateIsland>
    
    @State private var showEdit: Bool = false // This state is still relevant to the view

    var body: some View {
        VStack(alignment: .leading) {
            SearchHeader() // Assuming this is a static view
            
            SearchBar(text: $viewModel.searchQuery) // Bind to ViewModel's searchQuery
                .onChange(of: viewModel.searchQuery) { _, _ in // Using new onChange syntax
                    viewModel.updateFilteredIslands(with: islands) // Pass fetched results to ViewModel
                }
            
            // Add a loading indicator
            if viewModel.isLoading {
                ProgressView("Searching...")
                    .padding()
            } else if viewModel.filteredIslands.isEmpty && !viewModel.searchQuery.isEmpty {
                // Show "No Match Found" only if query is not empty and no results
                Spacer()
                Text("No gyms match your search criteria.")
                    .foregroundColor(.gray)
                    .font(.subheadline)
                    .frame(maxWidth: .infinity, alignment: .center)
                Spacer()
            } else {
                IslandList(
                    islands: viewModel.searchQuery.isEmpty ? Array(islands) : viewModel.filteredIslands, // Use ViewModel's filtered results
                    selectedIsland: $selectedIsland,
                    searchText: $viewModel.searchQuery, // Bind to ViewModel's searchQuery
                    navigationDestination: .editExistingIsland, // Assuming AppScreen.editExistingIsland exists
                    title: "Edit Gyms",
                    enterZipCodeViewModel: enterZipCodeViewModel, // ✅ Use the EnvironmentObject
                    authViewModel: authViewModel, // ✅ Use the EnvironmentObject
                    onIslandChange: { _ in } // Pass through or implement as needed
                )
                // Removed the .alert here as the message is now inline
            }
        }
        .onAppear {
            // Initial filter when the view appears
            viewModel.updateFilteredIslands(with: islands)
            // logFetch() // This function is not in the ViewModel, consider moving or removing
            createNewPirateIslandIfNeeded() // This function is not in the ViewModel, consider moving or removing
        }
        // No longer need onChange for searchQuery here, handled by SearchBar's onChange
    }

    
    // These helper methods now belong in the ViewModel or are no longer needed here
    private func createNewPirateIslandIfNeeded() {
        // Check if you need to create a new PirateIsland object
        _ = PirateIsland(context: viewContext)
        // ...
    }
    
    // Removed updateSearchResults(), updateFilteredIslands(), matchesIsland(), logFetch()
    // as their logic is now within EditExistingIslandListViewModel
}


// MARK: - Create EditExistingIslandListViewModel

class EditExistingIslandListViewModel: ObservableObject {
    @Published var searchQuery: String = ""
    @Published var filteredIslands: [PirateIsland] = []
    @Published var showNoMatchAlert: Bool = false
    @Published var isLoading: Bool = false // Add loading state for UI feedback

    private var debounceTimer: Timer?

    // This method will be called by the View to initiate filtering
    func updateFilteredIslands(with pirateIslands: FetchedResults<PirateIsland>) {
        if searchQuery.isEmpty {
            filteredIslands = Array(pirateIslands)
            showNoMatchAlert = false
            isLoading = false
            return
        }

        debounceTimer?.invalidate()
        debounceTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
            self?.performFiltering(with: pirateIslands)
        }
    }

    private func performFiltering(with pirateIslands: FetchedResults<PirateIsland>) {
        // Set loading state to true while filtering is in progress
        DispatchQueue.main.async {
            self.isLoading = true
        }

        DispatchQueue.global(qos: .userInitiated).async {
            let lowercasedQuery = self.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let filtered = pirateIslands.filter { island in
                let properties = [
                    island.islandName,
                    island.islandLocation,
                    island.gymWebsite?.absoluteString, // Ensure URL is converted to String
                    String(island.latitude), // Convert Double to String
                    String(island.longitude) // Convert Double to String
                ]
                return properties.compactMap { $0?.lowercased() }.contains { $0.contains(lowercasedQuery) }
            }

            DispatchQueue.main.async {
                self.filteredIslands = filtered
                self.showNoMatchAlert = !self.searchQuery.isEmpty && self.filteredIslands.isEmpty
                self.isLoading = false // Set loading state to false after filtering
            }
        }
    }
}
