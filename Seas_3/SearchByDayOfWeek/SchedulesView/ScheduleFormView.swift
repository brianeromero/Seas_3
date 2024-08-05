//
//  cheduleFormView.swiftcheduleFormView.swift
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
    @ObservedObject var viewModel: AppDayOfWeekViewModel

    @State private var day: String = ""
    @State private var name: String = ""
    @State private var selectedDay: DayOfWeek = .monday
    @State private var showingAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""

    init(
        selectedAppDayOfWeek: Binding<AppDayOfWeek?>,
        selectedIsland: Binding<PirateIsland?>,
        viewModel: AppDayOfWeekViewModel
    ) {
        self._selectedAppDayOfWeek = selectedAppDayOfWeek
        self._selectedIsland = selectedIsland
        self.viewModel = viewModel
    }

    var body: some View {
        NavigationView {
            Form {
                // Day Information Section
                Section(header: Text("Day Information")) {
                    TextField("Day (e.g., Monday)", text: $day)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .disabled(true)

                    Text("Schedule Name: \(name)")
                        .disabled(true)

                    Text("AppDayOfWeekID: \(viewModel.appDayOfWeekID ?? "Not Set")")
                        .disabled(true)
                }

                // Island Selection Section
                Section(header: Text("Select Island")) {
                    Picker("Select Island", selection: $selectedIsland) {
                        ForEach(islands, id: \.self) { island in
                            Text(island.islandName).tag(island as PirateIsland?)
                        }
                    }
                    .onChange(of: selectedIsland) { newIsland in
                        if let island = newIsland {
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
                    .onChange(of: selectedDay) { newValue in
                        day = newValue.rawValue
                        updateAppDayOfWeek()
                    }
                }

                // Add New Mat Time Section
                AddNewMatTimeSection(
                    selectedAppDayOfWeek: $selectedAppDayOfWeek,
                    selectedIsland: $selectedIsland,
                    viewModel: viewModel,
                    selectedDay: $selectedDay,
                    name: $name,
                    appDayOfWeekID: $viewModel.appDayOfWeekID
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
        if let island = selectedIsland, selectedAppDayOfWeek != nil {
            viewModel.fetchCurrentDayOfWeek(for: island)
        }

        if selectedAppDayOfWeek == nil {
            alertTitle = "No Selection"
            alertMessage = "Please select an AppDayOfWeek instance."
            showingAlert = true
        } else {
            updateUIWithAppDayOfWeek()
        }

        viewModel.updateNameAndID()
        print("Current AppDayOfWeek ID on Appear: \(selectedAppDayOfWeek?.appDayOfWeekID ?? "None")")
    }

    private func updateAppDayOfWeek() {
        if let appDayOfWeek = selectedAppDayOfWeek {
            appDayOfWeek.day = selectedDay.rawValue
            viewModel.updateNameAndID()
            viewModel.updateSchedules()
        }
    }

    private func updateUIWithAppDayOfWeek() {
        if let appDayOfWeek = selectedAppDayOfWeek {
            day = appDayOfWeek.day ?? ""
            name = appDayOfWeek.name ?? ""
            print("Updated AppDayOfWeek ID: \(String(describing: viewModel.appDayOfWeekID))")

            if let matTimes = appDayOfWeek.matTimes as? Set<MatTime> {
                viewModel.matTimesForDay[selectedDay] = Array(matTimes)
            }
        }
    }
}

struct ScheduledMatTimesSection: View {
    @Binding var selectedDay: DayOfWeek
    @ObservedObject var viewModel: AppDayOfWeekViewModel
    @Binding var selectedAppDayOfWeek: AppDayOfWeek?

    var body: some View {
        Section(header: Text("Scheduled Mat Times")) {
            if let _ = selectedAppDayOfWeek, // Ignored variable here
               let matTimes = viewModel.matTimesForDay[selectedDay],
               !matTimes.isEmpty {
                List {
                    ForEach(matTimes, id: \.self) { matTime in
                        Text(matTime.description) // Assuming `description` is properly overridden
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
        let context = PersistenceController.preview.container.viewContext
        
        // Create a valid PirateIsland object
        let island = PirateIsland(context: context)
        island.islandID = UUID() // Assign a UUID value
        island.islandName = "Island Name"
        
        // Create a valid AppDayOfWeek object
        let appDayOfWeek = AppDayOfWeek(context: context)
        appDayOfWeek.appDayOfWeekID = UUID().uuidString // Assign a UUID string value
        appDayOfWeek.day = "Monday"
        appDayOfWeek.name = "Schedule Name"
        
        // Create and configure a view model
        let viewModel = AppDayOfWeekViewModel(selectedIsland: island)
        viewModel.name = appDayOfWeek.name
        viewModel.appDayOfWeekID = appDayOfWeek.appDayOfWeekID

        // Initialize ScheduleFormView with viewModel
        return ScheduleFormView(
            selectedAppDayOfWeek: .constant(appDayOfWeek),
            selectedIsland: .constant(island),
            viewModel: viewModel
        )
        .environment(\.managedObjectContext, context) // Ensure environment context is set
    }
}
