//
//  AddNewMatTimeSection.swift
//  Seas_3
//
//  Created by Brian Romero on 8/1/24.
//

import SwiftUI
import CoreData
import FirebaseFirestore



struct AddNewMatTimeSection: View {
    @Binding var selectedIsland: PirateIsland?
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
    @State private var isLoading = false
    @State private var showToast = false
    @State private var toastMessage = ""

    
    // Ensure AppDayOfWeekRepository is accessible in your view.
    @ObservedObject var appDayOfWeekRepository = AppDayOfWeekRepository.shared
    @StateObject var userProfileViewModel = UserProfileViewModel()
    let selectIslandAndDay: (PirateIsland, DayOfWeek) async -> AppDayOfWeek?
    
    var isDaySelected: Bool {
        selectedDay != nil
    }

    var isMatTypeSelected: Bool {
        gi || noGi || openMat
    }


    // Computed property for button disable state
    var isAddNewMatTimeDisabled: Bool {
        let isDaySelected = selectedDay != nil
        let isMatTimeSet = self.isMatTimeSet
        let isLoading = self.isLoading
        let isMatTypeSelected = gi || noGi || openMat

        let result = !(isDaySelected && isMatTimeSet && !isLoading && isMatTypeSelected)

        // Debugging outputs
        print("=== Add New Mat Time Button State ===")
        print("Day Selected: \(selectedDay?.displayName ?? "None")")
        print("Is Mat Time Set: \(isMatTimeSet)")
        print("Is Loading: \(isLoading)")
        print("Mat Type Selected (Gi/NoGi/OpenMat): \(isMatTypeSelected)")
        print("Selected AppDayOfWeek: \(viewModel.selectedAppDayOfWeek?.day ?? "None")")
        print("Final Disabled State: \(result)")
        print("=====================================")

        return result
    }

