//
//  IslandDetailView.swift
//  Seas_3
//
//  Created by Brian Romero on 6/26/24.
//

import SwiftUI
import CoreData
import Combine
import CoreLocation
import Foundation

enum IslandDestination: String, CaseIterable {
    case firstDestination = "Schedule"
    case secondDestination = "Website"
}

struct IslandDetailView: View {
    @ObservedObject var island: PirateIsland
    @Environment(\.managedObjectContext) private var viewContext
    @Binding var selectedDestination: IslandDestination?
    @State private var showMapView = false

    var body: some View {
        IslandDetailContent(island: island, selectedDestination: $selectedDestination)
            .onAppear(perform: fetchIslands)
    }

    private func fetchIslands() {
        guard let islandID = island.islandID as UUID? else {
            print("Island ID is nil.")
            return
        }
        
        // Fetch request for a specific island using predicate
        let fetchRequest: NSFetchRequest<PirateIsland> = PirateIsland.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "islandID == %@", islandID as CVarArg)

        // Log fetch request details for debugging
        print("Fetch Request: \(fetchRequest)")
        
        do {
            let results = try viewContext.fetch(fetchRequest)
            print("Fetched \(results.count) PirateIsland objects.")
        } catch {
            print("Failed to fetch PirateIsland: \(error.localizedDescription)")
            // Handle error as needed (e.g., present an alert)
        }
    }

}

struct IslandDetailContent: View {
    let island: PirateIsland
    @Binding var selectedDestination: IslandDestination?

    @State private var showMapView = false

    var body: some View {
        VStack(alignment: .leading) {
            Text("\(island.islandName ?? "Unknown")")
                .font(.headline)
                .bold()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 10)

            if let location = island.islandLocation {
                Button(action: {
                    showMapView = true
                }) {
                    Text(location)
                        .foregroundColor(.blue)
                        .font(.system(size: 16, weight: .light))
                        .multilineTextAlignment(.leading)
                        .padding(.bottom, 10)
                }
                .sheet(isPresented: $showMapView) {
                    IslandMapView(islands: [island])
                }
            } else {
                Text("Location: Unknown")
                    .font(.system(size: 16, weight: .light))
                    .multilineTextAlignment(.leading)
                    .padding(.bottom, 10)
            }

            Text("Entered By: \(island.createdByUserId ?? "Unknown")")
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("Added Date: \(formattedDate(island.createdTimestamp) ?? "Unknown")")
                .frame(maxWidth: .infinity, alignment: .leading)

            ForEach(IslandDestination.allCases, id: \.self) { destination in
                if destination == .secondDestination {
                    Button(action: {
                        if let url = island.gymWebsite {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        Text("Go to \(destination.rawValue)")
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .foregroundColor(.blue)
                    }
                } else if destination == .firstDestination {
                    NavigationLink(destination: AdditionalGymInfo(islandName: island.islandName ?? "")) {
                        Text("Go to \(destination.rawValue)")
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            Spacer()
        }
        .padding()
        .navigationTitle("Island Detail")
    }

    private func formattedDate(_ date: Date?) -> String? {
        guard let date = date else { return nil }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
}


struct IslandDetailView_Previews: PreviewProvider {
    static var previews: some View {
        let persistenceController = PersistenceController.shared
        let context = persistenceController.container.viewContext

        let island = PirateIsland(context: context)
        island.islandName = "Example Island"
        island.createdByUserId = "John Doe"
        island.createdTimestamp = Date()

        return NavigationView {
            IslandDetailView(island: island, selectedDestination: .constant(nil))
                .environment(\.managedObjectContext, context)
        }
    }
}
