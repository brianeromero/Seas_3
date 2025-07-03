//
//  AddNewMatTimeSection.swift
//  Seas_3
//
//  Created by Brian Romero on 8/1/24.
//

import Foundation
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
    @State private var showToast = false // This controls the visibility of the toast via the modifier
    @State private var toastMessage = ""
    @State private var toastType: ToastView.ToastType = .custom // New: To control the type of toast

    
    // FIX 1: Add @Environment for viewContext
    @Environment(\.managedObjectContext) private var viewContext
    
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
                
                if let existingMatTime = matTime {
                    HStack {
                        Button(action: {
                            // Pass the ObjectID to updateMatTime
                            updateMatTime(existingMatTime.objectID)
                        }) {
                            Text("Update Mat Time")
                                .padding()
                                .background(Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                        
                        Button(action: {
                            deleteMatTime(existingMatTime)
                        }) {
                            Text("Delete")
                                .padding()
                                .background(Color.red)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                    }
                } else {
                    Button(action: addNewMatTime) {
                        Text("Add New Mat Time")
                            .padding()
                            .background(isAddNewMatTimeDisabled ? Color.gray : Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    .disabled(isAddNewMatTimeDisabled)
                }
            }
            // MARK: - onChange DEP-17 Fix
            .onChange(of: selectedDay) { oldValue, newValue in // Updated signature
                handleSelectedDayChange()
            }
            // MARK: - onChange DEP-17 Fix
            .onChange(of: viewModel.selectedAppDayOfWeek) { oldValue, newValue in // Updated signature
                print("Selected AppDayOfWeek changed to: \(String(describing: newValue?.day))")
            }
            .alert(isPresented: $showAlert) {
                Alert(title: Text(alertTitle), message: Text(alertMessage))
            }
            // Removed the old onChange(of: showToast) block.
            // The ToastModifier handles the timer internally.
            .onAppear {
                if let existing = matTime {
                    populateFieldsFromMatTime(existing)
                }
            }
        }
        // MARK: - Apply the new .showToast modifier here
        .showToast(isPresenting: $showToast, message: toastMessage, type: toastType)
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
                    // Update UI properties on the MainActor
                    await MainActor.run {
                        viewModel.selectedAppDayOfWeek = appDayOfWeek
                    }
                } else {
                    await MainActor.run {
                        alertTitle = "No Mat Times Found"
                        alertMessage = "No mat times have been entered for \(selectedDay.displayName)."
                        print("Failed to fetch or create AppDayOfWeek-No mat times have been entered for \(selectedDay.displayName).")
                        showAlert = true
                    }
                }
                await MainActor.run {
                    isLoading = false
                }
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
            isLoading = true // Set loading true at the start
            print("About to add mat time with:")
            print("- selectedDay: \(selectedDay.displayName)")
            print("- selectedIsland: \(selectedIsland.islandName ?? "nil")")
            print("- selectedAppDayOfWeek: \(viewModel.selectedAppDayOfWeek?.day ?? "nil")")
            
            await handleAddNewMatTime(selectedIsland: selectedIsland, selectedDay: selectedDay)
            // isLoading will be set to false inside handleAddNewMatTime
        }
    }
    
    func handleAddNewMatTime(selectedIsland: PirateIsland, selectedDay: DayOfWeek) async {
        print("About to add mat time with:")
        print("- selectedDay: \(selectedDay.displayName)")
        print("- selectedIsland: \(selectedIsland.islandName ?? "nil")")
        print("- selectedAppDayOfWeek (pre-process): \(viewModel.selectedAppDayOfWeek?.day ?? "nil")")

        do {
            let appDayOfWeekToUseID: NSManagedObjectID

            if let appDayOfWeek = viewModel.selectedAppDayOfWeek {
                // If an existing AppDayOfWeek is selected, use its ID
                appDayOfWeekToUseID = appDayOfWeek.objectID
                print("Using existing AppDayOfWeek with ID: \(appDayOfWeekToUseID)")
            } else {
                print("No existing AppDayOfWeek, creating a new one...")

                // Create new AppDayOfWeek on a background context
                // Get ID from the main thread object
                let selectedIslandID = selectedIsland.objectID

                // --- FIX: Manual context creation and work execution ---
                let backgroundContext = PersistenceController.shared.container.newBackgroundContext()

                // Perform the work on the background context using `await` for its async nature
                appDayOfWeekToUseID = try await backgroundContext.perform { // This `perform` *should* pass the context implicitly
                    // Rehydrate selectedIsland on the background context
                    guard let islandOnBGContext = try backgroundContext.existingObject(with: selectedIslandID) as? PirateIsland else {
                        throw NSError(domain: "CoreDataError", code: 202, userInfo: [NSLocalizedDescriptionKey: "Failed to rehydrate selectedIsland in background context."])
                    }

                    let generatedName = self.appDayOfWeekRepository.generateName(for: islandOnBGContext, day: selectedDay)
                    let newAppDayOfWeek = AppDayOfWeek(context: backgroundContext) // Use the backgroundContext here

                    newAppDayOfWeek.id = UUID()
                    newAppDayOfWeek.day = selectedDay.rawValue
                    newAppDayOfWeek.name = generatedName
                    newAppDayOfWeek.pIsland = islandOnBGContext // Assign on the correct context
                    newAppDayOfWeek.createdTimestamp = Date()
                    newAppDayOfWeek.appDayOfWeekID = self.appDayOfWeekRepository.generateAppDayOfWeekID(for: islandOnBGContext, day: selectedDay)

                    print("Generated name: \(newAppDayOfWeek.name ?? "None")")
                    print("Generated AppDayOfWeekID: \(newAppDayOfWeek.appDayOfWeekID ?? "None")")

                    try backgroundContext.save() // Save the new AppDayOfWeek on the background context
                    print("New AppDayOfWeek created in background context: \(selectedDay.displayName)")
                    return newAppDayOfWeek.objectID
                }
            }

            // Now call saveMatTime with the AppDayOfWeek's ObjectID
            let matTimeObjectID = try await saveMatTime(appDayOfWeekID: appDayOfWeekToUseID)
            print("Mat time created successfully with ID: \(matTimeObjectID)")

            // Update UI properties on the MainActor
            await MainActor.run {
                // Rehydrate the AppDayOfWeek on the main context for UI purposes
                if let appDayOfWeekOnMainContext = try? self.viewContext.existingObject(with: appDayOfWeekToUseID) as? AppDayOfWeek {
                    viewModel.selectedAppDayOfWeek = appDayOfWeekOnMainContext
                    viewModel.currentAppDayOfWeek = appDayOfWeekOnMainContext
                    print("Synced viewModel.selectedAppDayOfWeek and currentAppDayOfWeek on MainActor.")
                }

                self.alertTitle = "Success"
                self.alertMessage = "New mat time added successfully!"
                self.showAlert = true
                self.toastMessage = "Mat time added!"
                self.showToast = true
                self.resetStateVariables()

                // This forces a refresh of mat times if you're observing them
                if let currentSelectedDay = self.selectedDay {
                    self.selectedDay = nil // Temporarily nil out to force change detection
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        self.selectedDay = currentSelectedDay // Reset to trigger update
                    }
                }
                self.isLoading = false // Set loading false after completion
            }

        } catch {
            await MainActor.run {
                print("❌ Error saving mat time: \(error.localizedDescription)")
                self.alertTitle = "Error"
                self.alertMessage = "Failed to create or save mat time: \(error.localizedDescription)"
                self.showAlert = true
                self.isLoading = false // Set loading false on error
            }
        }
    }
    
    func validateInput() -> Bool {
        print("Validating input with selectedAppDayOfWeek: \(String(describing: viewModel.selectedAppDayOfWeek?.day))")
        
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
        
        if !(gi || noGi || openMat) {
            alertTitle = "Error"
            alertMessage = "Please select at least one mat time type."
            showAlert = true
            return false
        }
        
        return true
    }
    
    // MARK: - saveMatTime (Adjusted to use NSManagedObjectID)
    func saveMatTime(appDayOfWeekID: NSManagedObjectID) async throws -> NSManagedObjectID {
        print("💾 Starting saveMatTime(appDayOfWeekID:)")

        guard let selectedIsland = self.selectedIsland,
              let selectedDay = self.selectedDay else {
            print("❌ Missing necessary information: Island or Day is nil")
            throw NSError(domain: "AddNewMatTimeSectionError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Selected Island or Day is missing."])
        }

        let time = formatDateToString(selectedTime)
        let matTimeType = determineMatTimeType()
        let restrictionDescription = restrictions ? restrictionDescriptionInput : ""

        print("Time: \(time)")
        print("MatType: \(matTimeType)")
        print("RestrictionDescription: \(restrictionDescription)")
        print("Gi: \(gi), NoGi: \(noGi), OpenMat: \(openMat)")

        do {
            print("🔥 Saving AppDayOfWeek to Firestore...")
            // The appDayOfWeekID is passed to `saveAppDayOfWeekToFirestore`, it should handle rehydration if necessary internally.
            try await viewModel.saveAppDayOfWeekToFirestore(
                selectedIslandID: selectedIsland.objectID, // Pass the ObjectID of selectedIsland
                selectedDay: selectedDay,
                appDayOfWeekObjectID: appDayOfWeekID // Use the correct argument label
            )

            // 2. Create and Save MatTime object - Rehydrate AppDayOfWeek on the background context
            print("💾 Creating MatTime object...")

            // This function creates/updates the MatTime in Core Data and returns its ObjectID
            let matTimeObjectID = try await viewModel.updateOrCreateMatTime(
                nil, // No existing MatTime ID (for creation), so passing nil for update
                time: time,
                type: matTimeType,
                gi: gi,
                noGi: noGi,
                openMat: openMat,
                restrictions: restrictions,
                restrictionDescription: restrictionDescription,
                goodForBeginners: goodForBeginners,
                kids: kids,
                for: appDayOfWeekID // Pass the ObjectID
            )

            print("✅ MatTime created successfully with ID: \(matTimeObjectID.uriRepresentation().absoluteString)")

            // 3. Save MatTime to Firestore
            print("💾 Saving MatTime to Firestore...")

            // Initialize variables to a default/empty state before the closure
            var matTimeDataToSave: [String: Any] = [:] // Initialize with empty dictionary
            var matTimeUUIDString: String = ""         // Initialize with empty string
            var appDayOfWeekUUIDString: String = ""    // Initialize with empty string
            var appDayOfWeekRef: DocumentReference! = nil // Initialize as nil or remove `!` and handle optional

            let contextForFirestore = PersistenceController.shared.container.newBackgroundContext()

            try await contextForFirestore.perform {
                guard let matTimeOnBGContext = try contextForFirestore.existingObject(with: matTimeObjectID) as? MatTime,
                      let matTimeID = matTimeOnBGContext.id, // Get the UUID directly
                      let appDayOfWeekOnBGContext = try contextForFirestore.existingObject(with: appDayOfWeekID) as? AppDayOfWeek,
                      let appDayOfWeekIDFromContext = appDayOfWeekOnBGContext.id // Get AppDayOfWeek UUID
                else {
                    throw NSError(domain: "FirestoreSerializationError", code: 202, userInfo: [NSLocalizedDescriptionKey: "Failed to rehydrate matTime or appDayOfWeek for Firestore serialization, or missing UUIDs."])
                }

                matTimeUUIDString = matTimeID.uuidString
                appDayOfWeekUUIDString = appDayOfWeekIDFromContext.uuidString

                // Construct the Firestore DocumentReference *synchronously* here
                appDayOfWeekRef = Firestore.firestore().collection("AppDayOfWeek").document(appDayOfWeekUUIDString)

                var data = matTimeOnBGContext.toFirestoreData()
                data["appDayOfWeek"] = appDayOfWeekRef // Attach the Firestore reference
                matTimeDataToSave = data
            }

            // NOW, perform the Firestore write (which is asynchronous) OUTSIDE the Core Data perform block.
            // Add checks for initialized variables if appDayOfWeekRef was nil
            guard !matTimeUUIDString.isEmpty, !matTimeDataToSave.isEmpty else {
                throw NSError(domain: "FirestoreError", code: 204, userInfo: [NSLocalizedDescriptionKey: "Firestore data not prepared."])
            }

            let matTimeRef = Firestore.firestore().collection("MatTime").document(matTimeUUIDString)
            do {
                try await matTimeRef.setData(matTimeDataToSave)
                print("✅ MatTime saved to Firestore: \(matTimeUUIDString)")
            } catch {
                print("❌ Error saving MatTime to Firestore: \(error.localizedDescription)")
                throw error // Re-throwing ensures the outer catch block handles it.
            }

            // 4. Return the new MatTime's ObjectID
            return matTimeObjectID

        } catch {
            print("❌ Error in saveMatTime: \(error.localizedDescription)")
            throw error
        }
    }


    
    func deleteMatTime(_ matTime: MatTime) {
        let context = PersistenceController.shared.container.viewContext
        
        // Delete from Core Data
        context.delete(matTime)
        
        do {
            try context.save()
            print("MatTime deleted locally.")
            
            // Delete from Firestore
            if let id = matTime.id?.uuidString {
                let docRef = Firestore.firestore().collection("MatTime").document(id)
                docRef.delete { error in
                    if let error = error {
                        alertTitle = "Error"
                        alertMessage = "Failed to delete mat time from Firestore: \(error.localizedDescription)"
                        showAlert = true
                    } else {
                        toastMessage = "Mat time deleted!"
                        showToast = true
                    }
                }
            }
            
            // Clear current editing matTime
            self.matTime = nil
            isMatTimeSet = false
            
            // This might trigger a refresh of the list of mat times
            // similar to what you have in handleAddNewMatTime.
            // If let currentSelectedDay = self.selectedDay { ... }
            if let currentSelectedDay = self.selectedDay {
                self.selectedDay = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.selectedDay = currentSelectedDay
                }
            }
            
        } catch {
            alertTitle = "Error"
            alertMessage = "Failed to delete mat time: \(error.localizedDescription)"
            showAlert = true
        }
    }
    
    func resetStateVariables() {
        selectedTime = Date().roundToNearestHour()
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
        matTime = nil // Reset the matTime being edited
    }
    
    // MARK: - updateMatTime (Adjusted to use NSManagedObjectID)
    // FIX 3: Change argument type to NSManagedObjectID
    func updateMatTime(_ matTimeObjectID: NSManagedObjectID) {
        Task {
            guard let appDayOfWeek = viewModel.selectedAppDayOfWeek else {
                print("❌ No selectedAppDayOfWeek found for update.")
                return
            }

            do {
                let updatedMatTimeObjectID = try await viewModel.updateOrCreateMatTime(
                    matTimeObjectID, // Existing MatTime's ObjectID passed for update
                    time: formatDateToString(selectedTime),
                    type: determineMatTimeType(),
                    gi: gi,
                    noGi: noGi,
                    openMat: openMat,
                    restrictions: restrictions,
                    restrictionDescription: restrictions ? restrictionDescriptionInput : "",
                    goodForBeginners: goodForBeginners,
                    kids: kids,
                    for: appDayOfWeek.objectID
                )

                // Initialize variables to a default/empty state before the closure
                var matTimeDataToSave: [String: Any] = [:]      // Initialize with empty dictionary
                var updatedMatTimeUUIDString: String = ""       // Initialize with empty string
                var appDayOfWeekUUIDStringForFirestore: String = "" // Initialize with empty string
                var appDayOfWeekRefForFirestore: DocumentReference! = nil // Initialize as nil or remove `!`

                let contextForFirestore = PersistenceController.shared.container.newBackgroundContext()

                try await contextForFirestore.perform {
                    guard let matTimeOnBGContext = try contextForFirestore.existingObject(with: updatedMatTimeObjectID) as? MatTime,
                          let matTimeID = matTimeOnBGContext.id,
                          let appDayOfWeekOnBGContext = try contextForFirestore.existingObject(with: appDayOfWeek.objectID) as? AppDayOfWeek,
                          let appDayOfWeekIDFromContext = appDayOfWeekOnBGContext.id
                    else {
                        throw NSError(domain: "FirestoreSerializationError", code: 203, userInfo: [NSLocalizedDescriptionKey: "Failed to rehydrate matTime or appDayOfWeek for Firestore update."])
                    }

                    updatedMatTimeUUIDString = matTimeID.uuidString
                    appDayOfWeekUUIDStringForFirestore = appDayOfWeekIDFromContext.uuidString

                    appDayOfWeekRefForFirestore = Firestore.firestore().collection("AppDayOfWeek").document(appDayOfWeekUUIDStringForFirestore)

                    var data = matTimeOnBGContext.toFirestoreData()
                    data["appDayOfWeek"] = appDayOfWeekRefForFirestore
                    matTimeDataToSave = data
                }

                // Add checks for initialized variables before use
                guard !updatedMatTimeUUIDString.isEmpty, !matTimeDataToSave.isEmpty else {
                    throw NSError(domain: "FirestoreError", code: 205, userInfo: [NSLocalizedDescriptionKey: "Firestore update data not prepared."])
                }

                let matTimeRef = Firestore.firestore().collection("MatTime").document(updatedMatTimeUUIDString)
                try await matTimeRef.setData(matTimeDataToSave)
                print("✅ MatTime updated to Firestore: \(updatedMatTimeUUIDString)")

                await MainActor.run {
                    toastMessage = "Mat time updated!"
                    showToast = true
                    self.resetStateVariables()

                    if let currentSelectedDay = self.selectedDay {
                        self.selectedDay = nil
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            self.selectedDay = currentSelectedDay
                        }
                    }
                }

            } catch {
                await MainActor.run {
                    alertTitle = "Error"
                    alertMessage = "Failed to update mat time: \(error.localizedDescription)"
                    showAlert = true
                }
            }
        }
    }

    
    func populateFieldsFromMatTime(_ matTime: MatTime) {
        selectedTime = stringToDate(matTime.time ?? "") ?? Date().roundToNearestHour()
        gi = matTime.gi
        noGi = matTime.noGi
        openMat = matTime.openMat
        goodForBeginners = matTime.goodForBeginners
        kids = matTime.kids
        restrictions = matTime.restrictions
        restrictionDescriptionInput = matTime.restrictionDescription ?? ""
        isMatTimeSet = true
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
    
    func stringToDate(_ string: String) -> Date? {
        // You need to define how to convert a string back to a date.
        // This should match the format used in `formatDateToString`.
        let formatter = DateFormatter()
        formatter.timeStyle = .short // Assuming this is the format
        return formatter.date(from: string)
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
