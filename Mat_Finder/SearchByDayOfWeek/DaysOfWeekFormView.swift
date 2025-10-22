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
            // ✅ Search Bar
            SearchBar(text: $viewModel.searchQuery)
                .onChange(of: viewModel.searchQuery) { // SwiftUI 5.9+ provides newValue implicitly
                    // Trigger the ViewModel's update method, passing the FetchRequest results
                    viewModel.updateFilteredIslands(with: islands)
                }
                .padding(.horizontal, 16)

            // ✅ Conditional display for loading, no results, or the list
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
                List {
                    ForEach(viewModel.filteredIslands, id: \.self) { island in
                        NavigationLink(
                            destination: ScheduleFormView(
                                islands: Array(islands),
                                // *** CHANGE THIS LINE ***
                                selectedIsland: .constant(island), // Pass the specific island that was tapped
                                // Make sure ScheduleFormView's selectedIsland is still a @Binding
                                // If ScheduleFormView should *not* allow changing the island via picker,
                                // then in ScheduleFormView, 'selectedIsland' should become a 'let' property.
                                // If ScheduleFormView *should* allow changing it, this becomes more complex.
                                // Let's assume for now, ScheduleFormView's IslandSection Picker is meant to allow changing.
                                // So, the ScheduleFormView's @Binding will *then* update its parent.

                                viewModel: appDayOfWeekViewModel,
                                matTimes: .constant([])
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
                .listStyle(PlainListStyle())
            }
        }
        .navigationTitle("Gym Schedules")
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Text("Select Gym to View/Add Schedule")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
        }
        .onAppear {
            // ✅ Force an initial update when the view appears.
            // This is where `islands` (from @FetchRequest) becomes available and triggers the initial load.
            viewModel.forceUpdateFilteredIslands(with: islands)
        }
        // ✅ Add onChange and onReceive for Core Data updates
        // These observe changes in the FetchRequest and Core Data context,
        // then trigger the ViewModel to re-filter.
        .onChange(of: islands.count) { // React to changes in the total count of fetched islands
            viewModel.updateFilteredIslands(with: islands)
        }
        .onChange(of: islandObjectIDs) { // React to changes in individual island object IDs (more precise for updates/deletes)
            viewModel.updateFilteredIslands(with: islands)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name.NSManagedObjectContextDidSave)) { _ in
            viewModel.forceUpdateFilteredIslands(with: islands)
        }
    }
}
