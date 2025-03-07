//
//  AddNewMatTimeSection.swift
//  Seas_3
//
//  Created by Brian Romero on 8/1/24.
//

import SwiftUI
import CoreData


struct AddNewMatTimeSection: View {
    @Binding var selectedIsland: PirateIsland?
    @Binding var selectedAppDayOfWeek: AppDayOfWeek?
    @Binding var selectedDay: DayOfWeek?
    @StateObject var matTimesViewModel = MatTimesViewModel()
    @Binding var daySelected: Bool
    @State var matTime: MatTime?
    @State private var isMatTimeSet: Bool = false
    @State private var showAlert: Bool = false
    @State private var alertTitle: String = ""
    @State private var alertMessage: String = ""
    @State private var selectedTime: Date = Date().roundToNearestHour()
    @State private var restrictionDescriptionInput: String = ""
    @State private var gi: Bool = false
    @State private var noGi: Bool = false
    @State private var openMat: Bool = false
    @State private var goodForBeginners: Bool = false
    @State private var kids: Bool = false
    @State private var restrictions: Bool = false
    @ObservedObject var viewModel: AppDayOfWeekViewModel
    @State private var showRestrictionsTooltip = false
    @State private var isAppDayOfWeekLoaded = false
    @State private var isLoading = false

    // Computed property for button disable state
    var isAddNewMatTimeDisabled: Bool {
        let result = !(daySelected && isMatTimeSet && !isLoading && (gi || noGi || openMat) && selectedAppDayOfWeek != nil)
        
        print("=== Add New Mat Time Button State ===")
        print("Day Selected: \(daySelected)")
        print("Is Mat Time Set: \(isMatTimeSet)")
        print("Is Loading: \(isLoading)")
        print("Mat Type Selected (Gi/NoGi/OpenMat): \(gi || noGi || openMat)")
        print("Selected AppDayOfWeek: \(selectedAppDayOfWeek?.day ?? "None")")
        print("Final Disabled State: \(result)")
        print("=====================================")
        
        return result
    }

