//
//  DaysOfWeekFormView.swift
//  Seas_3
//
//  Created by Brian Romero on 6/26/24.
//

import SwiftUI
import CoreData

extension Binding where Value == String? {
    func toNonOptional() -> Binding<String> {
        Binding<String>(
            get: { self.wrappedValue ?? "" },
            set: { self.wrappedValue = $0 }
        )
    }
}

struct DaysOfWeekFormView: View {
    @ObservedObject var viewModel: AppDayOfWeekViewModel
    @Binding var selectedIsland: PirateIsland?
    @Binding var selectedMatTime: MatTime?
    @State private var isLoading = false
    @State private var isError = false
    @State private var errorDescription = ""

    @State private var showClassScheduleModal = false
    @State private var showOpenMatModal = false
    @State private var selectedAppDayOfWeek: AppDayOfWeek?
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var searchQuery = ""
    @State private var filteredIslands: [PirateIsland] = []
    @State private var showNoMatchAlert = false
    @State private var showReview = false
    @StateObject var daysOfWeekViewModel = DaysOfWeekFormViewModel()


    @Environment(\.managedObjectContext) private var viewContext

    init(viewModel: AppDayOfWeekViewModel, selectedIsland: Binding<PirateIsland?>, selectedMatTime: Binding<MatTime?>) {
        self.viewModel = viewModel
        self._selectedIsland = selectedIsland
        self._selectedMatTime = selectedMatTime
    }

    @FetchRequest(
        entity: PirateIsland.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \PirateIsland.islandName, ascending: true)]
    ) private var islands: FetchedResults<PirateIsland>

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Search by: gym name, zip code, or address/location")
                            .font(.headline)
                            .foregroundColor(.gray)) {
                    SearchBar(text: $searchQuery)
                        .onChange(of: searchQuery) { newValue in
                            updateFilteredIslands()
                        }
                }
                List(filteredIslands, id: \.self) { island in
                    NavigationLink(destination: ScheduleFormView(
                        islands: filteredIslands,
                        selectedAppDayOfWeek: $selectedAppDayOfWeek,
                        selectedIsland: .constant(island),
                        viewModel: viewModel,
                        daysOfWeekViewModel: daysOfWeekViewModel
                    )) {
                        VStack(alignment: .leading) {
                            Text(island.islandName ?? "Unknown Gym")
                                .font(.headline)
                            Text(island.islandLocation ?? "")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .navigationBarTitle("Select Gym to View/Add Schedule")
                .alert(isPresented: $showNoMatchAlert) {
                    Alert(
                        title: Text("No Match Found"),
                        message: Text("No gyms match your search criteria."),
                        dismissButton: .default(Text("OK"))
                    )
                }
                .fullScreenCover(isPresented: $showClassScheduleModal) {
                    ScheduleFormView(
                        islands: filteredIslands,
                        selectedAppDayOfWeek: $selectedAppDayOfWeek,
                        selectedIsland: $selectedIsland,
                        viewModel: viewModel,
                        daysOfWeekViewModel: daysOfWeekViewModel
                    )
                }

                if let matTime = selectedMatTime {
                    Section(header: Text("Edit Mat Time")) {
                        TextField("Time", text: Binding(
                            get: { matTime.time ?? "" },
                            set: { matTime.time = $0 }
                        ))
                    }
                }

                if isLoading {
                    ProgressView("Loading...")
                        .zIndex(1)
                }

                if isError {
                    ErrorView(
                        description: errorDescription,
                        isError: $isError,
                        retryAction: {
                            Task {
                                isLoading = true
                                viewModel.fetchPirateIslands()
                                isLoading = false
                                updateFilteredIslands()
                            }
                        }
                    )
                    .zIndex(1)
                }
            }
            .onAppear {
                print("DaysOfWeekFormView: selectedIsland = \(selectedIsland?.islandName ?? "None")")

                Task {
                    isLoading = true
                    viewModel.fetchPirateIslands()
                    isLoading = false
                    updateFilteredIslands()
                }
            }
            /*.onDisappear {
                do {
                    try PersistenceController.shared.saveContext()
                } catch {
                    // Handle error
                }
                resetSelectedIsland()
            } */
        }
    }

    private func resetSelectedIsland() {
        selectedIsland = nil
    }

    private func updateFilteredIslands() {
        let lowercasedQuery = searchQuery.lowercased()

        if !searchQuery.isEmpty {
            filteredIslands = islands.filter { island in
                let predicate = NSPredicate(format: "islandName CONTAINS[c] %@ OR islandLocation CONTAINS[c] %@ OR gymWebsite.absoluteString CONTAINS[c] %@", argumentArray: [lowercasedQuery, lowercasedQuery, lowercasedQuery])
                return predicate.evaluate(with: island)
            }
            print("Filtered Islands: \(filteredIslands.map { $0.islandName })")
        } else {
            filteredIslands = Array(islands)
            print("All Islands: \(filteredIslands.map { $0.islandName })")
        }

        showNoMatchAlert = filteredIslands.isEmpty && !searchQuery.isEmpty
    }
}


