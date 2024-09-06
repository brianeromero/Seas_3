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
    @State private var selectedIslandForReview: PirateIsland?
    @State private var showReviewView = false

    @Environment(\.managedObjectContext) private var viewContext

    // Ensure this is not private
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
                Section(header: Text("Search by Gym Name, Location, etc.")) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)

                        TextField("Search...", text: $searchQuery)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(Color(.systemGray6))
                            .cornerRadius(8.0)
                            .textFieldStyle(PlainTextFieldStyle())
                            .onChange(of: searchQuery) { _ in
                                updateFilteredIslands()
                            }
                    }
                }

                List(filteredIslands) { island in
                    Button(action: {
                        self.selectedIslandForReview = island
                        self.showReviewView = true
                    }) {
                        Text(island.islandName ?? "Unknown Island")
                    }
                    .sheet(isPresented: $showReviewView) {
                        GymMatReviewView(selectedIsland: $selectedIslandForReview, isPresented: $showReviewView, enterZipCodeViewModel: enterZipCodeViewModel)
                    }
                }
                .listStyle(PlainListStyle())
                .navigationTitle("Select Gym for Review")
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
            print("Filtered Islands: \(filteredIslands.map { $0.islandName })") // Add this line
        } else {
            filteredIslands = Array(islands)
            print("All Islands: \(filteredIslands.map { $0.islandName })") // Add this line
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
