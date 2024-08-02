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
        return "MatTime: \(time ?? "") - Gi: \(gi), No Gi: \(noGi), Open Mat: \(openMat), Restrictions: \(restrictions), Good for Beginners: \(goodForBeginners), Adult: \(adult)"
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

    @State private var day: String = ""
    @State private var name: String = ""
    //@State private var appDayOfWeekID: String = ""
    @State private var selectedDay: DayOfWeek = .monday
    @State private var editingExisting = false
    @State private var showingAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""

    @ObservedObject var viewModel: AppDayOfWeekViewModel

    init(
        viewModel: AppDayOfWeekViewModel,
        selectedAppDayOfWeek: Binding<AppDayOfWeek?>,
        selectedIsland: Binding<PirateIsland?>
    ) {
        self._selectedAppDayOfWeek = selectedAppDayOfWeek
        self._selectedIsland = selectedIsland
        self.viewModel = viewModel
    }

    var body: some View {
        NavigationView {
            Form {
                DayInformationSection(
                    day: $day,
                    name: Binding(
                        get: { viewModel.name ?? "" },
                        set: { viewModel.name = $0 }
                    ),
                    appDayOfWeekID: Binding(
                        get: { viewModel.appDayOfWeekID },
                        set: { viewModel.appDayOfWeekID = $0 }
                    ),
                    selectedIsland: $selectedIsland,
                    islands: islands,
                    viewModel: viewModel
                )
                
                SelectDaySection(
                    selectedDay: $selectedDay,
                    day: $day,
                    selectedAppDayOfWeek: $selectedAppDayOfWeek,
                    viewModel: viewModel
                )
                
                AddNewMatTimeSection(
                    selectedAppDayOfWeek: $selectedAppDayOfWeek,
                    selectedIsland: $selectedIsland,
                    viewModel: viewModel,
                    selectedDay: $selectedDay,
                    name: $name,
                    appDayOfWeekID: Binding(
                        get: { viewModel.appDayOfWeekID },
                        set: { viewModel.appDayOfWeekID = $0 }
                    )
                )
                
                ScheduledMatTimesSection(
                    selectedDay: $selectedDay,
                    viewModel: viewModel,
                    selectedAppDayOfWeek: $selectedAppDayOfWeek
                )
            }
            .navigationTitle("Schedule Form")
            .onAppear {
                if let island = selectedIsland {
                    viewModel.fetchCurrentDayOfWeek(for: island)
                }
                if selectedAppDayOfWeek == nil {
                    selectedAppDayOfWeek = AppDayOfWeek(context: viewContext)
                } else {
                    updateUIWithAppDayOfWeek()
                }
            }
            .alert(isPresented: $showingAlert) {
                Alert(title: Text(alertTitle), message: Text(alertMessage), dismissButton: .default(Text("OK")))
            }
        }
    }

    private func updateUIWithAppDayOfWeek() {
        if let appDayOfWeek = selectedAppDayOfWeek {
            day = appDayOfWeek.day ?? ""
            name = appDayOfWeek.name ?? ""  // Check if this is being set correctly
            //appDayOfWeekID = appDayOfWeek.appDayOfWeekID ?? ""  // Check if this is being set correctly
            
            if let matTimes = appDayOfWeek.matTimes as? Set<MatTime> {
                viewModel.matTimesForDay[selectedDay] = Array(matTimes)
            }
        }
    }

}

struct DayInformationSection: View {
    @Binding var day: String
    @Binding var name: String
    @Binding var appDayOfWeekID: String? // Make the appDayOfWeekID a binding
    @Binding var selectedIsland: PirateIsland?
    let islands: FetchedResults<PirateIsland>
    @ObservedObject var viewModel: AppDayOfWeekViewModel

    var body: some View {
        Section(header: Text("Day Information")) {
            TextField("Day (e.g., Monday)", text: Binding(
                get: { day },
                set: { newValue in
                    day = newValue
                    if let selectedIsland = selectedIsland {
                        viewModel.updateDay(for: selectedIsland, newDay: newValue)
                        viewModel.updateNameAndID()
                        print("Updated Day: \(newValue)")
                        print("Updated Name: \(name)")
                        print("Updated AppDayOfWeekID: \(String(describing: appDayOfWeekID))")
                    }
                }
            ))
            .textInputAutocapitalization(.words)
            .autocorrectionDisabled()
            .disabled(true) // Make the field non-editable
            
            Text("Schedule Name: \(name)")
                .disabled(true) // Display the name but make it non-editable
            
            Text("Day ID: \(String(describing: appDayOfWeekID))")
                .disabled(true) // Display the ID but make it non-editable

            Picker("Select Island", selection: $selectedIsland) {
                ForEach(islands, id: \.self) { island in
                    Text(island.islandName).tag(island as PirateIsland?)
                }
            }
            .onChange(of: selectedIsland) { newIsland in
                if let island = newIsland {
                    viewModel.fetchCurrentDayOfWeek(for: island)
                    viewModel.updateNameAndID()
                    name = viewModel.name ?? "" // Update the name binding here
                }
            }
        }
    }
}

struct SelectDaySection: View {
    @Binding var selectedDay: DayOfWeek
    @Binding var day: String
    @Binding var selectedAppDayOfWeek: AppDayOfWeek?
    @ObservedObject var viewModel: AppDayOfWeekViewModel

    var body: some View {
        Section(header: Text("Select Day")) {
            Picker("Day", selection: $selectedDay) {
                ForEach(DayOfWeek.allCases, id: \.self) { day in
                    Text(day.displayName).tag(day)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .onChange(of: selectedDay) { newValue in
                day = newValue.rawValue
                if let appDayOfWeek = selectedAppDayOfWeek {
                    appDayOfWeek.day = newValue.rawValue
                    viewModel.updateSchedules()
                    viewModel.updateNameAndID() // Call updateNameAndID here
                }
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
            if let matTimes = viewModel.matTimesForDay[selectedDay] {
                List(matTimes) { matTime in
                    MatTimeRow(matTime: matTime)
                }
            } else {
                Text("No mat times scheduled for this day.")
            }
        }
    }
}

struct MatTimeRow: View {
    var matTime: MatTime

    var body: some View {
        VStack(alignment: .leading) {
            Text(matTime.time ?? "")
                .font(.headline)
            Text("Gi: \(matTime.gi ? "Yes" : "No"), No Gi: \(matTime.noGi ? "Yes" : "No"), Open Mat: \(matTime.openMat ? "Yes" : "No")")
                .font(.subheadline)
            Text("Restrictions: \(matTime.restrictions ? "Yes" : "No")")
                .font(.body)
            if matTime.goodForBeginners {
                Text("Good for Beginners")
                    .font(.body)
            }
            if matTime.adult {
                Text("Adult")
                    .font(.body)
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
        
        // Initialize the view model without viewContext directly
        let viewModel = AppDayOfWeekViewModel(selectedIsland: island)

        return ScheduleFormView(
            viewModel: viewModel,
            selectedAppDayOfWeek: .constant(appDayOfWeek),
            selectedIsland: .constant(island)
        )
        .environment(\.managedObjectContext, context) // Ensure environment context is set
    }
}
