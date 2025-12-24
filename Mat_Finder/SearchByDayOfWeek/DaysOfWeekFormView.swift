//
//  DaysOfWeekFormView.swift
//  Mat_Finder
//
//  Created by Brian Romero on 6/26/24.
//

import SwiftUI
import CoreData

extension Binding where Value == String? {
    func toNonOptional() -> Binding<String> {
        Binding<String>(
            get: { self.wrappedValue ?? "" },
            set: { self.wrappedValue = $0 }
        )
    }
}


// MARK: - DaysOfWeekFormView
struct DaysOfWeekFormView: View {
    @ObservedObject var appDayOfWeekViewModel: AppDayOfWeekViewModel // Keep this for its other functions if needed
    
    // ✅ StateObject for the new search ViewModel
    @StateObject private var viewModel: DaysOfWeekFormViewModel
    
    @Binding var selectedIsland: PirateIsland?
    @Binding var selectedMatTime: MatTime?
    @Binding var showReview: Bool // This might not be needed in this particular view, depends on your flow
    
    @Environment(\.managedObjectContext) private var viewContext
    @State private var isSelected = false // Review if this is still needed
    @State private var navigationSelectedIsland: PirateIsland? // Review if this is still needed
    @State private var selectedDay: DayOfWeek? = nil // Review if this is still needed
    @State private var selectedMatTimes: [MatTime] = [] // Review if this is still needed
    
    // ✅ Correct placement for @FetchRequest
    @FetchRequest(
        entity: PirateIsland.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \PirateIsland.islandName, ascending: true)]
    )
    private var islands: FetchedResults<PirateIsland> // Assign the FetchRequest to a property
    
    
    // Convenience property to observe changes to the fetched results' object IDs
    private var islandObjectIDs: [NSManagedObjectID] {
        islands.map { $0.objectID }
    }
    
    // Custom initializer to pass initial islands to the ViewModel
    init(appDayOfWeekViewModel: AppDayOfWeekViewModel, selectedIsland: Binding<PirateIsland?>, selectedMatTime: Binding<MatTime?>, showReview: Binding<Bool>) {
        self.appDayOfWeekViewModel = appDayOfWeekViewModel
        self._selectedIsland = selectedIsland
        self._selectedMatTime = selectedMatTime
        self._showReview = showReview
        
        // Initialize the StateObject viewModel with an empty array.
        // The actual data will be loaded and filtered in .onAppear once 'islands' is ready.
        _viewModel = StateObject(wrappedValue: DaysOfWeekFormViewModel(initialIslands: []))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // MARK: - Search Bar
            SearchBar(text: $viewModel.searchQuery)
                .padding(.horizontal, 16)
                .onChange(of: viewModel.searchQuery) {
                    viewModel.updateFilteredIslands(with: islands)
                }
            
            // MARK: - Content
            content
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 2) {
                    Text("Gym Schedules")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text("Select Gym to View/Add Schedule")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .onAppear {
            viewModel.forceUpdateFilteredIslands(with: islands)
        }
        .onChange(of: islands.count) {
            viewModel.updateFilteredIslands(with: islands)
        }
        .onChange(of: islandObjectIDs) {
            viewModel.updateFilteredIslands(with: islands)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name.NSManagedObjectContextDidSave)) { _ in
            viewModel.forceUpdateFilteredIslands(with: islands)
        }
    }
    
    // MARK: - Subviews
    @ViewBuilder
    private var content: some View {
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
            List(viewModel.filteredIslands, id: \.self) { island in
                islandRow(for: island)
            }
            .listStyle(PlainListStyle())
        }
    }
    
    @ViewBuilder
    private func islandRow(for island: PirateIsland) -> some View {
        NavigationLink(
            destination: ScheduleFormView(
                islands: Array(islands),
                matTimes: .constant([]),           // placeholder binding
                viewModel: appDayOfWeekViewModel
            )
        ) {
            VStack(alignment: .leading) {
                Text(island.islandName ?? "Unknown Gym")
                    .font(.headline)
                Text(island.islandLocation ?? "")
                    .foregroundColor(.secondary)
            }
        }
    }
}
