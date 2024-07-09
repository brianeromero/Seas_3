//
// DaysOfWeekFormView.swift
// Seas_3
//
// Created by Brian Romero on 6/26/24.
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
    @ObservedObject var viewModel: AppDayOfWeekViewModel // Use @ObservedObject for observed objects
    @Binding var selectedIsland: PirateIsland? // Use @Binding for two-way data binding

    @State private var showClassScheduleModal = false
    @State private var showOpenMatModal = false
    @State private var selectedAppDayOfWeek: AppDayOfWeek?
    @State private var showError = false
    @State private var errorMessage = ""

    @Environment(\.managedObjectContext) private var viewContext

    init(viewModel: AppDayOfWeekViewModel, selectedIsland: Binding<PirateIsland?>) {
        self.viewModel = viewModel
        self._selectedIsland = selectedIsland // Use _selectedIsland for binding
    }

    var body: some View {
        NavigationView {
            List {
                if let selectedIsland = selectedIsland {
                    // Section for selected island
                    Section(header: Text("Island")) {
                        Text("Selected Island: \(selectedIsland.islandName)")
                    }
                } else {
                    // Section for inserting island search
                    Section(header: Text("Search by: gym name, zip code, or address/location")) {
                        InsertIslandSearch(selectedIsland: $selectedIsland)
                    }
                }

                // Section for adding class schedule
                Section(header: Text("Add Class Schedule")) {
                    if let island = selectedIsland {
                        Button(action: {
                            self.showClassScheduleModal = true
                        }) {
                            Text("Add Class Schedule")
                        }
                        .sheet(isPresented: $showClassScheduleModal) {
                            AddClassScheduleView(
                                viewModel: viewModel,
                                selectedAppDayOfWeek: $selectedAppDayOfWeek,
                                pIsland: island
                            )
                            .environment(\.managedObjectContext, viewContext)
                        }
                    }
                }

                // Section for adding open mat
                Section(header: Text("Add Open Mat")) {
                    if let island = selectedIsland {
                        Button(action: {
                            self.showOpenMatModal = true
                        }) {
                            Text("Add Open Mat")
                        }
                        .sheet(isPresented: $showOpenMatModal) {
                            AddOpenMatFormView(
                                viewModel: viewModel,
                                selectedAppDayOfWeek: $selectedAppDayOfWeek,
                                pIsland: island
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
                viewModel.fetchSchedules()
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
        mockIsland.gymWebsite = URL(string: "(link unavailable)")

        let viewModel = AppDayOfWeekViewModel(selectedIsland: mockIsland)

        // Create a Binding to mockIsland as optional
        let selectedIslandBinding = Binding<PirateIsland?>(
            get: { mockIsland },
            set: { _ in }
        )

        let view = DaysOfWeekFormView(viewModel: viewModel, selectedIsland: selectedIslandBinding)
            .environment(\.managedObjectContext, context)

        return view
    }
}
