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
    @StateObject private var profileViewModel = ProfileViewModel(
        viewContext: PersistenceController.shared.viewContext,
        authViewModel: AuthViewModel.shared
    )
    
    private let authViewModel = AuthViewModel.shared

    // MARK: - UI State
    @State private var showAddIslandForm = false
    @State private var sortByName = false   // ✅ New state for sorting

    // MARK: - Gym Fields
    @State private var islandName = ""
    @State private var createdByUserId = ""
    @State private var gymWebsite = ""
    @State private var gymWebsiteURL: URL?
    @State private var islandLocation = ""
    @State private var street = ""
    @State private var city = ""
    @State private var state = ""
    @State private var zip = ""
    @State private var selectedCountry: Country?

    // MARK: - Fetched Results
    @FetchRequest(
        entity: PirateIsland.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \PirateIsland.createdTimestamp, ascending: true)]
    ) private var pirateIslands: FetchedResults<PirateIsland>

    // MARK: - Init
    init(persistenceController: PersistenceController) {
        _viewModel = StateObject(wrappedValue: PirateIslandViewModel(persistenceController: persistenceController))
    }

    // MARK: - Body
    var body: some View {
        NavigationStack {
            VStack {
                // ✅ Sort toggle
                Toggle("Sort by Name", isOn: $sortByName)
                    .padding(.horizontal)
                    .toggleStyle(SwitchToggleStyle(tint: .blue))

                List {
                    ForEach(sortedIslands(), id: \.self) { island in
                        NavigationLink(
                            destination: IslandDetailView(
                                island: island,
                                selectedDestination: $viewModel.selectedDestination
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
                            showAddIslandForm.toggle()
                        } label: {
                            Label("Add Gym", systemImage: "plus")
                        }
                        .accessibilityLabel("Add Gym")
                    }
                }
                .sheet(isPresented: $showAddIslandForm) {
                    AddIslandFormView(
                        islandViewModel: viewModel,
                        profileViewModel: profileViewModel,
                        authViewModel: authViewModel,
                        islandDetails: IslandDetails(
                            islandName: islandName,
                            street: street,
                            city: city,
                            state: state,
                            postalCode: zip,
                            selectedCountry: selectedCountry,
                            country: selectedCountry?.name.common ?? "US"
                        )
                    )
                    .environment(\.managedObjectContext, persistenceController.viewContext)
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle()) // iPhone-style on iPad
    }

    // MARK: - Helper for Sorting
    private func sortedIslands() -> [PirateIsland] {
        let islandsArray = Array(pirateIslands)
        if sortByName {
            return islandsArray.sorted { ($0.islandName ?? "") < ($1.islandName ?? "") }
        } else {
            return islandsArray.sorted { ($0.createdTimestamp ?? Date()) < ($1.createdTimestamp ?? Date()) }
        }
    }

    // MARK: - Subviews
    private func islandRowView(island: PirateIsland) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(island.islandName ?? "Unknown Gym")
                .font(.headline)
            Text(island.islandLocation ?? "Unknown Location") // ✅ show location
                .font(.subheadline)
                .foregroundColor(.secondary)
            Text("Added: \(island.formattedTimestamp)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Actions
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
