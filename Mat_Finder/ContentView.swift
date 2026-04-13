//
//  ContentView.swift
//  Mat_Finder
//
//  Created by Brian Romero on 6/24/24.
//

import SwiftUI
import CoreData


struct ContentView: View {
    
    @EnvironmentObject var persistenceController: PersistenceController
    
    @StateObject private var viewModel: PirateIslandViewModel
    @StateObject private var profileViewModel = ProfileViewModel()
    
    private let authViewModel = AuthViewModel.shared
    
    // MARK: - UI State
    @State private var showAddIslandForm = false
    @State private var sortByName = false
    @State private var newIslandDetails = IslandDetails()
    
    // MARK: - Fetched Results
    @FetchRequest(
        entity: PirateIsland.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \PirateIsland.islandName, ascending: true)]
    )
    private var pirateIslands: FetchedResults<PirateIsland>
    
    // MARK: - Init
    init(persistenceController: PersistenceController) {
        _viewModel = StateObject(
            wrappedValue: PirateIslandViewModel(
                persistenceController: persistenceController
            )
        )
    }
    
    // MARK: - Body
    var body: some View {
        
        VStack {
            
            Toggle("Sort by Name", isOn: $sortByName)
                .padding(.horizontal)
                .toggleStyle(SwitchToggleStyle(tint: .blue))
            
            List {
                
                ForEach(sortedIslands(), id: \.objectID) { island in
                    
                    NavigationLink(
                        value: AppScreen.viewSchedule(
                            island.objectID.uriRepresentation().absoluteString
                        )
                    ) {
                        islandRowView(island: island)
                    }
                }
                .onDelete(perform: deleteItems)
            }
            .navigationTitle("Gyms")
            .toolbar {
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    
                    Button {
                        
                        newIslandDetails = IslandDetails()
                        showAddIslandForm.toggle()
                        
                    } label: {
                        Label("Add Gym", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddIslandForm) {
                
                AddNewIsland(
                    navigationPath: .constant(NavigationPath()),
                    islandDetails: $newIslandDetails
                )
                .environment(\.managedObjectContext,
                              persistenceController.viewContext)
                .environmentObject(viewModel)
                .environmentObject(profileViewModel)
                .environmentObject(authViewModel)
            }
        }
    }


    // MARK: - Sorting
    private func sortedIslands() -> [PirateIsland] {

        let islandsArray = Array(pirateIslands)

        if sortByName {
            return islandsArray.sorted {
                ($0.islandName ?? "") < ($1.islandName ?? "")
            }
        } else {
            return islandsArray.sorted {
                ($0.createdTimestamp ?? Date()) <
                ($1.createdTimestamp ?? Date())
            }
        }
    }

    // MARK: - Row View
    private func islandRowView(island: PirateIsland) -> some View {

        VStack(alignment: .leading, spacing: 4) {

            Text(island.islandName ?? "Unknown Gym")
                .font(.headline)

            Text(island.islandLocation ?? "Unknown Location")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Text("Added: \(island.formattedTimestamp)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Delete
    private func deleteItems(at offsets: IndexSet) {

        for index in offsets {

            let island = pirateIslands[index]

            Task {

                do {

                    try await viewModel.deletePirateIsland(island)

                    print("🗑️ Deleted island \(island.islandName ?? "") successfully")

                } catch {

                    print("❌ Error deleting island: \(error.localizedDescription)")
                }
            }
        }
    }
}
