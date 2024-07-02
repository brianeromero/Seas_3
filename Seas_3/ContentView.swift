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
    @StateObject var viewModel = PirateIslandViewModel(context: PersistenceController.shared.container.viewContext)

    @State private var showAddIslandForm = false
    @State private var islandName = ""
    @State private var islandLocation = ""
    @State private var createdByUserId = ""
    @State private var gymWebsite = ""
    @State private var gymWebsiteURL: URL?

    @FetchRequest(
        entity: PirateIsland.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \PirateIsland.createdTimestamp, ascending: true)]
    ) private var pirateIslands: FetchedResults<PirateIsland>

    var body: some View {
        NavigationView {
            List {
                ForEach(pirateIslands, id: \.self) { island in
                    NavigationLink(destination: IslandDetailView(island: island, selectedDestination: $viewModel.selectedDestination)) {
                        islandRowView(island: island)
                    }
                }
                .onDelete(perform: deleteItems)
            }
            .navigationTitle("Islands")
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
                    fullAddress: $islandLocation,
                    createdByUserId: $createdByUserId,
                    gymWebsite: $gymWebsite,
                    gymWebsiteURL: $gymWebsiteURL
                )
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
            }

        }
    }

    private func islandRowView(island: PirateIsland) -> some View {
        VStack(alignment: .leading) {
            Text("Gym: \(island.islandName)")
            Text("Added: \(island.formattedTimestamp)")
                .font(.caption)
                .foregroundColor(.gray)
        }
    }

    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            offsets.map { pirateIslands[$0] }.forEach { island in
                persistenceController.container.viewContext.delete(island)
            }

            do {
                try persistenceController.container.viewContext.save()
            } catch {
                print("Error deleting island: \(error.localizedDescription)")
            }
        }
    }
}

#if DEBUG
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(PersistenceController.preview)
    }
}
#endif
