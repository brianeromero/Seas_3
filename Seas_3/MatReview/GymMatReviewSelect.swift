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
    @State private var debounceTimer: Timer?


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
                        .onChange(of: searchQuery) { _ in
                            updateFilteredIslands()
                        }
                }

                List(filteredIslands, id: \.self) { island in
                    NavigationLink(
                        destination: GymMatReviewView(
                            localSelectedIsland: $selectedIsland,
                            enterZipCodeViewModel: enterZipCodeViewModel,
                            onIslandChange: self.handleIslandChange
                        )
                        .onAppear {
                            self.handleIslandChange(island)
                        }
                    ) {
                        VStack(alignment: .leading) {
                            Text(island.islandName ?? "Unknown Gym")
                                .font(.headline)
                            Text(island.islandLocation ?? "")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .frame(minHeight: 400, maxHeight: .infinity)
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
    
    func handleIslandChange(_ newIsland: PirateIsland?) {
        print("SELECTED ISLAND: \(newIsland?.islandName ?? "None")")
        self.selectedIsland = newIsland
    }

    private func updateFilteredIslands() {
        // Cancel any existing debounce timer and set a new one
        debounce(0.5) {
            self.performFiltering()
        }
    }

    private func performFiltering() {
        let lowercasedQuery = searchQuery.lowercased()
        
        if !searchQuery.isEmpty {
            let predicate = NSPredicate(format: "islandName CONTAINS[c] %@ OR islandLocation CONTAINS[c] %@ OR gymWebsite.absoluteString CONTAINS[c] %@", lowercasedQuery, lowercasedQuery, lowercasedQuery)
            filteredIslands = islands.filter { predicate.evaluate(with: $0) }
        } else {
            filteredIslands = Array(islands)
        }
        
        showNoMatchAlert = filteredIslands.isEmpty && !searchQuery.isEmpty
    }
}

// Custom Debounce Function
extension GymMatReviewSelect {
    func debounce(_ interval: TimeInterval, action: @escaping () -> Void) {
        debounceTimer?.invalidate()
        debounceTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { _ in
            action()
        }
    }
}

// New View for Selected Island
struct SelectedIslandView: View {
    let island: PirateIsland
    var enterZipCodeViewModel: EnterZipCodeViewModel
    var onIslandChange: (PirateIsland?) -> Void

    var body: some View {
        GymMatReviewView(
            localSelectedIsland: .constant(island),
            enterZipCodeViewModel: enterZipCodeViewModel,
            onIslandChange: onIslandChange
        )
    }
}


// Preview Setup
struct GymMatReviewSelect_Previews: PreviewProvider {
    static var previews: some View {
        let mockRepository = AppDayOfWeekRepository(persistenceController: PersistenceController.preview)
        let mockEnterZipCodeViewModel = EnterZipCodeViewModel(
            repository: mockRepository,
            persistenceController: PersistenceController.preview
        )

        // Create sample islands for preview
        let viewContext = PersistenceController.preview.container.viewContext
        let sampleIslands: [PirateIsland] = [
            PirateIsland(context: viewContext),
            PirateIsland(context: viewContext),
            PirateIsland(context: viewContext)
        ]
        
        sampleIslands[0].islandName = "Sample Gym 1"
        sampleIslands[0].islandLocation = "123 Main St, Anytown, USA"
        
        sampleIslands[1].islandName = "Sample Gym 2"
        sampleIslands[1].islandLocation = "456 Elm St, Othertown, USA"
        
        sampleIslands[2].islandName = "Sample Gym 3"
        sampleIslands[2].islandLocation = "789 Oak St, Thistown, USA"

        // Save the sample islands to the preview context
        try? viewContext.save()

        return GymMatReviewSelect(
            selectedIsland: .constant(nil),
            enterZipCodeViewModel: mockEnterZipCodeViewModel
        )
        .previewDisplayName("List of Sample Gyms")
    }
}
