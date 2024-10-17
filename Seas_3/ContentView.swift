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

    @State private var showAddIslandForm = false
    @State private var islandName = ""
    @State private var createdByUserId = ""
    @State private var gymWebsite = ""
    @State private var gymWebsiteURL: URL?
    
    @State private var selectedIsland: PirateIsland? = nil // Add this property
    
    // Define state variables for address components
    @State private var street = ""
    @State private var city = ""
    @State private var state = ""
    @State private var zip = ""
    
    // State variable to control the display of StoryboardViewController
    @State private var showStoryboardViewController = true

    @FetchRequest(
        entity: PirateIsland.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \PirateIsland.createdTimestamp, ascending: true)]
    ) private var pirateIslands: FetchedResults<PirateIsland>

    // Updated init method
    init(persistenceController: PersistenceController) {
        self._viewModel = StateObject(wrappedValue: PirateIslandViewModel(persistenceController: persistenceController))
    }
    
    var body: some View {
        NavigationView {
            if showStoryboardViewController {
                StoryboardViewControllerRepresentable(storyboardName: "MainStoryboard")
                    .ignoresSafeArea()
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
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
                    AddIslandFormView(
                        islandName: $islandName,
                        street: $street,
                        city: $city,
                        state: $state,
                        zip: $zip,
                        createdByUserId: $createdByUserId,
                        gymWebsite: $gymWebsite,
                        gymWebsiteURL: $gymWebsiteURL
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

#if DEBUG
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(persistenceController: PersistenceController.preview) // Inject preview instance for previews
    }
}
#endif
