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

    // ✅ Use @EnvironmentObject to receive these, as they are provided at the top level
    @EnvironmentObject var enterZipCodeViewModel: EnterZipCodeViewModel
    @EnvironmentObject var authViewModel: AuthViewModel
    
    @State private var navigationPath = NavigationPath()

    @StateObject private var viewModel = ViewReviewSearchViewModel()

    @FetchRequest(
        entity: PirateIsland.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \PirateIsland.islandName, ascending: true)]
    ) private var pirateIslands: FetchedResults<PirateIsland>

    // Break down the List row content into a separate function
    private func islandRowContent(island: PirateIsland) -> some View {
        VStack(alignment: .leading) {
            Text(island.islandName ?? "Unknown Gym")
                .font(.headline)
            Text(island.islandLocation ?? "")
                .foregroundColor(.secondary)
        }
    }

    // Helper to create the destination view for NavigationLink
    private func destinationView(for island: PirateIsland) -> some View {
        ViewReviewforIsland(
            showReview: .constant(true),
            selectedIsland: island,
            navigationPath: $navigationPath
        )
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading) {
                SearchHeader()
                SearchBar(text: $viewModel.searchQuery)
                    .onChange(of: viewModel.searchQuery) { _, _ in
                        viewModel.updateFilteredIslands(with: pirateIslands)
                    }

                // ---
                // ✅ Fix: Simplify the List content using ForEach and the helper function
                List {
                    ForEach(viewModel.searchQuery.isEmpty ? Array(pirateIslands) : viewModel.filteredIslands, id: \.self) { island in
                        NavigationLink(destination: destinationView(for: island)) {
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
                os_log("ViewReviewSearch appeared", log: OSLog.default, type: .info)
                viewModel.updateFilteredIslands(with: pirateIslands)
            }
            .onChange(of: selectedIsland) { _, newIsland in
                if let islandName = newIsland?.islandName {
                    os_log("Selected Island (from binding in ViewReviewSearch): %@", log: OSLog.default, type: .info, islandName)
                } else {
                    os_log("Selected Island (from binding in ViewReviewSearch): nil", log: OSLog.default, type: .info)
                }
            }
        }
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
