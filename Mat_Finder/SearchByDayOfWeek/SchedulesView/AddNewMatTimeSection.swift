//
//  AddNewMatTimeSection.swift
//  Mat_Finder
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
                    .onChange(of: selectedTime) { oldValue, newValue in
                        isMatTimeSet = true
                        print("Selected time changed to: \(formatDateToString(newValue))")
                    }
                
                MatTypeTogglesView(
                    gi: $gi,
                    noGi: $noGi,
                    openMat: $openMat,
                    goodForBeginners: $goodForBeginners,
                    kids: $kids
                )
                
                RestrictionsView(
                    restrictions: $restrictions,
                    restrictionDescriptionInput: $restrictionDescriptionInput
                )
                
                if !daySelected {
                    Text("Select a Day to View or Add Daily Mat Times.")
                        .foregroundColor(.red)
                }
                
                Spacer()
                
                if let existingMatTime = matTime {
                    // ===== Update + Delete Buttons =====
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
                    // ===== Add New Mat Time Button =====
                    Button(action: addNewMatTime) {
                        Text("Add New Mat Time")
                            .padding()
                            .background(Color.blue) // Always blue
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    // No .disabled()
                }
            } // END VStack
            
            // MARK: - OnAppear
            .onAppear {
                if let existing = matTime {
                    populateFieldsFromMatTime(existing)
                }
            }
            
            // MARK: - onChange Fixes
            .onChange(of: selectedDay) { oldValue, newValue in
                handleSelectedDayChange()
            }
            .onChange(of: viewModel.selectedAppDayOfWeek) { oldValue, newValue in
                print("Selected AppDayOfWeek changed to: \(String(describing: newValue?.day))")
            }
        } // END ZStack
        
        // MARK: - Toast Modifier ON OUTER VIEW
        .showToast(
            isPresenting: $showToast,
            duration: 2.0,
            alignment: .top,
            verticalOffset: 0
        )
        
        // MARK: - Alert Modifier (REPLACED)
        .showAlert(
            isPresented: $showAlert,
            title: alertTitle,
            message: alertMessage
        )

    }
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    

    
    func handleSelectedDayChange() {
        guard let selectedDay = selectedDay else { return }
        
        daySelected = true
        print("Selected day changed to: \(selectedDay.displayName)")
        
        guard let selectedIsland = selectedIsland else { return }
        
        Task {
            await MainActor.run { isLoading = true }
            print("Fetching AppDayOfWeek for \(selectedIsland.islandName ?? "Unknown") on \(selectedDay.displayName)")
            
            let appDayOfWeek = await selectIslandAndDay(selectedIsland, selectedDay)
            
            await MainActor.run {
                isLoading = false // Set loading once at the end
                if let appDayOfWeek = appDayOfWeek {
                    viewModel.selectedAppDayOfWeek = appDayOfWeek
                } else {
                    alertTitle = "No Mat Times Found"
                    alertMessage = "No mat times have been entered for \(selectedDay.displayName)."
                    print("Failed to fetch or create AppDayOfWeek - No mat times entered for \(selectedDay.displayName).")
                    showAlert = true
                }
            }
        }
    }

    
    
    func addNewMatTime() {
        print("=== addNewMatTime called ===")
        print("Day selected: \(daySelected)")
        print("Is Mat Time Set: \(isMatTimeSet)")
        print("Selected AppDayOfWeek: \(viewModel.selectedAppDayOfWeek?.day ?? "None")")
        print("Selected Island: \(selectedIsland?.islandName ?? "None")")
        print("Selected Time: \(formatDateToString(selectedTime))")
        print("Mat Types - Gi: \(gi), NoGi: \(noGi), OpenMat: \(openMat)")
        print("Restrictions: \(restrictions), Description: \(restrictionDescriptionInput)")
        
        // Show alerts if validation fails
        guard validateInput() else {
            print("❌ Validation failed")
            return
        }
        
        guard let selectedIsland = selectedIsland, let selectedDay = selectedDay else {
            print("❌ Selected Island or Day is missing")
            alertTitle = "Error"
            alertMessage = "Selected Island or Day is missing."
            showAlert = true
            return
        }
        
        print("✅ Validation passed, starting async task")
        
        Task {
            isLoading = true
            print("⏳ Adding mat time for island: \(selectedIsland.islandName ?? "nil"), day: \(selectedDay.displayName)")
            
            await handleAddNewMatTime(selectedIsland: selectedIsland, selectedDay: selectedDay)
            
            isLoading = false
            print("✅ Finished addNewMatTime Task")
        }
    }


    @MainActor
    func handleAddNewMatTime(selectedIsland: PirateIsland, selectedDay: DayOfWeek) async {
        await MainActor.run { isLoading = true }

        do {
            let appDayOfWeekToUseID: NSManagedObjectID

            if let existingAppDayOfWeek = viewModel.selectedAppDayOfWeek {
                appDayOfWeekToUseID = existingAppDayOfWeek.objectID
            } else {
                let selectedIslandID = selectedIsland.objectID
                let backgroundContext = PersistenceController.shared.container.newBackgroundContext()
                backgroundContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

                // Capture safe strings before entering performAndWait
                let islandNameSafe = selectedIsland.islandName ?? "UnknownIsland"
                let dayNameSafe = selectedDay.rawValue // or selectedDay.displayName

                // Perform only synchronous background work here
                appDayOfWeekToUseID = try backgroundContext.performAndWait {
                    guard let islandOnBG = try? backgroundContext.existingObject(with: selectedIslandID) as? PirateIsland else {
                        throw NSError(
                            domain: "CoreDataError",
                            code: 202,
                            userInfo: [NSLocalizedDescriptionKey: "Failed to rehydrate selectedIsland in background context."]
                        )
                    }

                    let newAppDayOfWeek = AppDayOfWeek(context: backgroundContext)
                    
                    // Keep UUID for Core Data identity
                    newAppDayOfWeek.id = UUID()
                    
                    // 🔹 Use captured safe strings instead of Core Data object
                    let humanReadableID = "\(islandNameSafe)-\(dayNameSafe)"
                    newAppDayOfWeek.appDayOfWeekID = humanReadableID
                    
                    newAppDayOfWeek.day = dayNameSafe
                    newAppDayOfWeek.name = humanReadableID
                    newAppDayOfWeek.pIsland = islandOnBG
                    newAppDayOfWeek.createdTimestamp = Date()

                    try backgroundContext.save()
                    return newAppDayOfWeek.objectID
                }

                // Merge changes into main context after background save
                await MainActor.run {
                    viewContext.performAndWait {
                        do {
                            try viewContext.save()
                        } catch {
                            print("Error saving main context after background save: \(error)")
                        }
                    }
                }
            }

            _ = try await saveMatTime(appDayOfWeekID: appDayOfWeekToUseID)

            // ✅ All SwiftUI updates explicitly on MainActor
            await MainActor.run {
                if let appDayOfWeekOnMain = try? viewContext.existingObject(with: appDayOfWeekToUseID) as? AppDayOfWeek {
                    viewModel.selectedAppDayOfWeek = appDayOfWeekOnMain
                    viewModel.currentAppDayOfWeek = appDayOfWeekOnMain
                }

                alertTitle = "Success"
                alertMessage = "New mat time added successfully!"
                showAlert = true
                toastMessage = "Mat time added!"
                showToast = true
                resetStateVariables()
            }

        } catch {
            await MainActor.run {
                alertTitle = "Error"
                alertMessage = "Failed to create or save mat time: \(error.localizedDescription)"
                showAlert = true
            }
        }

        await MainActor.run { isLoading = false }
    }

    func validateInput() -> Bool {
        if !daySelected {
            presentAlert(
                title: "Error",
                message: "Please select a day."
            )
            return false
        }

        if !isMatTimeSet {
            presentAlert(
                title: "Error",
                message: "Please select a time."
            )
            return false
        }

        if !(gi || noGi || openMat) {
            presentAlert(
                title: "Error",
                message: "Please select at least one mat time type."
            )
            return false
        }

        return true
    }

    func presentAlert(title: String, message: String) {
        DispatchQueue.main.async {
            self.alertTitle = title
            self.alertMessage = message
            self.showAlert = true
        }
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
            var _: String = ""    // Initialize with empty string
            var appDayOfWeekRef: DocumentReference! = nil // Initialize as nil or remove `!` and handle optional

            let contextForFirestore = PersistenceController.shared.container.newBackgroundContext()

            try await contextForFirestore.perform {
                guard let matTimeOnBGContext = try contextForFirestore.existingObject(with: matTimeObjectID) as? MatTime,
                      let matTimeID = matTimeOnBGContext.id,
                      let appDayOfWeekOnBGContext = try contextForFirestore.existingObject(with: appDayOfWeekID) as? AppDayOfWeek,
                      let appDayOfWeekIDFromContext = appDayOfWeekOnBGContext.appDayOfWeekID // <-- Use string ID
                else {
                    throw NSError(domain: "FirestoreSerializationError", code: 202,
                                  userInfo: [NSLocalizedDescriptionKey: "Failed to rehydrate matTime or appDayOfWeek for Firestore serialization."])
                }

                matTimeUUIDString = matTimeID.uuidString
                let appDayOfWeekHumanID = appDayOfWeekIDFromContext // <-- Human-readable ID

                // Use the human-readable string for Firestore reference
                appDayOfWeekRef = Firestore.firestore()
                    .collection("AppDayOfWeek")
                    .document(appDayOfWeekHumanID)

                var data = matTimeOnBGContext.toFirestoreData()
                data["appDayOfWeek"] = appDayOfWeekRef // Attach Firestore reference
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
    func updateMatTime(_ matTimeObjectID: NSManagedObjectID) {
        Task {
            guard let appDayOfWeek = viewModel.selectedAppDayOfWeek else {
                print("❌ No selectedAppDayOfWeek found for update.")
                return
            }

            do {
                // Capture the objectID early (safe to share across threads)
                let appDayOfWeekObjectID = appDayOfWeek.objectID

                // Step 1: Update or create in Core Data
                let updatedMatTimeObjectID = try await viewModel.updateOrCreateMatTime(
                    matTimeObjectID,
                    time: formatDateToString(selectedTime),
                    type: determineMatTimeType(),
                    gi: gi,
                    noGi: noGi,
                    openMat: openMat,
                    restrictions: restrictions,
                    restrictionDescription: restrictions ? restrictionDescriptionInput : "",
                    goodForBeginners: goodForBeginners,
                    kids: kids,
                    for: appDayOfWeekObjectID
                )

                // Step 2: Initialize variables
                var matTimeDataToSave: [String: Any] = [:]
                var updatedMatTimeUUIDString: String = ""
                var appDayOfWeekUUIDStringForFirestore: String = ""
                var appDayOfWeekRefForFirestore: DocumentReference?

                // Step 3: Use background context safely
                let contextForFirestore = PersistenceController.shared.container.newBackgroundContext()

                try await contextForFirestore.perform {
                    guard
                        let matTimeOnBGContext = try contextForFirestore.existingObject(with: updatedMatTimeObjectID) as? MatTime,
                        let matTimeID = matTimeOnBGContext.id,
                        let appDayOfWeekOnBGContext = try contextForFirestore.existingObject(with: appDayOfWeekObjectID) as? AppDayOfWeek,
                        let appDayOfWeekIDFromContext = appDayOfWeekOnBGContext.id
                    else {
                        throw NSError(
                            domain: "FirestoreSerializationError",
                            code: 203,
                            userInfo: [NSLocalizedDescriptionKey: "Failed to rehydrate matTime or appDayOfWeek for Firestore update."]
                        )
                    }

                    updatedMatTimeUUIDString = matTimeID.uuidString
                    appDayOfWeekUUIDStringForFirestore = appDayOfWeekIDFromContext.uuidString

                    appDayOfWeekRefForFirestore = Firestore.firestore()
                        .collection("AppDayOfWeek")
                        .document(appDayOfWeekUUIDStringForFirestore)

                    var data = matTimeOnBGContext.toFirestoreData()
                    data["appDayOfWeek"] = appDayOfWeekRefForFirestore
                    matTimeDataToSave = data
                }

                // Step 4: Sanity check
                guard !updatedMatTimeUUIDString.isEmpty, !matTimeDataToSave.isEmpty else {
                    throw NSError(
                        domain: "FirestoreError",
                        code: 205,
                        userInfo: [NSLocalizedDescriptionKey: "Firestore update data not prepared."]
                    )
                }

                // Step 5: Upload to Firestore
                let matTimeRef = Firestore.firestore().collection("MatTime").document(updatedMatTimeUUIDString)
                try await matTimeRef.setData(matTimeDataToSave)
                print("✅ MatTime updated to Firestore: \(updatedMatTimeUUIDString)")

                // Step 6: UI feedback
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