    var body: some View {
        Section(header: Text("Add New Mat Time")) {
            VStack(alignment: .leading) {
                DatePicker("Select Time", selection: $selectedTime, displayedComponents: .hourAndMinute)
                    .onChange(of: selectedTime) { newValue in
                        isMatTimeSet = true
                        print("Selected time changed to: \(formatDateToString(newValue))")
                    }

                ToggleView(title: "Gi", isOn: $gi)
                    .onChange(of: gi) { newValue in
                        print("Gi toggled: \(newValue)")
                    }

                ToggleView(title: "No Gi", isOn: $noGi)
                    .onChange(of: noGi) { newValue in
                        print("No Gi toggled: \(newValue)")
                    }

                ToggleView(title: "Open Mat", isOn: $openMat)
                    .onChange(of: openMat) { newValue in
                        print("Open Mat toggled: \(newValue)")
                    }

                ToggleView(title: "Good for Beginners", isOn: $goodForBeginners)
                ToggleView(title: "Kids Class", isOn: $kids)

                HStack {
                    Text("Restrictions")
                    InfoTooltip(text: "*", tooltipMessage: "e.g., White Gis Only, Competition Class, Mat Fees Required, etc.")
                    ToggleView(title: "", isOn: $restrictions)
                }

                if restrictions {
                    TextField("Restriction Description", text: $restrictionDescriptionInput)
                }

                if !daySelected {
                    Text("Please select a day.")
                        .foregroundColor(.red)
                }

                Button(action: {
                    print("Attempting to add new mat time")
                    print("Day selected: \(daySelected)")
                    print("Is Mat Time Set: \(isMatTimeSet)")
                    print("Selected AppDayOfWeek: \(selectedAppDayOfWeek?.day ?? "None")")
                    print("Mat Type Selection - Gi: \(gi), NoGi: \(noGi), Open Mat: \(openMat)")
                    
                    if isAppDayOfWeekLoaded {
                        if validateInput() {
                            Task {
                                await saveMatTime()
                            }
                        }
                    } else {
                        alertTitle = "Error"
                        alertMessage = "Please wait for the app day of week to load."
                        showAlert = true
                    }
                }) {
                    Text("Add New Mat Time")
                }
                .disabled(isAddNewMatTimeDisabled) // Using computed property for clarity
            }
        }
        .onChange(of: selectedDay) { _ in
            daySelected = true
            print("Selected day changed to: \(selectedDay!.displayName)")
            
            if let selectedIsland = selectedIsland {
                Task {
                    isLoading = true
                    if let appDayOfWeek = await selectIslandAndDay(island: selectedIsland, day: selectedDay!) {
                        selectedAppDayOfWeek = appDayOfWeek
                        isAppDayOfWeekLoaded = true
                    } else {
                        print("Error: Failed to fetch or create AppDayOfWeek")
                        alertTitle = "Error"
                        alertMessage = "Failed to fetch or create AppDayOfWeek."
                        showAlert = true
                    }
                    isLoading = false
                }
            }
        }
        .onChange(of: selectedAppDayOfWeek) { _ in
            print("Selected AppDayOfWeek changed to: \(String(describing: selectedAppDayOfWeek?.day))")
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                print("Delayed check: Selected AppDayOfWeek is \(String(describing: selectedAppDayOfWeek?.day))")
            }
        }
        .alert(isPresented: $showAlert) {
            Alert(title: Text(alertTitle), message: Text(alertMessage))
        }
    }

    func validateInput() -> Bool {
        print("Validating input with selectedAppDayOfWeek: \(String(describing: selectedAppDayOfWeek?.day))")
        
        if !daySelected {
            alertTitle = "Error"
            alertMessage = "Please select a day."
            showAlert = true
            return false
        }
        
        if !isMatTimeSet {
            alertTitle = "Error"
            alertMessage = "Please select a time."
            showAlert = true
            return false
        }
        
        if selectedAppDayOfWeek == nil {
            alertTitle = "Error"
            alertMessage = "Please wait for the app day of the week to load."
            showAlert = true
            return false
        }
        
        if !(gi || noGi || openMat) {
            alertTitle = "Error"
            alertMessage = "Please select at least one mat time type."
            showAlert = true
            return false
        }
        
        return true
    }


    
    func saveMatTime() async {
        guard let appDayOfWeek = selectedAppDayOfWeek,
              let selectedIsland = selectedIsland else {
            print("Error: Missing selectedAppDayOfWeek or selectedIsland.")
            alertTitle = "Error"
            alertMessage = "Missing necessary information."
            showAlert = true
            return
        }

        let time = formatDateToString(selectedTime)
        let matTimeType = determineMatTimeType()
        let restrictionDescription = restrictions ? restrictionDescriptionInput : ""

        // Log the input values
        print("Attempting to save mat time with following parameters:")
        print("Time: \(time)")
        print("Mat Time Type: \(matTimeType)")
        print("Restriction Description: \(restrictionDescription)")
        print("Gi: \(gi), No Gi: \(noGi), Open Mat: \(openMat), Good for Beginners: \(goodForBeginners), Kids: \(kids)")
        
        print("Saving mat time for AppDayOfWeek: \(appDayOfWeek.day)")

        do {
            let matTime = try await viewModel.updateOrCreateMatTime(
                nil,
                time: time,
                type: matTimeType,
                gi: gi,
                noGi: noGi,
                openMat: openMat,
                restrictions: restrictions,
                restrictionDescription: restrictionDescription,
                goodForBeginners: goodForBeginners,
                kids: kids,
                for: appDayOfWeek
            )
            
            print("MatTime successfully created or updated: \(matTime)")

            // Save to Firestore with error handling
            do {
                try await matTimesViewModel.saveMatTimeToFirestore(
                    matTime: matTime,
                    selectedAppDayOfWeek: appDayOfWeek,
                    selectedIsland: selectedIsland
                )
                print("Mat time successfully saved to Firestore")
            } catch {
                print("Error saving to Firestore: \(error.localizedDescription)")
            }

            // Save AppDayOfWeek to Firestore
            print("Attempting to save AppDayOfWeek to Firestore: \(selectedAppDayOfWeek?.day ?? "No Day")")
            viewModel.saveAppDayOfWeekToFirestore()

            print("MatTime and AppDayOfWeek successfully saved to Firestore.")

            // Reset state variables after saving
            resetStateVariables()
        } catch {
            print("Error saving mat time: \(error)")
            
            let nsError = error as NSError
            print("Error Domain: \(nsError.domain)")
            print("Error Code: \(nsError.code)")
            print("Error Description: \(nsError.localizedDescription)")
            print("Error Recovery Suggestion: \(nsError.localizedRecoverySuggestion ?? "N/A")")
            
            alertTitle = "Error"
            alertMessage = "Failed to save mat time: \(error.localizedDescription)"
            showAlert = true
        }
    }

    func resetStateVariables() {
        selectedTime = Date()
        gi = false
        noGi = false
        openMat = false
        goodForBeginners = false
        kids = false
        restrictions = false
        restrictionDescriptionInput = ""
        isMatTimeSet = false
        selectedAppDayOfWeek = nil
        daySelected = false
    }
    
    
    func determineMatTimeType() -> String {
        var matTimeType: [String] = []
        
        if gi {
            matTimeType.append("Gi")
        }
        
        if noGi {
            matTimeType.append("No Gi")
        }
        
        if openMat {
            matTimeType.append("Open Mat")
        }
        
        return matTimeType.joined(separator: ", ")
    }

    func selectIslandAndDay(island: PirateIsland, day: DayOfWeek) async -> AppDayOfWeek? {
        print("Attempting to select island and day")
        
        let (appDayOfWeek, _) = await viewModel.fetchCurrentDayOfWeek(for: island, day: day, selectedDayBinding: Binding(get: { self.selectedDay }, set: { self.selectedDay = $0 ?? .monday }))
        
        if let appDayOfWeek = appDayOfWeek {
            print("Successfully fetched AppDayOfWeek")
            return appDayOfWeek
        } else {
            print("Failed to fetch AppDayOfWeek")
            return nil
        }
    }
    
    func formatDateToString(_ date: Date) -> String {
        return DateFormat.time.string(from: date)
    }

    struct ToggleView: View {
        let title: String
        @Binding var isOn: Bool

        var body: some View {
            Toggle(isOn: $isOn) {
                Text(title)
            }
            .onChange(of: isOn) { newValue in
                print("\(title): \(newValue ? "Enabled" : "Disabled")")
            }
        }
    }
}


