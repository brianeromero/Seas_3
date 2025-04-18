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
    @ObservedObject var authViewModel: AuthViewModel



    init(selectedIsland: Binding<PirateIsland?>, enterZipCodeViewModel: EnterZipCodeViewModel, authViewModel: AuthViewModel) {
        _selectedIsland = selectedIsland
        self.enterZipCodeViewModel = enterZipCodeViewModel
        self.authViewModel = authViewModel
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
                            enterZipCodeViewModel: enterZipCodeViewModel, authViewModel: authViewModel,
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