class DaysOfWeekFormViewModel: ObservableObject {
    @Published var selectedIsland: PirateIsland?
}

struct ErrorView: View {
    let description: String
    @Binding var isError: Bool
    let retryAction: () -> Void

    var body: some View {
        VStack {
            Image(systemName: "exclamationmark.triangle")
                .resizable()
                .frame(width: 50, height: 50)
                .foregroundColor(.red)
            Text(description)
                .font(.headline)
                .foregroundColor(.black)
            Button(action: {
                isError = false
            }) {
                Text("OK")
                    .font(.body)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(8)
            }
            Button(action: retryAction) {
                Text("Retry")
                    .font(.body)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(8)
            }
        }
    }
}

struct DaysOfWeekFormView_Previews: PreviewProvider {
    static func createMockIsland(in context: NSManagedObjectContext) -> PirateIsland {
        let mockIsland = PirateIsland(context: context)
        mockIsland.islandName = "Mock Gym"
        mockIsland.islandLocation = "Mock Location"
        mockIsland.latitude = 0.0
        mockIsland.longitude = 0.0
        mockIsland.gymWebsite = URL(string: "https://www.example.com")

        return mockIsland
    }

    static var previews: some View {
        let context = PersistenceController.shared.container.viewContext
        let mockIsland = createMockIsland(in: context)

        let mockRepository = MockAppDayOfWeekRepository(persistenceController: PersistenceController.shared)
        let viewModel = AppDayOfWeekViewModel(
            selectedIsland: mockIsland,
            repository: mockRepository,
            enterZipCodeViewModel: MockEnterZipCodeViewModel()
        )

        let selectedIsland = Binding<PirateIsland?>(
            get: { mockIsland },
            set: { _ in }
        )
        let selectedMatTime = Binding<MatTime?>(
            get: { nil },
            set: { _ in }
        )

        return DaysOfWeekFormView(viewModel: viewModel, selectedIsland: selectedIsland, selectedMatTime: selectedMatTime)
            .environment(\.managedObjectContext, context)
            .previewDisplayName("DaysOfWeekFormView")
    }
}

class MockAppDayOfWeekRepository: AppDayOfWeekRepository {
    override init(persistenceController: PersistenceController) {
        super.init(persistenceController: persistenceController)
        // Create mock data
    }

    override func getViewContext() -> NSManagedObjectContext {
        return persistenceController.container.viewContext
    }

    // Override other methods as needed
}

class MockEnterZipCodeViewModel: EnterZipCodeViewModel {
    init() {
        super.init(repository: MockAppDayOfWeekRepository(persistenceController: PersistenceController.shared), context: PersistenceController.shared.container.viewContext)
    }
}
