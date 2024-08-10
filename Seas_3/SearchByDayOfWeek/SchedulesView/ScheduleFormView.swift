//
//  ScheduleFormView.swift
//  Seas_3
//
//  Created by Brian Romero on 7/30/24.
//


import SwiftUI
import CoreData

extension MatTime {
    override public var description: String {
        "MatTime: \(time ?? "") - Gi: \(gi), No Gi: \(noGi), Open Mat: \(openMat), Restrictions: \(restrictions), Good for Beginners: \(goodForBeginners), Adult: \(adult)"
    }
}

struct ScheduleFormView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \PirateIsland.islandName, ascending: true)],
        animation: .default
    ) private var islands: FetchedResults<PirateIsland>

    @Binding var selectedAppDayOfWeek: AppDayOfWeek?
    @Binding var selectedIsland: PirateIsland?
    @StateObject private var viewModel: AppDayOfWeekViewModel

    @State private var showingAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var daySelected = false
    @State private var selectedDay: DayOfWeek = .monday


    init(
        selectedAppDayOfWeek: Binding<AppDayOfWeek?>,
        selectedIsland: Binding<PirateIsland?>,
        viewModel: AppDayOfWeekViewModel
    ) {
        self._selectedAppDayOfWeek = selectedAppDayOfWeek
        self._selectedIsland = selectedIsland
        self._viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationView {
            Form {
                // Island Selection Section
                Section(header: Text("Select Island")) {
                    Picker("Select Island", selection: $selectedIsland) {
                        ForEach(islands, id: \.self) { island in
                            Text(island.islandName).tag(island as PirateIsland?)
                        }
                    }
                    .onChange(of: selectedIsland) { newIsland in
                        if let island = newIsland {
                            print("Selected Island: \(island.islandName)")
                            viewModel.fetchCurrentDayOfWeek(for: island)
                        }
                    }
                }

                // Day Selection Section
                Section(header: Text("Select Day")) {
                    Picker("Day", selection: $selectedDay) {
                        ForEach(DayOfWeek.allCases, id: \.self) { day in
                            Text(day.displayName).tag(day)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .onChange(of: selectedDay) { newDay in
                        print("Selected Day: \(newDay.displayName)")
                        viewModel.updateSchedules()
                        daySelected = true
                    }
                }

                // Add New Mat Time Section
                AddNewMatTimeSection(
                    selectedAppDayOfWeek: $selectedAppDayOfWeek,
                    selectedIsland: $selectedIsland,
                    viewModel: viewModel,
                    selectedDay: $selectedDay,
                    daySelected: $daySelected
                )

                // Scheduled Mat Times Section
                ScheduledMatTimesSection(
                    selectedDay: $selectedDay,
                    viewModel: viewModel,
                    selectedAppDayOfWeek: $selectedAppDayOfWeek
                )

                // Error Handling Section
                if selectedAppDayOfWeek == nil {
                    Section(header: Text("Error")) {
                        Text("No AppDayOfWeek instance selected.")
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Schedule Form")
            .onAppear {
                setupView()
            }
            .alert(isPresented: $showingAlert) {
                Alert(title: Text(alertTitle), message: Text(alertMessage), dismissButton: .default(Text("OK")))
            }
        }
    }

    private func setupView() {
        if let island = selectedIsland {
            viewModel.fetchCurrentDayOfWeek(for: island)
            if let appDayOfWeek = selectedAppDayOfWeek {
                if let day = DayOfWeek(rawValue: appDayOfWeek.day ?? "") {
                    selectedDay = day
                }
            }
        } else {
            alertTitle = "No Selection"
            alertMessage = "Please select an AppDayOfWeek instance."
            showingAlert = true
        }
    }
}

struct ScheduledMatTimesSection: View {
    @Binding var selectedDay: DayOfWeek
    @ObservedObject var viewModel: AppDayOfWeekViewModel
    @Binding var selectedAppDayOfWeek: AppDayOfWeek?

    var body: some View {
        Section(header: Text("Scheduled Mat Times")) {
            if let matTimes = viewModel.matTimesForDay[selectedDay], !matTimes.isEmpty {
                List {
                    ForEach(matTimes, id: \.self) { matTime in
                        Text(matTime.description)
                            .padding()
                    }
                }
            } else {
                Text("No mat times available.")
                    .foregroundColor(.gray)
            }
        }
    }
}

struct ScheduleFormView_Previews: PreviewProvider {
    static var previews: some View {
        let persistenceController = PersistenceController.preview
        let context = persistenceController.container.viewContext
        
        // Create a valid PirateIsland object
        let island = PirateIsland(context: context)
        island.islandID = UUID()
        island.islandName = "Island Name"
        
        // Create a valid AppDayOfWeek object
        let appDayOfWeek = AppDayOfWeek(context: context)
        appDayOfWeek.appDayOfWeekID = UUID().uuidString
        appDayOfWeek.day = DayOfWeek.monday.rawValue
        appDayOfWeek.name = "Schedule Name"
        
        // Create a mock repository for the view model
        let mockRepository = AppDayOfWeekRepository(persistenceController: persistenceController)
        
        // Create and configure the view model
        let viewModel = AppDayOfWeekViewModel(
            selectedIsland: island,
            repository: mockRepository
        )
        
        // Initialize the view model with mock data
        viewModel.fetchCurrentDayOfWeek(for: island)

        return ScheduleFormView(
            selectedAppDayOfWeek: .constant(appDayOfWeek),
            selectedIsland: .constant(island),
            viewModel: viewModel
        )
        .environment(\.managedObjectContext, context)
        .previewDisplayName("Schedule Form Preview")
    }
}
