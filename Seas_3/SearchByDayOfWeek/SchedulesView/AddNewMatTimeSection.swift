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
    @Binding var selectedDay: DayOfWeek
    @Binding var daySelected: Bool
    @State var matTime: MatTime?
    @State private var isMatTimeSet: Bool = false
    @State private var showAlert: Bool = false
    @State private var alertTitle: String = ""
    @State private var alertMessage: String = ""

    @State private var selectedTime: Date = Date().roundToNearestHour()
    @State private var restrictionDescriptionInput: String = ""

    // Define state properties for toggles
    @State private var gi: Bool = false
    @State private var noGi: Bool = false
    @State private var openMat: Bool = false
    @State private var goodForBeginners: Bool = false
    @State private var kids: Bool = false
    @State private var restrictions: Bool = false
    @ObservedObject var viewModel: AppDayOfWeekViewModel
    @State private var showRestrictionsTooltip = false


    var body: some View {
        Section(header: Text("Add New Mat Time")) {
            VStack(alignment: .leading) {
                DatePicker("Select Time", selection: $selectedTime, displayedComponents: .hourAndMinute)
                    .onChange(of: selectedTime) { newValue in
                        isMatTimeSet = true
                        print("Selected time: \(formatDateToString(newValue))")
                    }

                ToggleView(title: "Gi", isOn: $gi)
                ToggleView(title: "No Gi", isOn: $noGi)
                ToggleView(title: "Open Mat", isOn: $openMat)
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
                    if validateInput() {
                        saveMatTime()
                    }
                }) {
                    Text("Add New Mat Time")
                }
                .disabled(!(daySelected && isMatTimeSet && selectedAppDayOfWeek != nil && (gi || noGi || openMat)))
            }
        }
        .onChange(of: selectedDay) { _ in
            daySelected = true
            print("Selected day: \(selectedDay.displayName)")
            if let selectedIsland = selectedIsland {
                selectIslandAndDay(island: selectedIsland, day: selectedDay)
            }
        }
        .alert(isPresented: $showAlert) {
            Alert(title: Text(alertTitle), message: Text(alertMessage))
        }
    }

    func validateInput() -> Bool {
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
            alertMessage = "Please select an app day of week."
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

    func saveMatTime() {
        guard let appDayOfWeek = selectedAppDayOfWeek else { return }
        
        let time = formatDateToString(selectedTime)
        let matTimeType = determineMatTimeType() // Implement determineMatTimeType function
        let restrictionDescription = restrictions ? restrictionDescriptionInput : ""
        
        do {
            try viewModel.updateOrCreateMatTime(nil,
                                                time: time,
                                                type: matTimeType,
                                                gi: gi,
                                                noGi: noGi,
                                                openMat: openMat,
                                                restrictions: restrictions,
                                                restrictionDescription: restrictionDescription,
                                                goodForBeginners: goodForBeginners,
                                                kids: kids,
                                                for: appDayOfWeek)
            
            // Reset state variables after saving
            resetStateVariables()
        } catch {
            print("Error saving mat time: \(error)")
            alertTitle = "Error"
            alertMessage = "Failed to save mat time."
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

    func selectIslandAndDay(island: PirateIsland, day: DayOfWeek) {
        if let appDayOfWeek = viewModel.repository.fetchOrCreateAppDayOfWeek(for: day, pirateIsland: island, context: viewModel.viewContext) {
            selectedAppDayOfWeek = appDayOfWeek
            print("Selected AppDayOfWeek with day: \(selectedAppDayOfWeek?.day ?? "Unknown")")
        } else {
            print("Failed to fetch or create AppDayOfWeek for day: \(day) and island: \(island.islandName ?? "")")
            alertTitle = "Error"
            alertMessage = "Failed to fetch or create AppDayOfWeek."
            showAlert = true
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

struct AddNewMatTimeSection_Previews: PreviewProvider {
    @State private static var selectedDay: DayOfWeek = .monday

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
