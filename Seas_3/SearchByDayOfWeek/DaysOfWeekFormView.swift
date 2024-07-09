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
    @ObservedObject var viewModel: AppDayOfWeekViewModel
    @Binding var selectedIsland: PirateIsland?
    @State private var showClassScheduleModal = false
    @State private var showOpenMatModal = false
    @State private var selectedAppDayOfWeek: AppDayOfWeek?

    @Environment(\.managedObjectContext) private var viewContext  // Ensure this environment variable is declared

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
                            .environment(\.managedObjectContext, viewContext)  // Pass viewContext to child view
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
                            .environment(\.managedObjectContext, viewContext)  // Pass viewContext to child view
                        }
                    }
                }

            }
            .onDisappear {
                do {
                    try viewContext.save()  // Save changes in managed object context
                } catch {
                    let nsError = error as NSError
                    fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
                }
                self.selectedIsland = nil
            }
            .navigationBarTitle("Add Open Mat Times / Class Schedule", displayMode: .inline)
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
                    .onChange(of: searchQuery) { newValue in
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
        mockIsland.gymWebsite = URL(string: "https://mockisland.com")

        let viewModel = AppDayOfWeekViewModel(selectedIsland: mockIsland)

        return DaysOfWeekFormView(viewModel: viewModel, selectedIsland: .constant(mockIsland))
            .environment(\.managedObjectContext, context)
    }
}
