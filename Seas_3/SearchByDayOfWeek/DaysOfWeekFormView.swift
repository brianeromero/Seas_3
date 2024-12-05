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
    @Binding var showReview: Bool
    @State private var isLoading = false
    @State private var isError = false
    @State private var errorDescription = ""

    @State private var showClassScheduleModal = false
    @State private var selectedAppDayOfWeek: AppDayOfWeek?
    @State private var showNoMatchAlert = false
    @State private var searchQuery = ""
    @State private var filteredIslands: [PirateIsland] = []

    @Environment(\.managedObjectContext) private var viewContext

    init(viewModel: AppDayOfWeekViewModel, selectedIsland: Binding<PirateIsland?>, selectedMatTime: Binding<MatTime?>, showReview: Binding<Bool>) {
        self.viewModel = viewModel
        self._selectedIsland = selectedIsland
        self._selectedMatTime = selectedMatTime
        self._showReview = showReview
    }

    @FetchRequest(
        entity: PirateIsland.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \PirateIsland.islandName, ascending: true)]
    ) private var islands: FetchedResults<PirateIsland>

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Search by: gym name, postal code, or address/location")
                            .font(.headline)
                            .foregroundColor(.gray)) {
                    SearchBar(text: $searchQuery)
                        .onChange(of: searchQuery) { _ in
                            updateFilteredIslands()
                        }
                }

                IslandSection(
                    islands: filteredIslands,
                    selectedIsland: $selectedIsland,
                    showReview: $showReview
                )

                if selectedIsland != nil {
                    NavigationLink(
                        destination: ScheduleFormView(
                            islands: filteredIslands,
                            selectedAppDayOfWeek: $selectedAppDayOfWeek,
                            selectedIsland: $selectedIsland,
                            viewModel: viewModel,
                            matTimes: .constant([]) // Add this line
                        )
                    ) {
                        Text("View Schedule")
                    }
                    .onChange(of: selectedIsland) { newIsland in
                        if let island = newIsland {
                            print("Navigating to ScheduleFormView for island: \(island.islandName ?? "Unknown Gym")")
                        }
                    }
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
            .alert(isPresented: $showNoMatchAlert) {
                Alert(
                    title: Text("No Match Found"),
                    message: Text("No gyms match your search criteria."),
                    dismissButton: .default(Text("OK"))
                )
            }
            .navigationBarTitle("Select Gym to View/Add Schedule")
            .onAppear {
                print("DaysOfWeekFormView: selectedIsland = \(String(describing: selectedIsland))")
                Task {
                    isLoading = true
                    viewModel.fetchPirateIslands()
                    isLoading = false
                    updateFilteredIslands()
                }
            }
        }
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


class MockAppDayOfWeekRepository: AppDayOfWeekRepository {
    override init(persistenceController: PersistenceController) {
        super.init(persistenceController: persistenceController)
    }
    
    // Optionally, mock any methods used in the view model
    override func getViewContext() -> NSManagedObjectContext {
        return PersistenceController.shared.viewContext
    }
    
    // Add any other methods if needed for your preview scenario
}


class MockEnterZipCodeViewModel: EnterZipCodeViewModel {
    init() {
        super.init(repository: MockAppDayOfWeekRepository(persistenceController: PersistenceController.shared), persistenceController: PersistenceController.shared)
    }
    
    // You can mock or override methods if necessary for your preview scenario
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
        let context = PersistenceController.shared.viewContext // Access viewContext directly
        let mockIsland = createMockIsland(in: context)

        // Create the mock repository and view model
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
        let showReview = Binding<Bool>(
            get: { false },
            set: { _ in }
        )

        return DaysOfWeekFormView(viewModel: viewModel, selectedIsland: selectedIsland, selectedMatTime: selectedMatTime, showReview: showReview)
            .environment(\.managedObjectContext, context) // Inject the managed object context here
            .previewDisplayName("DaysOfWeekFormView")
    }
}
