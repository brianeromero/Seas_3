//
//  EditExistingIslandList.swift
//  Seas_3
//
//  Created by Brian Romero on 6/26/24.
//

import Foundation
import SwiftUI
import CoreData

// MARK: - EditExistingIslandList (Wrapper View)
struct EditExistingIslandList: View {
    @StateObject private var persistenceController = PersistenceController.shared
    @State private var selectedIsland: PirateIsland? = nil
    
    @EnvironmentObject private var authViewModel: AuthViewModel
    @Binding var navigationPath: NavigationPath

    var body: some View {
        EditExistingIslandListContent(
            viewContext: persistenceController.viewContext,
            selectedIsland: $selectedIsland,
            navigationPath: $navigationPath
        )
    }
}

// MARK: - EditExistingIslandListContent (Content View)
struct EditExistingIslandListContent: View {
    let viewContext: NSManagedObjectContext
    @Binding var selectedIsland: PirateIsland?

    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var enterZipCodeViewModel: EnterZipCodeViewModel

    @StateObject private var viewModel = EditExistingIslandListViewModel()

    @FetchRequest(
        entity: PirateIsland.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \PirateIsland.createdTimestamp, ascending: true)]
    )
    private var islands: FetchedResults<PirateIsland>
    
    @State private var showEdit: Bool = false

    @Binding var navigationPath: NavigationPath

    init(viewContext: NSManagedObjectContext, selectedIsland: Binding<PirateIsland?>, navigationPath: Binding<NavigationPath>) {
        self.viewContext = viewContext
        self._selectedIsland = selectedIsland
        self._navigationPath = navigationPath
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // "Search by..." text
            Text("Search by: gym name, postal code, or address/location") // Updated text to match image
                .font(.subheadline) // Smaller font, as in the "Select Gym to Review" image
                .foregroundColor(.secondary) // Gray/light gray color
                .padding(.horizontal, 16) // Inset padding
                .padding(.top, 8)
                .padding(.bottom, 4)
            
            SearchBar(text: $viewModel.searchQuery)
                .onChange(of: viewModel.searchQuery) { _, _ in
                    viewModel.updateFilteredIslands(with: islands)
                }
                .padding(.horizontal, 16) // Inset padding for search bar
            
            if viewModel.isLoading {
                ProgressView("Searching...")
                    .padding()
            } else if viewModel.filteredIslands.isEmpty && !viewModel.searchQuery.isEmpty {
                Spacer()
                Text("No gyms match your search criteria.")
                    .foregroundColor(.secondary)
                    .font(.subheadline)
                    .frame(maxWidth: .infinity, alignment: .center)
                Spacer()
            } else {
                // The IslandList component itself will now handle the List and NavigationLinks
                IslandList(
                    islands: viewModel.searchQuery.isEmpty ? Array(islands) : viewModel.filteredIslands,
                    selectedIsland: $selectedIsland,
                    searchText: $viewModel.searchQuery,
                    navigationDestination: .editExistingIsland, // Still passing this for IslandList's internal logic
                    title: "Edit Gyms", // Title for IslandList (which it now displays)
                    onIslandChange: { _ in },
                    navigationPath: $navigationPath // Pass navigationPath
                )
            }
        }
        .background(Color(.systemBackground)) // Overall view background
        .navigationTitle("Edit Gyms") // Set the navigation title for this screen
        .onAppear {
            viewModel.updateFilteredIslands(with: islands)
            createNewPirateIslandIfNeeded()
        }
    }
    
    private func createNewPirateIslandIfNeeded() {
        _ = PirateIsland(context: viewContext)
    }
}

// MARK: - IslandListRowContent (No changes, as it was already set up for dynamic colors and padding)
struct IslandListRowContent: View {
    let island: PirateIsland

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(island.islandName ?? "Unknown Gym")
                    .font(.headline)
                    .foregroundColor(.primary) // Adapts to Light/Dark Mode
                
                Text(island.islandLocation ?? "")
                    .font(.subheadline)
                    .foregroundColor(.secondary) // Adapts to Light/Dark Mode
            }
            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 16) // This creates the internal padding for text
        .background(Color(.systemBackground)) // Row content background
    }
}


// MARK: - Create EditExistingIslandListViewModel
// MARK: - EditExistingIslandListViewModel (No changes needed)
class EditExistingIslandListViewModel: ObservableObject {
    @Published var searchQuery: String = ""
    @Published var filteredIslands: [PirateIsland] = []
    @Published var showNoMatchAlert: Bool = false
    @Published var isLoading: Bool = false

    private var debounceTimer: Timer?

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
        DispatchQueue.main.async {
            self.isLoading = true
        }

        DispatchQueue.global(qos: .userInitiated).async {
            let lowercasedQuery = self.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let filtered = pirateIslands.filter { island in
                let properties = [
                    island.islandName,
                    island.islandLocation,
                    island.gymWebsite?.absoluteString,
                    String(island.latitude),
                    String(island.longitude)
                ]
                return properties.compactMap { $0?.lowercased() }.contains { $0.contains(lowercasedQuery) }
            }

            DispatchQueue.main.async {
                self.filteredIslands = filtered
                self.showNoMatchAlert = !self.searchQuery.isEmpty && self.filteredIslands.isEmpty
                self.isLoading = false
            }
        }
    }
}
