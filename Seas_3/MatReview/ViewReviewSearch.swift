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
    var enterZipCodeViewModel: EnterZipCodeViewModel

    @StateObject private var viewModel = ViewReviewSearchViewModel()
    @FetchRequest(
        entity: PirateIsland.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \PirateIsland.islandName, ascending: true)]
    ) private var pirateIslands: FetchedResults<PirateIsland>

    var body: some View {
        NavigationView {
            VStack(alignment: .leading) {
                SearchHeader()
                SearchBar(text: $viewModel.searchQuery)
                IslandList(
                    islands: viewModel.filteredIslands,
                    selectedIsland: $selectedIsland, searchText: $viewModel.searchQuery,
                    navigationDestination: .review,
                    title: titleString
                )
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
            .onChange(of: viewModel.searchQuery) { newValue in
                os_log("Search query changed: %@", log: OSLog.default, type: .info, newValue)
                viewModel.updateFilteredIslands(with: pirateIslands)
            }
            .onChange(of: selectedIsland) { newIsland in
                if let islandName = newIsland?.islandName {
                    os_log("Selected Island: %@", log: OSLog.default, type: .info, islandName)
                } else {
                    os_log("Selected Island: nil", log: OSLog.default, type: .info)
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
        debounceTimer?.invalidate()
        debounceTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
            self.performFiltering(with: pirateIslands)
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
    

// Preview
struct ViewReviewSearch_Previews: PreviewProvider {
    static var previews: some View {
        let persistenceController = PersistenceController.preview
        
        let mockIsland1 = PirateIsland(context: persistenceController.container.viewContext)
        mockIsland1.islandID = UUID()
        mockIsland1.islandName = "Mock Island 1"
        mockIsland1.islandLocation = "123 Main Street, Miami, FL"
        mockIsland1.latitude = 25.7617
        mockIsland1.longitude = -80.1918
        mockIsland1.createdTimestamp = Date()

        let mockIsland2 = PirateIsland(context: persistenceController.container.viewContext)
        mockIsland2.islandID = UUID()
        mockIsland2.islandName = "Mock Island 2"
        mockIsland2.islandLocation = "456 Ocean Drive, Miami Beach, FL"
        mockIsland2.latitude = 25.7917
        mockIsland2.longitude = -80.1418
        mockIsland2.createdTimestamp = Date()

        do {
            try persistenceController.container.viewContext.save()
        } catch {
            print("Failed to save context: \(error.localizedDescription)")
        }

        let mockRepository = AppDayOfWeekRepository(persistenceController: persistenceController)
        let mockEnterZipCodeViewModel = EnterZipCodeViewModel(repository: mockRepository, persistenceController: persistenceController)

        return Group {
            ViewReviewSearch(
                selectedIsland: .constant(mockIsland1),
                titleString: "Explore Gym Reviews2",
                enterZipCodeViewModel: mockEnterZipCodeViewModel
            )
            .previewLayout(.sizeThatFits)
            .previewDisplayName("default")

            ViewReviewSearch(
                selectedIsland: .constant(nil),
                titleString: "Explore Gym Reviews3",
                enterZipCodeViewModel: mockEnterZipCodeViewModel
            )
            .previewLayout(.sizeThatFits)
            .previewDisplayName("emptySearchQuery")

            ViewReviewSearch(
                selectedIsland: .constant(nil),
                titleString: "Explore Gym Reviews4",
                enterZipCodeViewModel: mockEnterZipCodeViewModel
            )
            .previewLayout(.sizeThatFits)
            .previewDisplayName("noMatchesFound")
        }
    }
}
