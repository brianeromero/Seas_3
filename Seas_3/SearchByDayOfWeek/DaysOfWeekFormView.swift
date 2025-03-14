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
    @State private var searchQuery: String = ""
    @State private var filteredIslands: [PirateIsland] = []
    @State private var showNoMatchAlert: Bool = false
    @Environment(\.managedObjectContext) private var viewContext
    @State private var isSelected = false
    @State private var navigationSelectedIsland: PirateIsland?
    @State private var selectedDay: DayOfWeek? = nil
    @State private var selectedMatTimes: [MatTime] = []


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
                searchSection
                islandList
            }
            .navigationTitle("Gym Schedules")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Text("Select Gym to View/Add Schedule")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
            }
            .onAppear {
                updateFilteredIslands()
            }
            .onChange(of: navigationSelectedIsland) { newSelection in
                if let selected = newSelection {
                    selectedIsland = selected
                }
            }
        }
    }

    var searchSection: some View {
        Section(header: Text("Search by: gym name, zip code, or address/location")
                            .font(.headline)
                            .foregroundColor(.gray)) {
            SearchBar(text: $searchQuery)
                .onChange(of: searchQuery) { _ in
                    updateFilteredIslands()
                }
        }
    }

    var islandList: some View {
        List(filteredIslands, id: \.self) { island in
            NavigationLink(
                destination: ScheduleFormView(
                    islands: filteredIslands,
                    selectedIsland: $selectedIsland,
                    viewModel: viewModel,
                    matTimes: $selectedMatTimes
                ),
                tag: island,
                selection: $navigationSelectedIsland
            ) {
                VStack(alignment: .leading) {
                    Text(island.islandName ?? "Unknown Gym")
                        .font(.headline)
                    Text(island.islandLocation ?? "")
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(minHeight: 400, maxHeight: .infinity)
        .listStyle(PlainListStyle())
        .alert(isPresented: $showNoMatchAlert) {
            Alert(
                title: Text("No Match Found"),
                message: Text("No gyms match your search criteria."),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    private func updateFilteredIslands() {
        let lowercasedQuery = searchQuery.lowercased()
        filteredIslands = filterIslands(query: lowercasedQuery)
        showNoMatchAlert = filteredIslands.isEmpty && !searchQuery.isEmpty
    }

    private func filterIslands(query: String) -> [PirateIsland] {
        if query.isEmpty {
            return Array(islands)
        }

        let islandNamePredicate = NSPredicate(format: "islandName CONTAINS[c] %@", query)
        let islandLocationPredicate = NSPredicate(format: "islandLocation CONTAINS[c] %@", query)
        let gymWebsitePredicate = NSPredicate(format: "gymWebsite.absoluteString CONTAINS[c] %@", query)

        let compoundPredicate = NSCompoundPredicate(orPredicateWithSubpredicates: [islandNamePredicate, islandLocationPredicate, gymWebsitePredicate])

        return islands.filter { compoundPredicate.evaluate(with: $0) }
    }
}

// Custom Debounce Function
extension DaysOfWeekFormView {
    func debounce(_ interval: TimeInterval, action: @escaping () -> Void) {
        Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { _ in
            action()
        }
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

    override func getViewContext() -> NSManagedObjectContext {
        return PersistenceController.shared.viewContext
    }
}

class MockEnterZipCodeViewModel: EnterZipCodeViewModel {
    init() {
        super.init(repository: MockAppDayOfWeekRepository(persistenceController: PersistenceController.shared), persistenceController: PersistenceController.shared)
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
        let context = PersistenceController.shared.viewContext
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
        let showReview = Binding<Bool>(
            get: { false },
            set: { _ in }
        )

        return DaysOfWeekFormView(viewModel: viewModel, selectedIsland: selectedIsland, selectedMatTime: selectedMatTime, showReview: showReview)
            .environment(\.managedObjectContext, context)
            .previewDisplayName("DaysOfWeekFormView")
    }
}
