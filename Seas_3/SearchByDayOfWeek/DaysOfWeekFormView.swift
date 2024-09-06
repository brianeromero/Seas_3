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

    @State private var showClassScheduleModal = false
    @State private var showOpenMatModal = false
    @State private var selectedAppDayOfWeek: AppDayOfWeek?
    @State private var showError = false
    @State private var errorMessage = ""

    @Environment(\.managedObjectContext) private var viewContext

    init(viewModel: AppDayOfWeekViewModel, selectedIsland: Binding<PirateIsland?>, selectedMatTime: Binding<MatTime?>) {
        self.viewModel = viewModel
        self._selectedIsland = selectedIsland
        self._selectedMatTime = selectedMatTime
    }

    var body: some View {
        NavigationView {
            Form {
                if let selectedIsland = selectedIsland {
                    Section(header: Text("Gyms")) {
                        Text("Selected Gym: \(selectedIsland.islandName ?? "")")
                    }
                } else {
                    Section(header: Text("Search by Gym Name, Zip Code, or Address/Location")) {
                        InsertIslandSearch(selectedIsland: $selectedIsland, viewModel: viewModel)
                    }
                }



                Section(header: Text("Add Mat Schedule")) {
                    if selectedIsland != nil {
                        Button(action: {
                            self.showOpenMatModal = true
                        }) {
                            Text("Add Mat Schedule")
                        }
                        .sheet(isPresented: $showOpenMatModal) {
                            ScheduleFormView(
                                selectedAppDayOfWeek: $selectedAppDayOfWeek,
                                selectedIsland: $selectedIsland,
                                viewModel: viewModel
                            )
                            .environment(\.managedObjectContext, viewContext)
                        }
                    }
                }

                if let matTime = selectedMatTime {
                    Section(header: Text("Edit Mat Time")) {
                        TextField("Time", text: Binding(
                            get: { matTime.time ?? "" },
                            set: { matTime.time = $0 }))
                        // Add other fields and save button as needed
                    }
                }
            }
            .onDisappear {
                do {
                    try viewContext.save()
                } catch {
                    let nsError = error as NSError
                    fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
                }
                self.selectedIsland = nil
            }
            .navigationBarTitle("Add Open Mat Times / Class Schedule", displayMode: .inline)
        }
        .onAppear {
            Task {
                viewModel.fetchPirateIslands()
            }
        }
        .alert(isPresented: $showError) {
            Alert(
                title: Text("Error"),
                message: Text(errorMessage),
                dismissButton: .default(Text("OK"))
            )
        }
    }
}


struct InsertIslandSearch: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        entity: PirateIsland.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \PirateIsland.createdTimestamp, ascending: true)]
    ) private var islands: FetchedResults<PirateIsland>

    @Binding var selectedIsland: PirateIsland?

    @State private var searchQuery: String = ""
    @State private var showNoMatchAlert: Bool = false
    @State private var filteredIslands: [PirateIsland] = []

    @ObservedObject var viewModel: AppDayOfWeekViewModel

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)

                TextField("Search...", text: $searchQuery)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(Color(.systemGray6))
                    .cornerRadius(8.0)
                    .textFieldStyle(PlainTextFieldStyle())
                    .onChange(of: searchQuery) {
                        updateFilteredIslands()
                    }
            }
            .padding(.bottom, 16)

            List(filteredIslands) { island in
                Button(action: {
                    self.selectedIsland = island
                    self.viewModel.currentAppDayOfWeek = AppDayOfWeek(context: self.viewContext)
                    self.viewModel.currentAppDayOfWeek?.pIsland = island
                }) {
                    Text(island.islandName?.description ?? "Unknown Gym")                }
            }
            .listStyle(PlainListStyle())
            .navigationTitle("Select Gym")
            .alert(isPresented: $showNoMatchAlert) {
                Alert(
                    title: Text("No Match Found"),
                    message: Text("No gyms match your search criteria."),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
        .padding()
        .onAppear {
            updateFilteredIslands()
        }
    }

    private func updateFilteredIslands() {
        let lowercasedQuery = searchQuery.lowercased()
        if !searchQuery.isEmpty {
            filteredIslands = islands.filter { island in
                return (island.islandName?.lowercased().contains(lowercasedQuery) ?? false) ||
                (island.islandLocation?.lowercased().contains(lowercasedQuery) ?? false) ||
                (island.gymWebsite?.absoluteString.lowercased().contains(lowercasedQuery) ?? false) ||
                (String(island.latitude).contains(lowercasedQuery)) ||
                (String(island.longitude).contains(lowercasedQuery))
            }
        } else {
            filteredIslands = Array(islands)
        }

        showNoMatchAlert = filteredIslands.isEmpty && !searchQuery.isEmpty
    }
}

// Mock repository class
class MockAppDayOfWeekRepository: AppDayOfWeekRepository {
    override init(persistenceController: PersistenceController) {
        super.init(persistenceController: persistenceController)
    }
    
    // Override method with the same signature as in superclass
    override func fetchAppDayOfWeek(for island: PirateIsland, day: DayOfWeek, context: NSManagedObjectContext) -> AppDayOfWeek? {
        return nil // Return nil or mock data if needed
    }
}


#if DEBUG
// Create a basic implementation or mock for EnterZipCodeViewModel
class MockEnterZipCodeViewModel: EnterZipCodeViewModel {
    init() {
        super.init(repository: MockAppDayOfWeekRepository(persistenceController: PersistenceController.preview), context: PersistenceController.preview.container.viewContext)
    }
}
#endif

#if DEBUG
struct DaysOfWeekFormView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext
        
        // Create a mock PirateIsland
        let mockIsland = PirateIsland(context: context)
        mockIsland.islandName = "Mock Gym"
        mockIsland.islandLocation = "Mock Location"
        mockIsland.latitude = 0.0
        mockIsland.longitude = 0.0
        mockIsland.gymWebsite = URL(string: "https://www.example.com")
        
        // Initialize the mock repository
        let mockRepository = MockAppDayOfWeekRepository(persistenceController: PersistenceController.preview)
        
        // Create a mock EnterZipCodeViewModel
        let mockEnterZipCodeViewModel = MockEnterZipCodeViewModel()
        
        // Create a mock AppDayOfWeekViewModel
        let viewModel = AppDayOfWeekViewModel(
            selectedIsland: mockIsland,
            repository: mockRepository,
            enterZipCodeViewModel: mockEnterZipCodeViewModel // Ensure this is included
        )
        
        // Create a Binding for selectedIsland
        let selectedIsland = Binding<PirateIsland?>(
            get: { mockIsland },
            set: { _ in } // No-op setter
        )
        
        // Create a Binding for selectedMatTime
        let selectedMatTime = Binding<MatTime?>(
            get: { nil },
            set: { _ in } // No-op setter
        )
        
        return DaysOfWeekFormView(
            viewModel: viewModel,
            selectedIsland: selectedIsland,
            selectedMatTime: selectedMatTime
        )
        .environment(\.managedObjectContext, context)
    }
}
#endif
