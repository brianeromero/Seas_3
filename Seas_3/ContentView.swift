//
//  ContentView.swift
//  Seas_3
//
//  Created by Brian Romero on 6/24/24.
//

import SwiftUI
import CoreData

struct ContentView: View {
    @ObservedObject var persistenceController = PersistenceController.shared
    @StateObject var viewModel: PirateIslandViewModel // Assuming you have this defined

    @State private var showAddIslandForm = false
    @State private var islandName = ""
    @State private var islandLocation = ""
    @State private var createdByUserId = ""
    @State private var gymWebsite = ""
    @State private var gymWebsiteURL: URL?

    @State private var pirateIslands: [PirateIsland] = [] // Define pirateIslands array

    init() {
        let context = PersistenceController.shared.container.viewContext
        _viewModel = StateObject(wrappedValue: PirateIslandViewModel(context: context))
    }

    var body: some View {
        NavigationView {
            List {
                ForEach(pirateIslands) { island in
                    NavigationLink(destination: IslandDetailView(island: island, selectedDestination: .constant(nil))) {
                        islandRowView(island: island)
                    }
                }
                .onDelete(perform: deleteItems)
            }
            .toolbar {
                // Your toolbar items...
            }
            .sheet(isPresented: $showAddIslandForm) {
                AddIslandFormView(
                    islandName: $islandName,
                    islandLocation: $islandLocation,
                    createdByUserId: $createdByUserId,
                    gymWebsite: $gymWebsite,
                    gymWebsiteURL: $gymWebsiteURL
                )
            }
            .navigationTitle("Islands")
        }
        .onAppear(perform: fetchIslands) // Fetch islands when view appears
    }

    private func islandRowView(island: PirateIsland) -> some View {
        VStack(alignment: .leading) {
            Text("Gym: \(island.islandName ?? "Unknown")")
            if let createdTimestamp = island.createdTimestamp {
                Text("Added: \(createdTimestamp, formatter: dateFormatter)")
            } else {
                Text("Unknown Added Date")
            }
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

    private func fetchIslands() {
        let fetchRequest: NSFetchRequest<PirateIsland> = PirateIsland.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \PirateIsland.createdTimestamp, ascending: true)]

        do {
            pirateIslands = try persistenceController.container.viewContext.fetch(fetchRequest)
        } catch {
            print("Failed to fetch PirateIsland: \(error.localizedDescription)")
        }
    }

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter
    }()
}

#if DEBUG
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
#endif
