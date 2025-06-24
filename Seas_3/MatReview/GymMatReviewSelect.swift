//
//  GymMatReviewSelect.swift
//  Seas_3
//
//  Created by Brian Romero on 8/23/24.
//

import Foundation
import SwiftUI
import CoreData
import os.log // For logging, matching ViewReviewSearch



struct GymMatReviewSelect: View {
    @Binding var selectedIsland: PirateIsland?

    @EnvironmentObject var enterZipCodeViewModel: EnterZipCodeViewModel
    @EnvironmentObject var authViewModel: AuthViewModel

    @Binding var navigationPath: NavigationPath

    @StateObject private var viewModel = GymMatReviewSelectViewModel()

    @FetchRequest(
        entity: PirateIsland.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \PirateIsland.islandName, ascending: true)]
    ) private var islands: FetchedResults<PirateIsland>

    init(
        selectedIsland: Binding<PirateIsland?>,
        navigationPath: Binding<NavigationPath>
    ) {
        _selectedIsland = selectedIsland
        _navigationPath = navigationPath
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
        NavigationStack(path: $navigationPath) {
            VStack(alignment: .leading) {
                Text("Search by: gym name, zip code, or address/location")
                    .font(.headline)
                    .foregroundColor(.gray)
                    .padding(.leading)
                    .padding(.top, 8)

                SearchBar(text: $viewModel.searchQuery)
                    .onChange(of: viewModel.searchQuery) { _, _ in
                        viewModel.updateFilteredIslands(with: islands)
                    }

                List {
                    ForEach(viewModel.searchQuery.isEmpty ? Array(islands) : viewModel.filteredIslands, id: \.self) { island in
                        NavigationLink(value: AppScreen.review(island)) {
                            islandRowContent(island: island)
                        }
                    }
                }
                .frame(minHeight: 400, maxHeight: .infinity)
                .listStyle(.plain)
            }
            .navigationTitle("Select Gym to Review")
            .alert(isPresented: $viewModel.showNoMatchAlert) {
                Alert(
                    title: Text("No Match Found"),
                    message: Text("No gyms match your search criteria."),
                    dismissButton: .default(Text("OK"))
                )
            }
            .onAppear {
                os_log("GymMatReviewSelect appeared", log: OSLog.default, type: .info)
                viewModel.updateFilteredIslands(with: islands)
            }
            .onChange(of: selectedIsland) { _, newIsland in
                if let islandName = newIsland?.islandName {
                    os_log("Selected Island (from binding in GymMatReviewSelect): %@", log: OSLog.default, type: .info, islandName)
                } else {
                    os_log("Selected Island (from binding in GymMatReviewSelect): nil", log: OSLog.default, type: .info)
                }
            }
            // ✅ Add this navigationDestination modifier here!
            .navigationDestination(for: AppScreen.self) { screen in
                switch screen {
                case .review(let island):
                    // This is the actual view that will be pushed when AppScreen.review(island) is selected
                    // Make sure 'ViewReviewforIsland' or whatever your review detail view is, is correctly imported and available.
                    ViewReviewforIsland(
                        // Adjust these bindings/parameters as per your ViewReviewforIsland's init requirements
                        showReview: .constant(true), // Assuming it takes a binding or you can make it a regular var
                        selectedIsland: island,
                        navigationPath: $navigationPath
                    )
                case .selectGymForReview:
                    // This case is typically not handled by itself if you navigate *to* selectGymForReview.
                    // If you navigate *from* here, it would be handled in the parent's NavigationStack.
                    // For now, it's safer to have a fallback or ensure this path isn't reached this way.
                    Text("Selecting Gym For Review (Already in this view)")
                case .viewAllReviews:
                    Text("View All Reviews Placeholder") // Replace with your actual ViewAllReviews view
                }
            }
        }
    }
}

// MARK: - GymMatReviewSelectViewModel (No changes needed here)

class GymMatReviewSelectViewModel: ObservableObject {
    @Published var searchQuery: String = ""
    @Published var filteredIslands: [PirateIsland] = []
    @Published var showNoMatchAlert: Bool = false
    @Published var isLoading: Bool = false

    private var debounceTimer: Timer?

    func updateFilteredIslands(with pirateIslands: FetchedResults<PirateIsland>) {
        if searchQuery.isEmpty {
            filteredIslands = Array(pirateIslands)
            showNoMatchAlert = false
        } else {
            debounceTimer?.invalidate()
            debounceTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
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
