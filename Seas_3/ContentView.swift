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


    @State private var showAddIslandForm = false
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

    @State private var showStoryboardViewController = true
    private let storyboardDisplayDuration: Double = 3.0

    @FetchRequest(
        entity: PirateIsland.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \PirateIsland.createdTimestamp, ascending: true)]
    ) private var pirateIslands: FetchedResults<PirateIsland>

    init(persistenceController: PersistenceController) {
        self._viewModel = StateObject(wrappedValue: PirateIslandViewModel(persistenceController: persistenceController))
    }
    
    var body: some View {
        NavigationView {
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
                        NavigationLink(destination: IslandDetailView(island: island, selectedDestination: $viewModel.selectedDestination)) {
                            islandRowView(island: island)
                        }
                    }
                    .onDelete { indexSet in
                        deleteItems(at: indexSet)
                    }
                }
                .navigationTitle("Gyms")
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(action: {
                            showAddIslandForm.toggle()
                        }) {
                            Image(systemName: "plus")
                        }
                    }
                }
                .sheet(isPresented: $showAddIslandForm) {
                    let islandDetails = IslandDetails(
                        islandName: islandName,
                        street: street,
                        city: city,
                        state: state,
                        postalCode: zip,  // Use postalCode instead of zip
                        selectedCountry: selectedCountry, country: selectedCountry?.name.common ?? "US"  // Pass selectedCountry as the Country object
                    )
                    AddIslandFormView(
                        islandViewModel: viewModel,
                        profileViewModel: profileViewModel,
                        authViewModel: authViewModel,
                        islandDetails: islandDetails
                    )
                    .environment(\.managedObjectContext, persistenceController.viewContext)
                }


            }
        }
    }
    
    private func islandRowView(island: PirateIsland) -> some View {
        VStack(alignment: .leading) {
            Text("Gym: \(island.islandName ?? "Unknown Gym")")
            Text("Added: \(island.formattedTimestamp)")
                .font(.caption)
                .foregroundColor(.gray)
        }
    }
    
    private func deleteItems(at offsets: IndexSet) {
        withAnimation {
            offsets.forEach { index in
                let island = pirateIslands[index]
                persistenceController.viewContext.delete(island)
            }
            
            do {
                try persistenceController.viewContext.save()
            } catch {
                print("Error deleting gym: \(error.localizedDescription)")
            }
        }
    }
}
