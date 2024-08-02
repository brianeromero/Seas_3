//
//  DaysOfWeekFormView.swift
//  Seas_3
//
//  Created by Brian Romero on 6/26/24.
//

import SwiftUI

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

    @State private var showClassScheduleModal = false
    @State private var showOpenMatModal = false
    @State private var selectedAppDayOfWeek: AppDayOfWeek?
    @State private var showError = false
    @State private var errorMessage = ""

    @Environment(\.managedObjectContext) private var viewContext

    init(viewModel: AppDayOfWeekViewModel, selectedIsland: Binding<PirateIsland?>) {
        self.viewModel = viewModel
        self._selectedIsland = selectedIsland
    }

    var body: some View {
        NavigationView {
            List {
                if let selectedIsland = selectedIsland {
                    Section(header: Text("Island")) {
                        Text("Selected Island: \(selectedIsland.islandName)")
                    }
                } else {
                    Section(header: Text("Search by Gym Name, Zip Code, or Address/Location")) {
                        InsertIslandSearch(selectedIsland: $selectedIsland, viewModel: viewModel)
                    }
                }

                Section(header: Text("Add Class Schedule")) {
                    if selectedIsland != nil {
                        Button(action: {
                            self.showClassScheduleModal = true
                        }) {
                            Text("Add Class Schedule")
                        }
                        .sheet(isPresented: $showClassScheduleModal) {
                            AddClassScheduleView(
                                viewModel: viewModel,
                                selectedAppDayOfWeek: $selectedAppDayOfWeek,
                                pIsland: selectedIsland!
                            )
                            .environment(\.managedObjectContext, viewContext)
                        }
                    }
                }

                Section(header: Text("Add Open Mat")) {
                    if selectedIsland != nil {
                        Button(action: {
                            self.showOpenMatModal = true
                        }) {
                            Text("Add Open Mat")
                        }
                        .sheet(isPresented: $showOpenMatModal) {
                            ScheduleFormView(
                                viewModel: viewModel,
                                selectedAppDayOfWeek: $selectedAppDayOfWeek,
                                selectedIsland: $selectedIsland
                            )
                            .environment(\.managedObjectContext, viewContext)
                        }
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
                    Text(island.islandName)
                }
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
                return (island.islandName.lowercased().contains(lowercasedQuery)) ||
                (island.islandLocation.lowercased().contains(lowercasedQuery)) ||
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

struct DaysOfWeekFormView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext
        let mockIsland = PirateIsland(context: context)
        mockIsland.islandName = "Mock Island"
        mockIsland.islandLocation = "Mock Location"
        mockIsland.latitude = 0.0
        mockIsland.longitude = 0.0
        mockIsland.gymWebsite = URL(string: "https://www.example.com")

        // Initialize the view model with the default constructor
        let viewModel = AppDayOfWeekViewModel(selectedIsland: mockIsland)

        // Use a Binding with a default value
        let selectedIsland = Binding<PirateIsland?>(
            get: { mockIsland },
            set: { _ in } // No-op setter
        )

        return DaysOfWeekFormView(
            viewModel: viewModel,
            selectedIsland: selectedIsland
        )
        .environment(\.managedObjectContext, context) // Set the environment context
    }
}
