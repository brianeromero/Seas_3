import SwiftUI
import CoreData
import Combine
import CoreLocation
import Foundation

enum IslandDestination: String, CaseIterable {
    case schedule = "Schedule"
    case website = "Website"
}

struct IslandDetailView: View {
    let island: PirateIsland
    @Binding var selectedDestination: IslandDestination?

    @Environment(\.managedObjectContext) private var viewContext

    var body: some View {
        IslandDetailContent(island: island, selectedDestination: $selectedDestination)
            .onAppear(perform: fetchIsland)
    }

    private func fetchIsland() {
        guard let islandID = island.islandID else {
            print("Gym ID is nil.")
            return
        }

        let fetchRequest: NSFetchRequest<PirateIsland> = PirateIsland.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "islandID == %@", islandID as CVarArg)

        print("Fetch Request: \(fetchRequest)")

        do {
            let results = try viewContext.fetch(fetchRequest)
            print("Fetched \(results.count) Gym objects.")
        } catch {
            print("Failed to fetch Gym: \(error.localizedDescription)")
            // Handle error as needed (e.g., present an alert)
        }
    }
}

struct IslandDetailContent: View {
    let island: PirateIsland
    @Binding var selectedDestination: IslandDestination?
    @State private var showMapView = false

    @Environment(\.managedObjectContext) private var viewContext // Add this line

    var body: some View {
        VStack(alignment: .leading) {
            Text(island.islandName)
                .font(.headline)
                .bold()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 10)

            Button(action: {
                showMapView = true
            }) {
                Text(island.islandLocation)
                    .foregroundColor(.blue)
                    .font(.system(size: 16, weight: .light))
                    .multilineTextAlignment(.leading)
                    .padding(.bottom, 10)
            }
            .sheet(isPresented: $showMapView) {
                IslandMapView(islands: [island])
            }

            Text("Entered By: \(island.createdByUserId ?? "Unknown")")
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 10)

            Text("Added Date: \(formattedDate(island.createdTimestamp) ?? "Unknown")")
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 10)

            ForEach(IslandDestination.allCases, id: \.self) { destination in
                if destination == .website {
                    Button(action: {
                        if let url = island.gymWebsite {
                            UIApplication.shared.open(url)
                        } else {
                            print("No website URL available")
                        }
                    }) {
                        Text("Go to \(destination.rawValue)")
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .foregroundColor(.blue)
                    }

                } else if destination == .schedule {
                    NavigationLink(destination: IslandScheduleAsCal(
                        viewModel: AppDayOfWeekViewModel(
                            selectedIsland: island,
                            repository: AppDayOfWeekRepository(persistenceController: PersistenceController.shared)
                        ),
                        pIsland: island
                    )) {
                        Text("Go to \(destination.rawValue)")
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            Spacer()
        }
        .padding()
        .navigationTitle("Gym Detail")
    }

    private func formattedDate(_ date: Date?) -> String? {
        guard let date = date else { return nil }
        return DateFormat.mediumDateTime.string(from: date)
    }
}

struct IslandDetailView_Previews: PreviewProvider {
    static var previews: some View {
        let persistenceController = PersistenceController.shared
        let context = persistenceController.viewContext

        let island = PirateIsland(context: context)
        island.islandName = "Example Gym"
        island.createdByUserId = "John Doe"
        island.createdTimestamp = Date()

        return NavigationView {
            IslandDetailView(island: island, selectedDestination: .constant(nil))
                .environment(\.managedObjectContext, context) // Ensure viewContext is provided
        }
    }
}
