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
    @State private var isReviewViewPresented: Bool = false
    

    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        entity: PirateIsland.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \PirateIsland.islandName, ascending: true)]
    ) private var islands: FetchedResults<PirateIsland>

    var body: some View {
        NavigationView {
            VStack {
                TextField("Search by Gym Name, Location, etc.", text: $searchQuery)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    .onChange(of: searchQuery) { _ in
                        updateFilteredIslands()
                    }

                List(filteredIslands) { island in
                    Button(action: {
                        self.selectedIslandForReview = island
                        self.isReviewViewPresented = true // Show review view when an island is selected
                    }) {
                        Text(island.islandName)
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
                .background(
                    NavigationLink(
                        destination: Group {
                            if let selectedIslandForReview = selectedIslandForReview {
                                GymMatReviewView(selectedIsland: $selectedIslandForReview, isPresented: $isReviewViewPresented)
                                    .onChange(of: isReviewViewPresented) { newValue in
                                        if !newValue {
                                            // Navigate back to IslandMenu
                                            // You can add code here to navigate back to IslandMenu
                                        }
                                    }
                            } else {
                                EmptyView()
                            }
                        },
                        isActive: $isReviewViewPresented
                    ) {
                        EmptyView()
                    }
                )
                
            }
            .onAppear {
                updateFilteredIslands()
            }
        }
    }

    private func updateFilteredIslands() {
        let lowercasedQuery = searchQuery.lowercased()
        
        if !searchQuery.isEmpty {
            filteredIslands = Array(islands.filter { island in
                let islandName = island.islandName.lowercased()
                let islandLocation = island.islandLocation.lowercased()
                
                let gymWebsite: String
                if let url = island.gymWebsite {
                    gymWebsite = url.absoluteString.lowercased()
                } else {
                    gymWebsite = ""
                }
                
                return islandName.contains(lowercasedQuery) ||
                       islandLocation.contains(lowercasedQuery) ||
                       gymWebsite.contains(lowercasedQuery)
            })
        } else {
            filteredIslands = Array(islands)
        }
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
        
        return GymMatReviewSelect(selectedIsland: .constant(mockIsland))
            .environment(\.managedObjectContext, context)
    }
}
