//
//  ViewReviewSearch.swift
//  Seas_3
//
//  Created by Brian Romero on 9/20/24.
//

import SwiftUI
import CoreData

struct ViewReviewSearch: View {
    @Binding var selectedIsland: PirateIsland?
    @State private var searchQuery: String = ""
    @State private var filteredIslands: [PirateIsland] = []
    @State private var showNoMatchAlert: Bool = false
    @State private var showReview = false

    @Environment(\.managedObjectContext) private var viewContext
    var enterZipCodeViewModel: EnterZipCodeViewModel

    init(selectedIsland: Binding<PirateIsland?>, enterZipCodeViewModel: EnterZipCodeViewModel) {
        _selectedIsland = selectedIsland
        self.enterZipCodeViewModel = enterZipCodeViewModel
    }

    @FetchRequest(
        entity: PirateIsland.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \PirateIsland.islandName, ascending: true)]
    ) private var islands: FetchedResults<PirateIsland>

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Search by Island Name, Location, etc.")) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)

                        TextField("Search...", text: $searchQuery)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(Color(.systemGray6))
                            .cornerRadius(8.0)
                            .onChange(of: searchQuery) { _ in
                                updateFilteredIslands()
                            }
                    }
                }

                List(filteredIslands) { island in
                    Button(action: {
                        selectedIsland = island
                        showReview = true
                    }) {
                        Text(island.islandName ?? "Unknown Gym")
                    }
                    .background(
                        NavigationLink(destination: ViewReviewforIsland(
                            selectedIsland: $selectedIsland,
                            enterZipCodeViewModel: enterZipCodeViewModel
                        ), isActive: $showReview) {
                            EmptyView()
                        }
                    )
                }

                .listStyle(PlainListStyle())
                .navigationTitle("Explore Gym Reviews")
                .alert(isPresented: $showNoMatchAlert) {
                    Alert(
                        title: Text("No Match Found"),
                        message: Text("No Gyms match your search criteria."),
                        dismissButton: .default(Text("OK"))
                    )
                }
            }
            .onAppear {
                updateFilteredIslands()
            }
        }
    }

    private func updateFilteredIslands() {
        let lowercasedQuery = searchQuery.lowercased()

        if !searchQuery.isEmpty {
            filteredIslands = islands.filter { island in
                let nameMatch = island.islandName?.lowercased().contains(lowercasedQuery) ?? false
                let locationMatch = island.islandLocation?.lowercased().contains(lowercasedQuery) ?? false
                return nameMatch || locationMatch
            }
            print("Filtered islands: \(filteredIslands.map { $0.islandName ?? "Unknown" })")
        } else {
            filteredIslands = Array(islands)
        }

        showNoMatchAlert = filteredIslands.isEmpty && !searchQuery.isEmpty
        if showNoMatchAlert {
            print("No matches found for query: \(searchQuery)")
        }
    }
}

// Preview
struct ViewReviewSearch_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext
        let mockIsland = PirateIsland(context: context)
        mockIsland.islandName = "Mock Island"
        mockIsland.islandLocation = "Mock Location"

        let mockRepository = AppDayOfWeekRepository(persistenceController: PersistenceController.preview)
        let mockEnterZipCodeViewModel = EnterZipCodeViewModel(repository: mockRepository, context: context)

        return ViewReviewSearch(
            selectedIsland: .constant(mockIsland),
            enterZipCodeViewModel: mockEnterZipCodeViewModel
        )
        .environment(\.managedObjectContext, context)
    }
}
