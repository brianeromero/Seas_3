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
    @State private var appDayOfWeekID: String = ""
    @State private var newMatTime: MatTime?
    @State private var selectedDay: DayOfWeek = .monday
    @State private var editingExisting = false
    @State private var showingAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @ObservedObject var viewModel: AppDayOfWeekViewModel

    init(viewModel: AppDayOfWeekViewModel, selectedAppDayOfWeek: Binding<AppDayOfWeek?>, selectedIsland: Binding<PirateIsland?>) {
        self._selectedAppDayOfWeek = selectedAppDayOfWeek
        self._selectedIsland = selectedIsland
        self.viewModel = viewModel
    }

    var body: some View {
        NavigationView {
            Form {
                DayInformationSection(
                    day: $day,
                    name: $name,
                    appDayOfWeekID: $appDayOfWeekID,
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
                    newMatTime: $newMatTime,
                    selectedAppDayOfWeek: $selectedAppDayOfWeek,
                    selectedIsland: $selectedIsland,
                    viewModel: viewModel,
                    selectedDay: $selectedDay,
                    name: $name,
                    appDayOfWeekID: $appDayOfWeekID,
                    viewContext: viewContext
                )
                .onChange(of: newMatTime?.time) { _ in
                    // Reset newMatTime when its time changes
                    newMatTime = MatTime(context: viewContext)
                }
                
                ScheduledMatTimesSection(
                    selectedDay: $selectedDay,
                    viewModel: viewModel,
                    selectedAppDayOfWeek: $selectedAppDayOfWeek
                )
            }
            .navigationTitle("Schedule Form")
            .onAppear {
                newMatTime = MatTime(context: viewContext)

                if let island = selectedIsland {
                    viewModel.fetchCurrentDayOfWeek(for: island)
                }
                if selectedAppDayOfWeek == nil {
                    selectedAppDayOfWeek = AppDayOfWeek(context: viewContext)
                } else {
                    updateUIWithAppDayOfWeek()
                }
            }
        }
    }

    private func updateUIWithAppDayOfWeek() {
        if let appDayOfWeek = selectedAppDayOfWeek {
            day = appDayOfWeek.day ?? ""
            name = appDayOfWeek.name ?? ""
            appDayOfWeekID = appDayOfWeek.appDayOfWeekID ?? ""
            
            // Fetch existing mat times associated with this AppDayOfWeek
            if let matTimes = appDayOfWeek.matTimes as? Set<MatTime> {
                viewModel.matTimesForDay[selectedDay] = Array(matTimes)
                print("Existing matTimes for \(selectedDay): \(viewModel.matTimesForDay[selectedDay] ?? [])")
            }
        }
    }
}

struct DayInformationSection: View {
    @Binding var day: String
    @Binding var name: String
    @Binding var appDayOfWeekID: String
    @Binding var selectedIsland: PirateIsland?
    let islands: FetchedResults<PirateIsland>
    @ObservedObject var viewModel: AppDayOfWeekViewModel

    var body: some View {
        Section(header: Text("Day Information")) {
            TextField("Day (e.g., Monday)", text: Binding(
                get: { day },
                set: { newValue in
                    day = newValue
                    if DayOfWeek(rawValue: newValue) != nil {
                        // Update selectedDay here if needed
                    }
                }
            ))
            .textInputAutocapitalization(.words)
            .autocorrectionDisabled()

            TextField("Schedule Name", text: $name)
            TextField("Day ID", text: $appDayOfWeekID)
                .keyboardType(.numberPad)

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
                }
            }
        }
    }
}

struct AddNewMatTimeSection: View {
    @State private var errorMessage = ""
    @Binding var newMatTime: MatTime?
    @Binding var selectedAppDayOfWeek: AppDayOfWeek?
    @Binding var selectedIsland: PirateIsland?
    @ObservedObject var viewModel: AppDayOfWeekViewModel
    @Binding var selectedDay: DayOfWeek
    @Binding var name: String
    @Binding var appDayOfWeekID: String
    let viewContext: NSManagedObjectContext
    
    init(
        newMatTime: Binding<MatTime?>,
        selectedAppDayOfWeek: Binding<AppDayOfWeek?>,
        selectedIsland: Binding<PirateIsland?>,
        viewModel: AppDayOfWeekViewModel,
        selectedDay: Binding<DayOfWeek>,
        name: Binding<String>,
        appDayOfWeekID: Binding<String>,
        viewContext: NSManagedObjectContext
    ) {
        self._newMatTime = newMatTime
        self._selectedAppDayOfWeek = selectedAppDayOfWeek
        self._selectedIsland = selectedIsland
        self.viewModel = viewModel
        self._selectedDay = selectedDay
        self._name = name
        self._appDayOfWeekID = appDayOfWeekID
        self.viewContext = viewContext
    }
    