extension Date {
    /// Rounds the date to the nearest hour, either up or down.
    func roundToNearestHour() -> Date {
        let calendar = Calendar.current
        let minuteComponent = calendar.component(.minute, from: self)

        if minuteComponent >= 30 {
            // Round up to the next hour
            return calendar.date(byAdding: .minute, value: 60 - minuteComponent, to: self)!
        } else {
            // Round down to the current hour
            return calendar.date(byAdding: .minute, value: -minuteComponent, to: self)!
        }
    }
}

/*
struct AddNewMatTimeSection_Previews: PreviewProvider {
    @State private static var selectedDay: DayOfWeek? = .monday

    static var previews: some View {
        let pirateIsland = PirateIsland(context: PersistenceController.preview.container.viewContext)
        pirateIsland.islandName = "Sample Island"
        let appDayOfWeek = AppDayOfWeek(context: PersistenceController.preview.container.viewContext)
        let matTime: MatTime? = nil
        let persistenceController = PersistenceController.preview
        let repository = AppDayOfWeekRepository(persistenceController: persistenceController)
        let enterZipCodeViewModel = EnterZipCodeViewModel(repository: repository, persistenceController: persistenceController)
        let viewModel = AppDayOfWeekViewModel(
            selectedIsland: pirateIsland,
            repository: repository,
            enterZipCodeViewModel: enterZipCodeViewModel
        )

        return Group {
            AddNewMatTimeSection(
                selectedIsland: .constant(pirateIsland),
                selectedAppDayOfWeek: .constant(appDayOfWeek),
                selectedDay: $selectedDay,
                daySelected: .constant(true),
                matTime: matTime,
                viewModel: viewModel
            )
            .previewLayout(.sizeThatFits)
            .previewDisplayName("Default")

            AddNewMatTimeSection(
                selectedIsland: .constant(pirateIsland),
                selectedAppDayOfWeek: .constant(appDayOfWeek),
                selectedDay: $selectedDay,
                daySelected: .constant(false),
                matTime: matTime,
                viewModel: viewModel
            )
            .previewLayout(.sizeThatFits)
            .previewDisplayName("Day Not Selected")
        }
    }
}
*/
