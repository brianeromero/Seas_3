//
//  DaysOfWeekFormViewModel.swift
//  Seas_3
//
//  Created by Brian Romero on 7/14/25.
//

import Foundation
import SwiftUI
import CoreData
import os.log

class DaysOfWeekFormViewModel: ObservableObject {
    @Published var searchQuery: String = ""
    @Published var filteredIslands: [PirateIsland] = []
    @Published var showNoMatchAlert: Bool = false
    @Published var isLoading: Bool = false

    private var debounceTimer: Timer?

    init(initialIslands: [PirateIsland]) {
        self.filteredIslands = initialIslands
    }

    func updateFilteredIslands(with pirateIslands: FetchedResults<PirateIsland>) {
        debounceTimer?.invalidate()
        debounceTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.performFiltering(with: pirateIslands)
            }
        }
    }

    func forceUpdateFilteredIslands(with pirateIslands: FetchedResults<PirateIsland>) {
        debounceTimer?.invalidate()
        DispatchQueue.main.async {
            self.performFiltering(with: pirateIslands)
        }
    }

    private func performFiltering(with pirateIslands: FetchedResults<PirateIsland>) {
        os_log("DaysOfWeekFormViewModel: performFiltering called. Query: '%{public}s'", log: OSLog.default, type: .info, searchQuery)
        self.isLoading = true // Set isLoading true here, just before filtering starts
        let lowercasedQuery = self.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        if lowercasedQuery.isEmpty {
            self.filteredIslands = Array(pirateIslands)
            self.showNoMatchAlert = false
            self.isLoading = false
            return
        }

        let filtered = pirateIslands.filter { island in
            // Now, we correctly include island.islandLocation to be searched for zip codes.
            let properties = [
                island.islandName,
                island.islandLocation, // This is where the zip code would be if it's part of the address string
                island.gymWebsite?.absoluteString,
                island.country // You also have 'country' now, which could be searched
            ]

            // Filter by any of the properties that contain the lowercased query
            return properties.compactMap { $0?.lowercased() }.contains { $0.contains(lowercasedQuery) }
        }

        self.filteredIslands = filtered
        self.showNoMatchAlert = !self.searchQuery.isEmpty && self.filteredIslands.isEmpty
        os_log("DaysOfWeekFormViewModel: Filtering complete. Result count: %d. Is Loading: %{public}@", log: OSLog.default, type: .info, filtered.count, isLoading.description)
        self.isLoading = false // Set isLoading false after filtering is done
    }
}
