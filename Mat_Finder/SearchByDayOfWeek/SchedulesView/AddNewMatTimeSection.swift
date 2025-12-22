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
//    @Binding var daySelected: Bool
    @State var matTime: MatTime?
    @State private var isMatTimeSet: Bool = false
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

    
    @Binding var showAlert: Bool
    @Binding var alertTitle: String
    @Binding var alertMessage: String
    
    
    // FIX 1: Add @Environment for viewContext
    @Environment(\.managedObjectContext) private var viewContext
    
    // Ensure AppDayOfWeekRepository is accessible in your view.
    @ObservedObject var appDayOfWeekRepository = AppDayOfWeekRepository.shared
    @StateObject var userProfileViewModel = UserProfileViewModel()
    let selectIslandAndDay: (PirateIsland, DayOfWeek) async -> AppDayOfWeek?
    
    
    // MARK: - Custom initializer
    init(
        selectedIsland: Binding<PirateIsland?>,
        selectedDay: Binding<DayOfWeek?>,
        viewModel: AppDayOfWeekViewModel,
        selectIslandAndDay: @escaping (PirateIsland, DayOfWeek) async -> AppDayOfWeek?,
        showAlert: Binding<Bool>,
        alertTitle: Binding<String>,
        alertMessage: Binding<String>
    ) {
        self._selectedIsland = selectedIsland
        self._selectedDay = selectedDay
        self.viewModel = viewModel
        self.selectIslandAndDay = selectIslandAndDay
        self._showAlert = showAlert
        self._alertTitle = alertTitle
        self._alertMessage = alertMessage
    }
    
    var isDaySelected: Bool {
        selectedDay != nil
    }
    
    var isMatTypeSelected: Bool {
        gi || noGi || openMat
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
                
                if selectedDay == nil {
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
        
        // MARK: - Alert Modifier (REPLACED)
        .showAlert(
            isPresented: $showAlert,
            title: alertTitle,
            message: alertMessage
        )
        .onReceive(NotificationCenter.default.publisher(for: .addNewMatTimeTapped)) { _ in
            addNewMatTime()
        }

    }
    

    
    func handleSelectedDayChange() {
        guard let selectedDay = selectedDay else { return }
        
        //daySelected = true
        print("Selected day changed to: \(selectedDay.displayName)")
        
        guard let selectedIsland = selectedIsland else { return }
        
        Task {
            isLoading = true
            defer { isLoading = false }

            let appDayOfWeek = await selectIslandAndDay(selectedIsland, selectedDay)

            if let appDayOfWeek {
                await MainActor.run {
                    viewModel.selectedAppDayOfWeek = appDayOfWeek
                }
            } /*else {
                await MainActor.run {
                    presentAlert(
                        title: "No Mat Times Found",
                        message: "No mat times have been entered for \(selectedDay.displayName)."
                    )
                }
            }
               */
        }

    }

    func addNewMatTime() {
        print("=== addNewMatTime called ===")

        guard validateInput() else {
            print("❌ Validation failed")
            return
        }

        guard let selectedIsland,
              let selectedDay else {
            presentAlert(
                title: "Error",
                message: "Selected Island or Day is missing."
            )
            return
        }

        Task {
            await handleAddNewMatTime(
                selectedIsland: selectedIsland,
                selectedDay: selectedDay
            )
        }
    }



    @MainActor
    func handleAddNewMatTime(
        selectedIsland: PirateIsland,
        selectedDay: DayOfWeek
    ) async {
        isLoading = true
        defer { isLoading = false }   // ✅ guarantees cleanup

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

                // Perform only synchronous background Core Data work here
                appDayOfWeekToUseID = try backgroundContext.performAndWait {
                    guard let islandOnBG = try? backgroundContext.existingObject(
                        with: selectedIslandID
                    ) as? PirateIsland else {
                        throw NSError(
                            domain: "CoreDataError",
                            code: 202,
                            userInfo: [
                                NSLocalizedDescriptionKey:
                                    "Failed to rehydrate selectedIsland in background context."
                            ]
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

                // ✅ Already on MainActor — no MainActor.run needed
                viewContext.performAndWait {
                    do {
                        try viewContext.save()
                    } catch {
                        print("Error saving main context after background save: \(error)")
                    }
                }
            }

            _ = try await saveMatTime(appDayOfWeekID: appDayOfWeekToUseID)

            if let appDayOfWeekOnMain = try? viewContext.existingObject(
                with: appDayOfWeekToUseID
            ) as? AppDayOfWeek {
                viewModel.selectedAppDayOfWeek = appDayOfWeekOnMain
                viewModel.currentAppDayOfWeek = appDayOfWeekOnMain
            }

            presentAlert(
                title: "Success",
                message: "New mat time added successfully!"
            )
            resetStateVariables()

        } catch {
            presentAlert(
                title: "Error",
                message: "Failed to create or save mat time: \(error.localizedDescription)"
            )
        }
    }


    func validateInput() -> Bool {

        guard selectedDay != nil else {
            presentAlert(
                title: "Error",
                message: "Please select a day."
            )
            return false
        }

        guard isMatTimeSet else {
            presentAlert(
                title: "Error",
                message: "Please select a time."
            )
            return false
        }

        guard gi || noGi || openMat else {
            presentAlert(
                title: "Error",
                message: "Please select at least one mat time type."
            )
            return false
        }

        // ✅ NEW RULE: Restrictions require description
        if restrictions {
            let trimmed = restrictionDescriptionInput.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                presentAlert(
                    title: "Missing Restriction Details",
                    message: "Please Describe Restrictions."
                )
                return false
            }
        }

        return true
    }



    @MainActor
    func presentAlert(title: String, message: String) {
        alertTitle = title
        alertMessage = message
        showAlert = true
    }



    // MARK: - saveMatTime (Adjusted to use NSManagedObjectID and human-readable Firestore ID)
    @MainActor
    func saveMatTime(appDayOfWeekID: NSManagedObjectID) async throws -> NSManagedObjectID {
        print("💾 Starting saveMatTime(appDayOfWeekID:)")

        guard let selectedIsland = self.selectedIsland,
              let selectedDay = self.selectedDay else {
            print("❌ Missing necessary information: Island or Day is nil")
            throw NSError(domain: "AddNewMatTimeSectionError", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Selected Island or Day is missing."])
        }

        let time = formatDateToString(selectedTime)
        let matTimeType = determineMatTimeType()
        let restrictionDescription = restrictions ? restrictionDescriptionInput : ""

        print("Time: \(time)")
        print("MatType: \(matTimeType)")
        print("RestrictionDescription: \(restrictionDescription)")
        print("Gi: \(gi), NoGi: \(noGi), OpenMat: \(openMat)")

        do {
            // 1️⃣ Ensure AppDayOfWeek exists in Firestore
            try await viewModel.saveAppDayOfWeekToFirestore(
                selectedIslandID: selectedIsland.objectID,
                selectedDay: selectedDay,
                appDayOfWeekObjectID: appDayOfWeekID
            )

            // 2️⃣ Create or Update MatTime in Core Data
            let matTimeObjectID = try await viewModel.updateOrCreateMatTime(
                nil, // nil = new MatTime
                time: time,
                type: matTimeType,
                gi: gi,
                noGi: noGi,
                openMat: openMat,
                restrictions: restrictions,
                restrictionDescription: restrictionDescription,
                goodForBeginners: goodForBeginners,
                kids: kids,
                for: appDayOfWeekID
            )

            print("✅ MatTime created successfully with ID: \(matTimeObjectID.uriRepresentation().absoluteString)")

            // 3️⃣ Prepare Firestore data using background context
            var matTimeDataToSave: [String: Any] = [:]
            var matTimeUUIDString: String = ""
            var appDayOfWeekRefForFirestore: DocumentReference?

            let contextForFirestore = PersistenceController.shared.container.newBackgroundContext()

            try await contextForFirestore.perform {
                guard
                    let matTimeOnBGContext = try contextForFirestore.existingObject(with: matTimeObjectID) as? MatTime,
                    let matTimeID = matTimeOnBGContext.id,
                    let appDayOfWeekOnBGContext = try contextForFirestore.existingObject(with: appDayOfWeekID) as? AppDayOfWeek,
                    let appDayOfWeekHumanID = appDayOfWeekOnBGContext.appDayOfWeekID
                else {
                    throw NSError(domain: "FirestoreSerializationError", code: 202,
                                  userInfo: [NSLocalizedDescriptionKey: "Failed to rehydrate MatTime or AppDayOfWeek for Firestore serialization."])
                }

                matTimeUUIDString = matTimeID.uuidString

                // Human-readable Firestore reference
                appDayOfWeekRefForFirestore = Firestore.firestore()
                    .collection("AppDayOfWeek")
                    .document(appDayOfWeekHumanID)

                var data = matTimeOnBGContext.toFirestoreData()
                data["appDayOfWeek"] = appDayOfWeekRefForFirestore
                matTimeDataToSave = data
            }

            // 4️⃣ Sanity check
            guard !matTimeUUIDString.isEmpty, !matTimeDataToSave.isEmpty else {
                throw NSError(domain: "FirestoreError", code: 204,
                              userInfo: [NSLocalizedDescriptionKey: "Firestore data not prepared."])
            }

            // 5️⃣ Upload MatTime to Firestore
            let matTimeRef = Firestore.firestore().collection("MatTime").document(matTimeUUIDString)
            do {
                try await matTimeRef.setData(matTimeDataToSave)
                print("✅ MatTime saved to Firestore: \(matTimeUUIDString)")
            } catch {
                print("❌ Error saving MatTime to Firestore: \(error.localizedDescription)")
                throw error
            }

            // 6️⃣ Return the MatTime ObjectID
            return matTimeObjectID

        } catch {
            print("❌ Error in saveMatTime: \(error.localizedDescription)")
            throw error
        }
    }


    func deleteMatTime(_ matTime: MatTime) {
        let context = PersistenceController.shared.container.viewContext

        // ✅ Capture Firestore ID FIRST
        let firestoreID = matTime.id?.uuidString

        // Delete from Core Data
        context.delete(matTime)

        do {
            try context.save()
            print("MatTime deleted locally.")

            // Delete from Firestore
            if let firestoreID {
                Firestore.firestore()
                    .collection("MatTime")
                    .document(firestoreID)
                    .delete { error in
                        DispatchQueue.main.async {
                            if let error {
                                presentAlert(
                                    title: "Error",
                                    message: "Failed to delete mat time from Firestore: \(error.localizedDescription)"
                                )
                            } else {
                                presentAlert(
                                    title: "Deleted",
                                    message: "Mat time was deleted successfully."
                                )
                            }
                        }
                    }
            }

            // Reset UI state
            self.matTime = nil
            isMatTimeSet = false

        } catch {
            presentAlert(
                title: "Error",
                message: "Failed to delete mat time: \(error.localizedDescription)"
            )
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
        //daySelected = false
        matTime = nil // Reset the matTime being edited
    }
    
    // MARK: - updateMatTime (Adjusted to use NSManagedObjectID and human-readable Firestore ID)
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

                // Step 2: Initialize variables for Firestore upload
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
                        let appDayOfWeekHumanID = appDayOfWeekOnBGContext.appDayOfWeekID
                    else {
                        throw NSError(
                            domain: "FirestoreSerializationError",
                            code: 203,
                            userInfo: [NSLocalizedDescriptionKey: "Failed to rehydrate matTime or appDayOfWeek for Firestore update."]
                        )
                    }

                    // Use UUID for MatTime and human-readable ID for AppDayOfWeek
                    updatedMatTimeUUIDString = matTimeID.uuidString
                    appDayOfWeekUUIDStringForFirestore = appDayOfWeekHumanID

                    appDayOfWeekRefForFirestore = Firestore.firestore()
                        .collection("AppDayOfWeek")
                        .document(appDayOfWeekUUIDStringForFirestore)

                    var data = matTimeOnBGContext.toFirestoreData()
                    data["appDayOfWeek"] = appDayOfWeekRefForFirestore
                    matTimeDataToSave = data
                }

                // Step 4: Sanity check before uploading
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
                    presentAlert(
                        title: "Updated",
                        message: "Mat time updated successfully."
                    )

                    self.resetStateVariables()

                    // Refresh selected day to reload mat times
                    if let currentSelectedDay = self.selectedDay {
                        self.selectedDay = nil
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            self.selectedDay = currentSelectedDay
                        }
                    }
                }

            } catch {
                await MainActor.run {
                    
                    presentAlert(
                        title: "Error",
                        message: "Failed to update mat time: \(error.localizedDescription)."
                    )
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
        AppDateFormatter.twentyFourHour.string(from: date)
    }

    
    func stringToDate(_ string: String) -> Date? {
        AppDateFormatter.twentyFourHour.date(from: string)
            ?? AppDateFormatter.twelveHour.date(from: string)
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
