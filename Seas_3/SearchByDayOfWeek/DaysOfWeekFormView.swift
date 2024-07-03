//
//  DaysOfWeekFormView.swift
//  Seas_3
//
//  Created by Brian Romero on 6/26/24.
//

import Foundation

import SwiftUI

struct DaysOfWeekFormView: View {
    @ObservedObject var viewModel: AppDayOfWeekViewModel
    @Binding var selectedIsland: PirateIsland?
    @State private var showClassScheduleModal = false
    @State private var showOpenMatModal = false

    var body: some View {
        NavigationView {
            VStack {
                if let selectedIsland = selectedIsland {
                    Text("Selected Island: \(selectedIsland.islandName)")
                } else {
                    InsertIslandSearch(selectedIsland: $selectedIsland)
                }

                Form {
                    Section(header: Text("Select Schedule Type")) {
                        Button(action: {
                            self.showClassScheduleModal = true
                        }) {
                            Text("Add Class Schedule")
                        }
                        .sheet(isPresented: $showClassScheduleModal) {
                            AddClassScheduleView(viewModel: self.viewModel, selectedIsland: self.$selectedIsland)
                        }

                        Button(action: {
                            self.showOpenMatModal = true
                        }) {
                            Text("Add Open Mat")
                        }
                        .sheet(isPresented: $showOpenMatModal) {
                            AddOpenMatFormView(viewModel: self.viewModel, selectedIsland: self.$selectedIsland)
                        }
                    }
                }
                .navigationBarTitle("Add Open Mat Times / Class Schedule", displayMode: .inline)
            }
        }
        .onDisappear {
            // Reset selectedIsland when navigating back to IslandMenu
            self.selectedIsland = nil
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
            Text("Search by: gym name, zip code, or address/location")
                .font(.headline)
                .padding(.bottom, 4)
                .foregroundColor(.gray)

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

            List {
                ForEach(filteredIslands) { island in
                    Button(action: {
                        self.selectedIsland = island
                    }) {
                        Text(island.islandName)
                    }
                }
            }
            .listStyle(PlainListStyle())
            .navigationTitle("Select Island")
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
            logFetch() // Log fetch results on appearance
        }
    }

    private func updateFilteredIslands() {
        let lowercasedQuery = searchQuery.lowercased()
        filteredIslands = islands.filter { island in
            (island.islandName.lowercased().contains(lowercasedQuery)) ||
            (island.islandLocation.lowercased().contains(lowercasedQuery)) ||
            (island.gymWebsite?.absoluteString.lowercased().contains(lowercasedQuery) ?? false) ||
            (String(island.latitude).contains(lowercasedQuery)) ||
            (String(island.longitude).contains(lowercasedQuery))
        }

        showNoMatchAlert = filteredIslands.isEmpty && !searchQuery.isEmpty
    }

    private func logFetch() {
        print("Fetched \(islands.count) PirateIsland objects.")
    }
}

struct DaysOfWeekFormView_Previews: PreviewProvider {
    static var previews: some View {
        let viewModel = AppDayOfWeekViewModel(selectedIsland: nil) // Initialize your view model with a nil selected island

        // Create a mock PirateIsland instance for preview
        let mockIsland = PirateIsland()
        mockIsland.islandName = "Mock Island"

        return DaysOfWeekFormViewWrapper(viewModel: viewModel, initialIsland: mockIsland)
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext) // Inject the managed object context for the FetchRequest
    }
}

struct DaysOfWeekFormViewWrapper: View {
    @State private var selectedIsland: PirateIsland?
    var viewModel: AppDayOfWeekViewModel
    var initialIsland: PirateIsland?

    var body: some View {
        DaysOfWeekFormView(viewModel: viewModel, selectedIsland: $selectedIsland)
            .onAppear {
                self.selectedIsland = initialIsland
            }
    }
}
