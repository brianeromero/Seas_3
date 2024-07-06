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

    var body: some View {
        NavigationView {
            List {
                if let selectedIsland = selectedIsland {
                    Section(header: Text("Island")) {
                        Text("Selected Island: \(selectedIsland.islandName)")
                    }
                } else {
                    Section(header: Text("Search")) {
                        InsertIslandSearch(selectedIsland: $selectedIsland)
                    }
                }
                
                // Separate sections for each type of schedule
                Section(header: Text("Add Class Schedule")) {
                    if viewModel.selectedIsland != nil {
                        Button(action: {
                            self.showClassScheduleModal = true
                        }) {
                            Text("Add Class Schedule")
                        }
                        .sheet(isPresented: $showClassScheduleModal) {
                            if let island = selectedIsland {
                                AddClassScheduleView(
                                    viewModel: self.viewModel,
                                    selectedAppDayOfWeek: self.$selectedAppDayOfWeek,
                                    pIsland: island,
                                    goodForBeginners: self.$viewModel.goodForBeginners,
                                    matTime: self.$viewModel.matTime.toNonOptional(),
                                    openMat: self.$viewModel.openMat,
                                    restrictions: self.$viewModel.restrictions,
                                    restrictionDescription: self.$viewModel.restrictionDescription.toNonOptional(),
                                    selectedIsland: self.$selectedIsland
                                )
                            }
                        }
                    }
                }
                
                Section(header: Text("Add Open Mat")) {
                    if viewModel.selectedIsland != nil {
                        Button(action: {
                            self.showOpenMatModal = true
                        }) {
                            Text("Add Open Mat")
                        }
                        .disabled(selectedIsland == nil)
                        .sheet(isPresented: $showOpenMatModal) {
                            if let island = selectedIsland {
                                AddOpenMatFormView(
                                    viewModel: self.viewModel,
                                    selectedAppDayOfWeek: self.$selectedAppDayOfWeek,
                                    pIsland: island
                                )
                            }
                        }
                    }
                }
            }
            .onDisappear {
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
            
            List(filteredIslands) { island in
                Button(action: {
                    self.selectedIsland = island
                }) {
                    Text(island.islandName)
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
