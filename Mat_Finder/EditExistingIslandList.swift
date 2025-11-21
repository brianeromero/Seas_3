//
//  EditExistingIslandList.swift
//  Mat_Finder
//
//  Created by Brian Romero on 6/26/24.
//

import Foundation
import SwiftUI
import CoreData
import os
import OSLog // Ensure OSLog is imported for os_log



// MARK: - EditExistingIslandList (Wrapper View)
struct EditExistingIslandList: View {
    @StateObject private var persistenceController = PersistenceController.shared
    @State private var selectedIsland: PirateIsland? = nil

    @EnvironmentObject private var authViewModel: AuthViewModel
    @Binding var navigationPath: NavigationPath

    // Receive toast bindings from parent (AppRootDestinationView)
    @Binding var showGlobalToast: Bool
    @Binding var globalToastMessage: String
    @Binding var globalToastType: ToastView.ToastType

    // Update init to accept new bindings (if you had a custom init, otherwise Swift provides it)
    init(navigationPath: Binding<NavigationPath>, showGlobalToast: Binding<Bool>, globalToastMessage: Binding<String>, globalToastType: Binding<ToastView.ToastType>) {
        _navigationPath = navigationPath
        _showGlobalToast = showGlobalToast
        _globalToastMessage = globalToastMessage
        _globalToastType = globalToastType
    }

    var body: some View {
        EditExistingIslandListContent(
            viewContext: persistenceController.viewContext,
            selectedIsland: $selectedIsland,
            navigationPath: $navigationPath,
            showSuccessToast: $showGlobalToast,      // Pass global binding down
            successToastMessage: $globalToastMessage, // Pass global binding down
            successToastType: $globalToastType        // Pass global binding down
        )
        // No .showToast modifier here; it's on AppRootView
    }
}

// MARK: - EditExistingIslandListContent (Content View)
struct EditExistingIslandListContent: View {
    let viewContext: NSManagedObjectContext
    @Binding var selectedIsland: PirateIsland?

    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var enterZipCodeViewModel: EnterZipCodeViewModel

    // This ViewModel is responsible for filtering and holding the filtered data
    @StateObject private var viewModel = EditExistingIslandListViewModel()

    // Fetch all islands; the filtering happens in the ViewModel
    @FetchRequest(
        entity: PirateIsland.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \PirateIsland.createdTimestamp, ascending: true)]
    )
    private var islands: FetchedResults<PirateIsland>

    // Bindings for the global toast message
    @Binding var showSuccessToast: Bool
    @Binding var successToastMessage: String
    @Binding var successToastType: ToastView.ToastType

    @Binding var navigationPath: NavigationPath

    // Convenience property to observe changes to the fetched results' object IDs
    private var islandObjectIDs: [NSManagedObjectID] {
        islands.map { $0.objectID }
    }
    // Custom initializer to accept all bindings
    init(viewContext: NSManagedObjectContext, selectedIsland: Binding<PirateIsland?>, navigationPath: Binding<NavigationPath>, showSuccessToast: Binding<Bool>, successToastMessage: Binding<String>, successToastType: Binding<ToastView.ToastType>) {
        self.viewContext = viewContext
        self._selectedIsland = selectedIsland
        self._navigationPath = navigationPath
        self._showSuccessToast = showSuccessToast
        self._successToastMessage = successToastMessage
        self._successToastType = successToastType
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SearchBar(text: $viewModel.searchQuery)
                .onChange(of: viewModel.searchQuery) { oldValue, newValue in
                    // When search query changes, update the filtered list
                    viewModel.updateFilteredIslands(with: islands)
                }
                .padding(.horizontal, 16)

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
                IslandList(
                    // Pass the filtered list from the ViewModel
                    islands: viewModel.searchQuery.isEmpty ? Array(islands) : viewModel.filteredIslands,
                    selectedIsland: $selectedIsland,
                    searchText: $viewModel.searchQuery,
                    navigationDestination: .editExistingIsland,
                    title: "",
                    onIslandChange: { _ in }, // You might want to remove this if not needed
                    navigationPath: $navigationPath,
                    showSuccessToast: $showSuccessToast,        // Pass global binding down
                    successToastMessage: $successToastMessage,  // Pass global binding down
                    successToastType: $successToastType         // Pass global binding down
                )
            }
        }
        .background(Color(.systemBackground))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Edit Gyms")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
            }
        }
        .onAppear {
            // ✅ CRITICAL: Force a re-filter when this view appears.
            // This ensures the list is up-to-date even if a Core Data notification
            // was missed or delayed during navigation transitions.
            os_log("EditExistingIslandListContent: View appeared. Forcing filter update.", log: OSLog.default, type: .info)
            viewModel.forceUpdateFilteredIslands(with: islands)
        }
        // ✅ Keep these onChange and onReceive to react to live Core Data changes
        .onChange(of: islands.count) {
            os_log("EditExistingIslandListContent: islands count changed, re-filtering.", log: OSLog.default, type: .info)
            viewModel.updateFilteredIslands(with: islands)
        }
        .onChange(of: islandObjectIDs) {
            os_log("EditExistingIslandListContent: islands objectIDs changed, re-filtering.", log: OSLog.default, type: .info)
            viewModel.updateFilteredIslands(with: islands)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name.NSManagedObjectContextDidSave)) { _ in
            os_log("EditExistingIslandListContent: NSManagedObjectContextDidSave notification received, forcing immediate re-filter.", log: OSLog.default, type: .info)
            viewModel.forceUpdateFilteredIslands(with: islands)
        }
        // No .showToast modifier here; it's on AppRootView
    }
}


// MARK: - EditExistingIslandListViewModel
class EditExistingIslandListViewModel: ObservableObject {
    @Published var searchQuery: String = ""
    @Published var filteredIslands: [PirateIsland] = []
    @Published var showNoMatchAlert: Bool = false
    @Published var isLoading: Bool = false

    private var debounceTimer: Timer?

    // Existing debounced update function (good for search bar input)
    func updateFilteredIslands(with pirateIslands: FetchedResults<PirateIsland>) {
        // Invalidate existing timer and set a new one
        debounceTimer?.invalidate()
        debounceTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            // All filtering operations are now on the main thread
            DispatchQueue.main.async {
                self.performFiltering(with: pirateIslands)
            }
        }
    }

    // NEW: Function to force an immediate update (for Core Data save notifications)
    func forceUpdateFilteredIslands(with pirateIslands: FetchedResults<PirateIsland>) {
        debounceTimer?.invalidate() // Invalidate any pending debounce, as we want immediate action
        DispatchQueue.main.async {
            self.performFiltering(with: pirateIslands)
        }
    }

    // Helper method to consolidate filtering logic to avoid code duplication
    private func performFiltering(with pirateIslands: FetchedResults<PirateIsland>) {
        os_log("ViewModel: performFiltering called. Query: '%{public}s'", log: OSLog.default, type: .info, searchQuery)
        self.isLoading = true
        let lowercasedQuery = self.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        if lowercasedQuery.isEmpty {
            self.filteredIslands = Array(pirateIslands)
            self.showNoMatchAlert = false
            self.isLoading = false
            return
        }

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

        self.filteredIslands = filtered
        self.showNoMatchAlert = !self.searchQuery.isEmpty && self.filteredIslands.isEmpty
        os_log("ViewModel: Filtering complete. Result count: %d. Is Loading: %{public}@", log: OSLog.default, type: .info, filtered.count, isLoading.description)
        self.isLoading = false
    }
}
