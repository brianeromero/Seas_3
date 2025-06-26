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

    @Environment(\.managedObjectContext) private var viewContext
    // Ensure this matches the type passed from AppRootView
    @EnvironmentObject var enterZipCodeViewModel: AllEnteredLocationsViewModel // Changed to AllEnteredLocationsViewModel
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

    private var displayedIslands: [PirateIsland] {
        if viewModel.searchQuery.isEmpty {
            return Array(islands)
        } else {
            return viewModel.filteredIslands
        }
    }

    private func islandRowContent(island: PirateIsland) -> some View {
        VStack(alignment: .leading) {
            Text(island.islandName ?? "Unknown Gym")
                .font(.headline)
            Text(island.islandLocation ?? "")
                .foregroundColor(.secondary)
        }
    }

    // MARK: - REMOVE Helper for Navigation Destinations
    // You no longer need `destinationView` here, as AppRootDestinationView handles all AppScreen types.
    /*
    @ViewBuilder
    private func destinationView(for screen: AppScreen) -> some View {
        switch screen {
        case .review(let island):
            GymMatReviewView(localSelectedIsland: .constant(island))
                .environmentObject(authViewModel)
                .environmentObject(enterZipCodeViewModel)
                .environment(\.managedObjectContext, viewContext)

        case .viewAllReviews(let island):
            ViewReviewforIsland(
                showReview: .constant(true),
                selectedIsland: island,
                navigationPath: $navigationPath
            )
            .environmentObject(authViewModel)
            .environmentObject(enterZipCodeViewModel)
            .environment(\.managedObjectContext, viewContext)

        case .selectGymForReview:
            // This case is problematic if it tries to push itself.
            // If you need to return to the root of this view, you'd manipulate navigationPath directly.
            GymMatReviewSelect(selectedIsland: $selectedIsland, navigationPath: $navigationPath)
                .environmentObject(authViewModel)
                .environmentObject(enterZipCodeViewModel)
                .environment(\.managedObjectContext, viewContext)
        }
    }
    */

    var body: some View {
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
                ForEach(displayedIslands, id: \.objectID) { island in
                    // This NavigationLink is correct. It pushes an AppScreen value
                    // onto the navigationPath, which AppRootView's .navigationDestination
                    // will then handle by presenting AppRootDestinationView.
                    NavigationLink(value: AppScreen.review(island.objectID.uriRepresentation().absoluteString)) {
                        islandRowContent(island: island)
                            .onAppear {
                                print("🧭 NavigationLink triggered for island: \(island.islandName ?? "nil")")
                            }
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
            print("🟢 GymMatReviewSelect appeared")
            os_log("GymMatReviewSelect appeared", log: OSLog.default, type: .info)
            viewModel.updateFilteredIslands(with: islands)
        }
        .onDisappear {
            print("🔴 GymMatReviewSelect disappeared")
            os_log("GymMatReviewSelect disappeared", log: OSLog.default, type: .info)
        }
        .onChange(of: selectedIsland) { oldIsland, newIsland in
            print("SelectedIsland changed in GymMatReviewSelect from \(oldIsland?.islandName ?? "nil") to \(newIsland?.islandName ?? "nil")")
            os_log("SelectedIsland changed in GymMatReviewSelect from %{public}@ to %{public}@", log: OSLog.default, type: .info, oldIsland?.islandName ?? "nil", newIsland?.islandName ?? "nil")
        }
        // REMOVE THIS LINE: The navigationDestination modifier should NOT be here.
        // It belongs on the NavigationStack in AppRootView.
        // .navigationDestination(for: AppScreen.self) { screen in
        //     destinationView(for: screen)
        // }
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