    private var timeDate: Binding<Date> {
        Binding<Date>(
            get: {
                if let time = newMatTime?.time, !time.isEmpty {
                    let formatter = DateFormatter()
                    formatter.dateFormat = "HH:mm"
                    return formatter.date(from: time) ?? Date()
                } else {
                    return Date()
                }
            },
            set: { newDate in
                let formatter = DateFormatter()
                formatter.dateFormat = "HH:mm"
                newMatTime?.time = formatter.string(from: newDate)
                print("newMatTime.time updated to: \(newMatTime?.time ?? "nil")")
            }
        )
    }
    
    var body: some View {
        Section(header: Text("Add New Mat Time")) {
            // Print statements updated to handle optionals
            Text("Current newMatTime: \(newMatTime?.description ?? "nil")")
            Text("Current newMatTime.time: \(newMatTime?.time ?? "nil")")
            
            DatePicker("Time", selection: timeDate, displayedComponents: .hourAndMinute)
                .datePickerStyle(WheelDatePickerStyle())
            
            Toggle("Gi", isOn: Binding(
                get: { newMatTime?.gi ?? false },
                set: { newValue in
                    newMatTime?.gi = newValue
                }
            ))
            Toggle("No Gi", isOn: Binding(
                get: { newMatTime?.noGi ?? false },
                set: { newValue in
                    newMatTime?.noGi = newValue
                }
            ))
            Toggle("Open Mat", isOn: Binding(
                get: { newMatTime?.openMat ?? false },
                set: { newValue in
                    newMatTime?.openMat = newValue
                }
            ))
            Toggle("Restrictions", isOn: Binding(
                get: { newMatTime?.restrictions ?? false },
                set: { newValue in
                    newMatTime?.restrictions = newValue
                }
            ))
            
            if newMatTime?.restrictions ?? false {
                TextField("Restriction Description", text: Binding(
                    get: { newMatTime?.restrictionDescription ?? "" },
                    set: { newMatTime?.restrictionDescription = $0 }
                ))
                .textInputAutocapitalization(.sentences)
            }
            
            Toggle("Good for Beginners", isOn: Binding(
                get: { newMatTime?.goodForBeginners ?? false },
                set: { newValue in
                    newMatTime?.goodForBeginners = newValue
                }
            ))
            Toggle("Adult", isOn: Binding(
                get: { newMatTime?.adult ?? false },
                set: { newValue in
                    newMatTime?.adult = newValue
                }
            ))
            
            Button(action: addOrUpdateMatTime) {
                Text("Add Mat Time")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            
            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .foregroundColor(.red)
            }
        }
    }
    
    private func addOrUpdateMatTime() {
        // Check if an AppDayOfWeek object with the same day value already exists
        let fetchRequest: NSFetchRequest<AppDayOfWeek> = AppDayOfWeek.fetchRequest()
        if let island = selectedIsland {
            fetchRequest.predicate = NSPredicate(format: "day == %@ AND pIsland == %@", selectedDay.rawValue, island)

            do {
                let results = try viewContext.fetch(fetchRequest)
                
                var appDayOfWeek: AppDayOfWeek
                
                if results.isEmpty {
                    // Create a new AppDayOfWeek object
                    appDayOfWeek = AppDayOfWeek(context: viewContext)
                    appDayOfWeek.day = selectedDay.rawValue
                    appDayOfWeek.name = name
                    appDayOfWeek.appDayOfWeekID = appDayOfWeekID
                    appDayOfWeek.pIsland = island
                } else {
                    // Use the existing AppDayOfWeek object
                    appDayOfWeek = results.first!
                    appDayOfWeek.name = name
                    appDayOfWeek.appDayOfWeekID = appDayOfWeekID
                }
                
                // Add newMatTime to appDayOfWeek's matTimes
                appDayOfWeek.addToMatTimes(newMatTime!)
                print("MatTime being added: \(newMatTime!.description)")
                
                do {
                    try viewContext.save()
                    print("Successfully saved new MatTime with time: \(newMatTime!.time ?? "nil")")
                    self.newMatTime = MatTime(context: viewContext) // Reset MatTime
                    viewModel.refreshMatTimes() // Refresh the UI
                } catch {
                    print("Failed to save new MatTime: \(error.localizedDescription)")
                }
            } catch {
                print("Failed to fetch AppDayOfWeek: \(error.localizedDescription)")
            }
        } else {
            print("No island selected")
        }
    }
}

struct ScheduledMatTimesSection: View {
    @Binding var selectedDay: DayOfWeek
    @ObservedObject var viewModel: AppDayOfWeekViewModel
    @Binding var selectedAppDayOfWeek: AppDayOfWeek?

    var body: some View {
        Section(header: Text("Scheduled Mat Times")) {
            if selectedAppDayOfWeek != nil {
                let matTimes = viewModel.matTimesForDay[selectedDay] ?? []
                ForEach(matTimes, id: \.self) { matTime in
                    HStack {
                        Text(matTime.time ?? "")
                        Spacer()
                        Text(matTime.gi ? "Gi" : "No Gi")
                        Text(matTime.openMat ? "Open Mat" : "")
                    }
                }
            } else {
                Text("No scheduled mat times")
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
