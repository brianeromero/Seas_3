//
//  ViewReviewSearch.swift
//  Seas_3
//
//  Created by Brian Romero on 9/20/24.
//

import SwiftUI
import CoreData
import os

struct ViewReviewSearch: View {
    @Binding var selectedIsland: PirateIsland?
    var titleString: String

    @EnvironmentObject var enterZipCodeViewModel: AllEnteredLocationsViewModel // Corrected type name
    @EnvironmentObject var authViewModel: AuthViewModel
    
    // IMPORTANT: This navigationPath should be a BINDING
    // It must be the same `NavigationPath` instance as in AppRootView
    @Binding var navigationPath: NavigationPath // <--- Changed from @State to @Binding

    @StateObject private var viewModel = ViewReviewSearchViewModel()

    @FetchRequest(
        entity: PirateIsland.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \PirateIsland.islandName, ascending: true)]
    ) private var pirateIslands: FetchedResults<PirateIsland>

    // Make sure the init also takes the navigationPath as a binding
    init(selectedIsland: Binding<PirateIsland?>, titleString: String, navigationPath: Binding<NavigationPath>) {
        _selectedIsland = selectedIsland
        self.titleString = titleString
        _navigationPath = navigationPath // Initialize the binding
    }

    private func islandRowContent(island: PirateIsland) -> some View {
        VStack(alignment: .leading) {
            Text(island.islandName ?? "Unknown Gym")
                .font(.headline)
            Text(island.islandLocation ?? "")
                .foregroundColor(.secondary)
        }
    }

    var body: some View {
        // REMOVED: NavigationStack { ... }
        VStack(alignment: .leading) {
            SearchHeader()
            SearchBar(text: $viewModel.searchQuery)
                .onChange(of: viewModel.searchQuery) { _, _ in
                    viewModel.updateFilteredIslands(with: pirateIslands)
                }

            List {
                // Ensure pirateIslands are Hashable (via objectID.uriRepresentation().absoluteString)
                // ForEach needs a stable ID. `\.self` might work for NSManagedObject if they are Hashable.
                // If not, use `\.objectID` or a wrapper that makes them Hashable.
                ForEach(viewModel.searchQuery.isEmpty ? Array(pirateIslands) : viewModel.filteredIslands, id: \.objectID) { island in // Use .objectID for stable identity
                    // Changed to NavigationLink(value: ...) to push onto the shared path
                    NavigationLink(value: AppScreen.viewAllReviews(island.objectID.uriRepresentation().absoluteString)) {
                        islandRowContent(island: island)
                    }
                }
            }
            .frame(minHeight: 400, maxHeight: .infinity)
            .listStyle(.plain)
        }
        .navigationTitle(titleString)
        .alert(isPresented: $viewModel.showNoMatchAlert) {
            Alert(
                title: Text("No Match Found"),
                message: Text("No gyms match your search criteria."),
                dismissButton: .default(Text("OK"))
            )
        }
        .onAppear {
            os_log("ViewReviewSearch appeared (no nested NavigationStack)", log: OSLog.default, type: .info)
            viewModel.updateFilteredIslands(with: pirateIslands)
        }
        .onChange(of: selectedIsland) { _, newIsland in
            if let islandName = newIsland?.islandName {
                os_log("Selected Island (from binding in ViewReviewSearch): %@", log: OSLog.default, type: .info, islandName)
            } else {
                os_log("Selected Island (from binding in ViewReviewSearch): nil", log: OSLog.default, type: .info)
            }
        }
        // REMOVED: private func destinationView(for island: PirateIsland) -> some View
        // REMOVED: .navigationDestination here (it belongs in AppRootView)
    }
}



class ViewReviewSearchViewModel: ObservableObject {
    @Published var searchQuery: String = ""
    @Published var filteredIslands: [PirateIsland] = []
    @Published var showNoMatchAlert: Bool = false
    @Published var showReview: Bool = false
    @Published var isLoading: Bool = false
    
    // Declare debounceTimer
    private var debounceTimer: Timer?
    
    func updateFilteredIslands(with pirateIslands: FetchedResults<PirateIsland>) {
        if searchQuery.isEmpty {
            filteredIslands = Array(pirateIslands)
        } else {
            debounceTimer?.invalidate()
            debounceTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in // Added [weak self]
                self?.performFiltering(with: pirateIslands)
            }
        }
    }
    
    private func performFiltering(with pirateIslands: FetchedResults<PirateIsland>) {
        isLoading = true

        DispatchQueue.global(qos: .userInitiated).async {
            let lowercasedQuery = self.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let filteredIslands = self.filterIslands(pirateIslands, query: lowercasedQuery)

            DispatchQueue.main.async {
                self.filteredIslands = filteredIslands
                self.showNoMatchAlert = !self.searchQuery.isEmpty && self.filteredIslands.isEmpty
                self.isLoading = false
            }
        }
    }
    
    private func filterIslands(_ pirateIslands: FetchedResults<PirateIsland>, query: String) -> [PirateIsland] {
        pirateIslands.compactMap { island -> PirateIsland? in
            guard let islandName = island.islandName?.lowercased(),
                  let islandLocation = island.islandLocation?.lowercased() else {
                return nil
            }

            let nameMatch = islandName.contains(query)
            let locationMatch = islandLocation.contains(query)

            return nameMatch || locationMatch ? island : nil
        }
    }
}