    var body: some View {
        ZStack {
            VStack(alignment: .leading) {
                Text("Add New Mat Time")
                    .font(.headline)
                    .padding(.bottom, 8)

                DatePicker("Select Time", selection: $selectedTime, displayedComponents: .hourAndMinute)
                    .onChange(of: selectedTime) { newValue in
                        isMatTimeSet = true
                        print("Selected time changed to: \(formatDateToString(newValue))")
                    }

                MatTypeTogglesView(gi: $gi, noGi: $noGi, openMat: $openMat, goodForBeginners: $goodForBeginners, kids: $kids)
                RestrictionsView(restrictions: $restrictions, restrictionDescriptionInput: $restrictionDescriptionInput)
                
                if !daySelected {
                    Text("Select a Day to View or Add Daily Mat Times.")
                        .foregroundColor(.red)
                }

                Spacer()

                Button(action: addNewMatTime) {
                    Text("Add New Mat Time")
                        .padding()
                        .background(isAddNewMatTimeDisabled ? Color.gray : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .disabled(isAddNewMatTimeDisabled)
            }
            .onChange(of: selectedDay) { _ in
                handleSelectedDayChange()
            }
            .onChange(of: viewModel.selectedAppDayOfWeek) { newValue in
                print("Selected AppDayOfWeek changed to: \(String(describing: newValue?.day))")
            }

            .alert(isPresented: $showAlert) {
                Alert(title: Text(alertTitle), message: Text(alertMessage))
            }
            .onChange(of: showToast) { newValue in
                if newValue {
                    print("ToastView appeared with message: \(toastMessage)")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation {
                            showToast = false
                            print("ToastView dismissed")
                        }
                    }
                }
            }

            ToastView(showToast: $showToast, message: toastMessage)
        }
    }
    
    func handleSelectedDayChange() {
        guard let selectedDay = selectedDay else { return }

        daySelected = true
        print("Selected day changed to: \(selectedDay.displayName)")

        if let selectedIsland = selectedIsland {
            Task {
                isLoading = true
                print("Fetching AppDayOfWeek for \(selectedIsland.islandName ?? "Unknown") on \(selectedDay.displayName)")

                if let appDayOfWeek = await selectIslandAndDay(selectedIsland, selectedDay) {
                    viewModel.selectedAppDayOfWeek = appDayOfWeek
                } else {
                    alertTitle = "No Mat Times Found"
                    alertMessage = "No mat times have been entered for \(selectedDay.displayName)."
                    print("Failed to fetch or create AppDayOfWeek-No mat times have been entered for \(selectedDay.displayName).")
                    showAlert = true
                }
                isLoading = false
            }
        }
    }
    
    
    func addNewMatTime() {
        print("Attempting to add new mat time")
        print("Day selected: \(daySelected)")
        print("Is Mat Time Set: \(isMatTimeSet)")
        print("Selected AppDayOfWeek: \(viewModel.selectedAppDayOfWeek?.day ?? "None")")

        guard validateInput() else { return }
        guard let selectedIsland = selectedIsland, let selectedDay = selectedDay else { return }

        Task {
            isLoading = true
            print("About to add mat time with:")
            print("- selectedDay: \(selectedDay.displayName)")
            print("- selectedIsland: \(selectedIsland.islandName ?? "nil")")
            print("- selectedAppDayOfWeek: \(viewModel.selectedAppDayOfWeek?.day ?? "nil")")

            await handleAddNewMatTime(selectedIsland: selectedIsland, selectedDay: selectedDay)
        }
    }


    
    func handleAddNewMatTime(selectedIsland: PirateIsland, selectedDay: DayOfWeek) async {
        if let appDayOfWeek = viewModel.selectedAppDayOfWeek {
            // Sync current with selected
            viewModel.currentAppDayOfWeek = appDayOfWeek
            await saveMatTime(appDayOfWeek: appDayOfWeek)
        } else {
            print("No existing AppDayOfWeek, creating a new one...")

            // Fetch user info
            userProfileViewModel.fetchData()

            // Ensure UserInfo entity has a valid name
            if let userInfo = userProfileViewModel.userInfo {
                if userInfo.name.isEmpty {
                    userInfo.name = "Unknown User"
                }
            }

            let context = PersistenceController.shared.container.viewContext
            let generatedName = appDayOfWeekRepository.generateName(for: selectedIsland, day: selectedDay)
            let newAppDayOfWeek = AppDayOfWeek(context: context)

            // Set required properties
            newAppDayOfWeek.id = UUID()
            newAppDayOfWeek.day = selectedDay.rawValue
            newAppDayOfWeek.name = generatedName
            newAppDayOfWeek.pIsland = selectedIsland
            newAppDayOfWeek.createdTimestamp = Date()
            newAppDayOfWeek.appDayOfWeekID = appDayOfWeekRepository.generateAppDayOfWeekID(for: selectedIsland, day: selectedDay)

            // Debug logging
            print("Generated name: \(newAppDayOfWeek.name ?? "None")")
            print("Generated AppDayOfWeekID: \(newAppDayOfWeek.appDayOfWeekID ?? "None")")

            do {
                try context.save()
                print("New AppDayOfWeek created: \(selectedDay.displayName)")
                
                // Sync both selected and current
                viewModel.selectedAppDayOfWeek = newAppDayOfWeek
                viewModel.currentAppDayOfWeek = newAppDayOfWeek

                await saveMatTime(appDayOfWeek: newAppDayOfWeek)
            } catch {
                print("Failed to create AppDayOfWeek: \(error)")
                alertTitle = "Error"
                alertMessage = "Failed to create AppDayOfWeek."
                showAlert = true
                isLoading = false
                return
            }
        }

        print("Mat time saved successfully.")
        isLoading = false
    }


    func validateInput() -> Bool {
        print("Validating input with selectedAppDayOfWeek: \(String(describing: viewModel.selectedAppDayOfWeek?.day))")

        if !daySelected {
            alertTitle = "Error"
            alertMessage = "Please select a day3."
            showAlert = true
            return false
        }

        if !isMatTimeSet {
            alertTitle = "Error"
            alertMessage = "Please select a time."
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

    
    func saveMatTime(appDayOfWeek: AppDayOfWeek) async {
        print("💾 Starting saveMatTime()")

        guard selectedIsland != nil else {
            print("❌ Missing necessary information: Island is nil")
            alertTitle = "Error"
            alertMessage = "Missing necessary information."
            showAlert = true
            return
        }

        let time = formatDateToString(selectedTime)
        let matTimeType = determineMatTimeType()
        let restrictionDescription = restrictions ? restrictionDescriptionInput : ""

        // Debugging print statements to check the values
        print("Time: \(time)")
        print("MatType: \(matTimeType)")
        print("RestrictionDescription: \(restrictionDescription)")
        print("Gi: \(gi), NoGi: \(noGi), OpenMat: \(openMat)")

        do {
            // 1. Sync current AppDayOfWeek and Save AppDayOfWeek to Firestore
            viewModel.currentAppDayOfWeek = appDayOfWeek
            print("🔥 Saving AppDayOfWeek to Firestore...")
            viewModel.saveAppDayOfWeekToFirestore(selectedIsland: selectedIsland!, selectedDay: selectedDay!)
            
            // 2. Create and Save MatTime object
            print("💾 Creating MatTime object...")
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
            
            // MatTime object is now created or updated
            print("✅ MatTime created successfully: \(matTime.id?.uuidString ?? UUID().uuidString)")

            // 3. Save MatTime to Firestore
            print("💾 Saving MatTime to Firestore...")
            
            var matTimeData: [String: Any] = matTime.toFirestoreData()
            let matTimeRef = Firestore.firestore().collection("MatTime").document(matTime.id?.uuidString ?? UUID().uuidString)
            
            // Include a reference to AppDayOfWeek in MatTime
            matTimeData["appDayOfWeek"] = Firestore.firestore().collection("AppDayOfWeek").document(appDayOfWeek.appDayOfWeekID ?? UUID().uuidString)
            
            // Save MatTime document
            try await matTimeRef.setData(matTimeData)
            print("✅ MatTime saved to Firestore: \(matTime.id?.uuidString ?? UUID().uuidString)")

            // 4. Save MatTime to Core Data
            let context = PersistenceController.shared.container.viewContext
            appDayOfWeek.addToMatTimes(matTime)

            // Save context to Core Data
            print("💾 Saving to Core Data...")
            try context.save()
            print("✅ Core Data save successful")

            // 5. Reset state variables
            DispatchQueue.main.async {
                self.alertTitle = "Success"
                self.alertMessage = "New mat time added successfully!"
                self.showAlert = true

                // Show toast
                self.toastMessage = "Mat time added!"
                self.showToast = true

                // Reset form
                print("🔄 Resetting state variables...")
                self.resetStateVariables()
                
                // Trigger the view reset by changing selectedDay
                if let currentSelectedDay = self.selectedDay {
                    self.selectedDay = nil  // Clear selectedDay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        self.selectedDay = currentSelectedDay  // Reassign to trigger onChange
                    }
                }
            }

        } catch {
            print("❌ Error saving mat time: \(error.localizedDescription)")
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
        viewModel.selectedAppDayOfWeek = nil
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

    
    func formatDateToString(_ date: Date) -> String {
        return DateFormat.time.string(from: date)
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
