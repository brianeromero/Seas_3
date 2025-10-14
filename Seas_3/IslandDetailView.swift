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
    @StateObject var viewModel: AllEnteredLocationsViewModel
    @State private var navigationPath = NavigationPath()

    init(island: PirateIsland, selectedDestination: Binding<IslandDestination?>) {
        self.island = island
        self._selectedDestination = selectedDestination
        
        let dataManager = PirateIslandDataManager(viewContext: PersistenceController.shared.viewContext)
        _viewModel = StateObject(wrappedValue: AllEnteredLocationsViewModel(dataManager: dataManager))
    }

    @Environment(\.managedObjectContext) private var viewContext

    var body: some View {
        IslandDetailContent(
            island: island,
            selectedDestination: $selectedDestination,
            viewModel: viewModel,
            navigationPath: $navigationPath
        )
        .onAppear(perform: fetchIsland)
    }

    private func fetchIsland() {
        guard let islandID = island.islandID else {
            print("Gym ID is nil.")
            return
        }

        let fetchRequest: NSFetchRequest<PirateIsland> = PirateIsland.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "islandID == %@", islandID as CVarArg)

        do {
            let results = try viewContext.fetch(fetchRequest)
            print("Fetched \(results.count) Gym objects.")
        } catch {
            print("Failed to fetch Gym: \(error.localizedDescription)")
        }
    }
}

struct IslandDetailContent: View {
    let island: PirateIsland
    @Binding var selectedDestination: IslandDestination?
    @State private var showMapView = false
    @ObservedObject var viewModel: AllEnteredLocationsViewModel
    @StateObject var mapViewModel = AppDayOfWeekViewModel(
        selectedIsland: nil,
        repository: AppDayOfWeekRepository(persistenceController: PersistenceController.shared),
        enterZipCodeViewModel: EnterZipCodeViewModel(
            repository: AppDayOfWeekRepository.shared,
            persistenceController: PersistenceController.shared
        )
    )
    @Binding var navigationPath: NavigationPath

    @Environment(\.managedObjectContext) private var viewContext

    var body: some View {
        VStack(alignment: .leading) {
            // Gym Name
            Text(island.islandName ?? "Unnamed Gym")
                .font(.headline)
                .bold()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 10)

            // Location Button
            Button(action: { showMapView = true }) {
                Text(island.islandLocation ?? "Unknown Location")
                    .foregroundColor(.blue)
                    .font(.system(size: 16, weight: .light))
                    .multilineTextAlignment(.leading)
                    .padding(.bottom, 10)
            }
            .sheet(isPresented: $showMapView) {
                ConsolidatedIslandMapView(
                    viewModel: mapViewModel,
                    enterZipCodeViewModel: EnterZipCodeViewModel(
                        repository: AppDayOfWeekRepository.shared,
                        persistenceController: PersistenceController.shared
                    ),
                    navigationPath: $navigationPath
                )
            }

            // Created By
            if let createdByUserId = island.createdByUserId {
                Text("Entered By: \(createdByUserId)")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 10)
                    .onChange(of: createdByUserId) { newValue in
                        Logger.logCreatedByIdEvent(
                            createdByUserId: newValue,
                            fileName: "IslandDetailView",
                            functionName: "body"
                        )
                    }
            } else {
                Text("Entered By: Unknown")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 10)
            }

            // Added Date
            Text("Added Date: \(formattedDate(island.createdTimestamp) ?? "Unknown")")
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 10)

            // Navigation Buttons
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
                        viewModel: mapViewModel,
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
