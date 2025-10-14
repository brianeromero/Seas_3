//
//  ContentView.swift
//  Seas_3
//
//  Created by Brian Romero on 6/24/24.
//

import SwiftUI
import CoreData

struct ContentView: View {
    @EnvironmentObject var persistenceController: PersistenceController
    @StateObject var viewModel: PirateIslandViewModel
    @StateObject var profileViewModel = ProfileViewModel(
        viewContext: PersistenceController.shared.viewContext,
        authViewModel: AuthViewModel.shared
    )

    private let authViewModel = AuthViewModel.shared

    // MARK: - UI State
    @State private var showAddIslandForm = false
    @State private var showStoryboardViewController = true
    private let storyboardDisplayDuration: Double = 3.0

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
        self._viewModel = StateObject(wrappedValue: PirateIslandViewModel(persistenceController: persistenceController))
    }

    // MARK: - Body
    var body: some View {
        NavigationView {
            Group {
                if showStoryboardViewController {
                    StoryboardViewControllerRepresentable(storyboardName: "MainStoryboard")
                        .ignoresSafeArea()
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + storyboardDisplayDuration) {
                                withAnimation {
                                    showStoryboardViewController = false
                                }
                            }
                        }
                } else {
                    List {
                        ForEach(pirateIslands, id: \.self) { island in
                            NavigationLink(destination: IslandDetailView(
                                island: island,
                                selectedDestination: $viewModel.selectedDestination
                            )) {
                                islandRowView(island: island)
                            }
                        }
                        .onDelete(perform: deleteItems)
                    }
                    .navigationTitle("Gyms")
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button(action: {
                                showAddIslandForm.toggle()
                            }) {
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
        }
        // ✅ Force single-column navigation style (iPhone-style on iPad)
        .navigationViewStyle(StackNavigationViewStyle())
    }

    // MARK: - Subviews
    private func islandRowView(island: PirateIsland) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(island.islandName ?? "Unknown Gym")
                .font(.headline)
            Text("Added: \(island.formattedTimestamp)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Actions
    private func deleteItems(at offsets: IndexSet) {
        withAnimation {
            offsets.map { pirateIslands[$0] }.forEach(persistenceController.viewContext.delete)
            do {
                try persistenceController.viewContext.save()
            } catch {
                print("Error deleting gym: \(error.localizedDescription)")
            }
        }
    }
}
