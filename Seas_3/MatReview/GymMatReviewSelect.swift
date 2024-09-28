//
//  GymMatReviewSelect.swift
//  Seas_3
//
//  Created by Brian Romero on 8/23/24.
//

import Foundation
import SwiftUI
import CoreData

struct GymMatReviewSelect: View {
    @Binding var selectedIsland: PirateIsland?
    @State private var searchQuery: String = ""
    @State private var filteredIslands: [PirateIsland] = []
    @State private var showNoMatchAlert: Bool = false

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
                Section(header: Text("Search by: gym name, zip code, or address/location")
                            .font(.headline)
                            .foregroundColor(.gray)) {
                    SearchBar(text: $searchQuery)
                        .onChange(of: searchQuery) { newValue in
                            updateFilteredIslands()
                        }
                }

                // Use NavigationLink to display the review view consistently
                List(filteredIslands) { island in
                    NavigationLink(destination: GymMatReviewView(
                        localSelectedIsland: .constant(island),
                        isPresented: .constant(false),
                        enterZipCodeViewModel: enterZipCodeViewModel,
                        onIslandChange: { newIsland in
                            // Handle island change
                            self.selectedIsland = newIsland
                        }
                    )) {
                        Text(island.islandName ?? "Unknown Gym")
                    }
                }
                .listStyle(PlainListStyle())
                .navigationTitle("Select Gym to Review")
                .alert(isPresented: $showNoMatchAlert) {
                    Alert(
                        title: Text("No Match Found"),
                        message: Text("No gyms match your search criteria."),
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
                let predicate = NSPredicate(format: "islandName CONTAINS[c] %@ OR islandLocation CONTAINS[c] %@ OR gymWebsite.absoluteString CONTAINS[c] %@", argumentArray: [lowercasedQuery, lowercasedQuery, lowercasedQuery])
                return predicate.evaluate(with: island)
            }
            print("Filtered Islands: \(filteredIslands.map { $0.islandName })")
        } else {
            filteredIslands = Array(islands)
            print("All Islands: \(filteredIslands.map { $0.islandName })")
        }
        
        showNoMatchAlert = filteredIslands.isEmpty && !searchQuery.isEmpty
    }
}

// Preview
struct GymMatReviewSelect_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext
        
        let mockIsland = PirateIsland(context: context)
        mockIsland.islandName = "Mock Gym"
        mockIsland.islandLocation = "Mock Location"
        mockIsland.latitude = 0.0
        mockIsland.longitude = 0.0
        mockIsland.gymWebsite = URL(string: "https://www.example.com")

        // Create a mock instance of EnterZipCodeViewModel
        let mockRepository = AppDayOfWeekRepository(persistenceController: PersistenceController.preview)
        let mockEnterZipCodeViewModel = EnterZipCodeViewModel(repository: mockRepository, context: context)
        
        return GymMatReviewSelect(selectedIsland: .constant(mockIsland), enterZipCodeViewModel: mockEnterZipCodeViewModel) // Pass the view model here
            .environment(\.managedObjectContext, context)
    }
}
