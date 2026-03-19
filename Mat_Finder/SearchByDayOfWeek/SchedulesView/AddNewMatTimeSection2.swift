//
//  AddNewMatTimeSection2.swift
//  Mat_Finder
//
//  Created by Brian Romero on 2/22/26.
//

 

import Foundation
import SwiftUI
import CoreData
import FirebaseFirestore
  

struct AddNewMatTimeSection2: View {
    
    @Environment(\.dismiss) private var dismiss
    // MARK: - Inputs

    @Binding var selectedIslandID: String?
    let islands: [PirateIsland]

    var selectedIsland: PirateIsland? {
        islands.first { $0.islandID == selectedIslandID }
    }

    @ObservedObject var viewModel: AppDayOfWeekViewModel

    @Binding var showAlert: Bool
    @Binding var alertTitle: String
    @Binding var alertMessage: String

    let selectIslandAndDay: (PirateIsland, DayOfWeek) async -> AppDayOfWeek?

    @Environment(\.managedObjectContext)
    private var viewContext


    // MARK: - NEW MULTI SELECT STATE

    @State private var selectedDays: Set<DayOfWeek> = []

    @State private var selectedTimes: [Date] = []

    @State private var tempTime: Date = Date().roundToNearestHour()


    // MARK: - Class Type

    @State private var kidsClass = false
    @State private var goodForBeginners = false
    @State private var womensOnly = false   // ✅ NEW

    // MARK: - Restrictions

    @State private var restrictions = false
    @State private var restrictionText = ""
    
    @State private var discipline: Discipline = .bjjGi
    @State private var style: Style? = nil
    @State private var customStyle: String = ""

    // MARK: - Loading

    @State private var isSaving = false

    // MARK: UI
    var body: some View {

        Form {
            
            Section("DISCIPLINE") {
                DisciplinePicker(discipline: $discipline)
                
                StylePicker(
                    style: $style,
                    discipline: $discipline,
                    customStyle: $customStyle
                )
            }
 
  

            Section("DAYS") {
                daysSection
                    .listRowInsets(EdgeInsets())
            }

            Section("TIMES - add one or multiple") {
                timesSection
            }

            Section("OPTIONS") {
                Toggle("Kids Class", isOn: $kidsClass)
                Toggle("Good for Beginners", isOn: $goodForBeginners)
                Toggle("Women’s Class", isOn: $womensOnly)
            }

            Section("RESTRICTIONS") {

                RestrictionsView(
                    restrictions: $restrictions,
                    restrictionDescriptionInput: $restrictionText
                )
                .listRowInsets(EdgeInsets())

            }

            Color.clear
                .frame(height: 80)
                .listRowBackground(Color.clear)

        }
        .formStyle(GroupedFormStyle())
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) {
            addButtonFooter
        }
        .navigationTitle("Add Schedule")
        .navigationBarTitleDisplayMode(.inline)
        .showAlert(
            isPresented: $showAlert,
            title: alertTitle,
            message: alertMessage
        )

        .onChange(of: discipline) { _, newValue in
            if newValue == .openMat {
                style = nil
                customStyle = ""
            }
        }

        .onChange(of: style) { _, newStyle in
            if newStyle != .custom {
                customStyle = ""
            }
        }

    }

}


// MARK: - Sections

extension AddNewMatTimeSection2 {

 


    var daysSection: some View {

        AppleStyleDaySelector(
            selectedDays: $selectedDays
        )
        .padding(.vertical, 4)

    }

    var timesSection: some View {

        VStack(spacing: 12) {

            HStack {

                DatePicker(
                    "Time",
                    selection: $tempTime,
                    displayedComponents: .hourAndMinute
                )
                .labelsHidden()

                Spacer()

                Button {

                    addTime()

                } label: {

                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(.accentColor)

                }
            }

            ForEach(selectedTimes, id: \.self) { time in

                HStack {

                    Text(time.toTimeString())
                        .font(.system(size: 17, weight: .medium))
                    Spacer()

                    Button {

                        removeTime(time)

                    } label: {

                        Image(systemName: "minus.circle.fill")
                            .foregroundColor(.red)

                    }
                    .buttonStyle(.plain)

                }

            }

        }
        .padding(.vertical, 4)

    
    }
    
    var addButton: some View {

        Button {

            UIImpactFeedbackGenerator(style: .medium)
                .impactOccurred()

            addMatTimesBatch()

        } label: {

            HStack {

                Spacer()

                if isSaving {

                    ProgressView()

                } else {

                    Text("Add Schedule")
                        .fontWeight(.semibold)

                }

                Spacer()

            }
            .padding()
            .background(
                isSaving
                ? Color.gray.opacity(0.4)
                : Color.accentColor
            )
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            // ✅ Bonus Enhancement Applied
            .opacity(isSaving ? 0.6 : 1.0)
            .scaleEffect(isSaving ? 0.98 : 1)
            .animation(.easeInOut, value: isSaving)

        }
        .disabled(isSaving)

    }
    
    var addButtonFooter: some View {

        addButton
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 12)
            .background(
                Color(.systemBackground)
                    .opacity(0.95)
                    .shadow(color: .black.opacity(0.08), radius: 8, y: -2)
            )

    }
 
}

// MARK: - Actions

extension AddNewMatTimeSection2 {


    func toggleDay(_ day: DayOfWeek) {

        if selectedDays.contains(day) {

            selectedDays.remove(day)

        } else {

            selectedDays.insert(day)

        }

    }


    func addTime() {

        guard !selectedTimes.contains(tempTime) else { return }

        // ✅ HAPTIC
        UIImpactFeedbackGenerator(style: .light)
            .impactOccurred()

        selectedTimes.append(tempTime)

        // ✅ AUTO SORT
        selectedTimes.sort()
    }

    func removeTime(_ time: Date) {

        UIImpactFeedbackGenerator(style: .light)
            .impactOccurred()

        selectedTimes.removeAll { $0 == time }

    }
}


// MARK: - SAVE

extension AddNewMatTimeSection2 {


    func addMatTimesBatch() {

        guard validate() else { return }

        guard let island = selectedIsland else {

            alert("Error", "No island selected")

            return

        }

        Task {

            await saveBatch(island: island)

        }

    }

    func validate() -> Bool {

        if selectedDays.isEmpty {

            alert("Error", "Select days")
            return false
        }

        if selectedTimes.isEmpty {

            alert("Error", "Select times")
            return false
        }

        if restrictions && restrictionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            alert("Error", "Enter restriction description")
            return false
        }

        return true
    }
    
    
    @MainActor
    func saveBatch(island: PirateIsland) async {

        isSaving = true
        defer { isSaving = false }

        var addedCount = 0
        var skippedCount = 0

        do {

            for day in selectedDays {

                let appDayID =
                    try await getOrCreateAppDay(
                        island: island,
                        day: day
                    )

                for time in selectedTimes {

                    let wasAdded =
                        try await createMatTimeSafe(
                            appDayID: appDayID,
                            time: time
                        )

                    if wasAdded {
                        addedCount += 1
                    } else {
                        skippedCount += 1
                    }

                }
            }


            // ✅ CLEAN SUMMARY ALERT

            alertTitle =
            skippedCount == 0
            ? "Schedule Created"
            : "Schedule Updated"
            
            alertMessage =
            """
            Added: \(addedCount)

            Skipped duplicate entry: \(skippedCount)
            """

            showAlert = true
            dismiss()
            reset()

        }
        catch {

            alert(
                "Error",
                error.localizedDescription
            )

        }
    }
}

// MARK: - CoreData + Firestore

extension AddNewMatTimeSection2 {

    func getOrCreateAppDay(
        island: PirateIsland,
        day: DayOfWeek
    ) async throws -> NSManagedObjectID {

        let islandObjectID = island.objectID

        let islandNameSafe =
            (island.islandName ?? "")
                .replacingOccurrences(of: "/", with: "-")
                .replacingOccurrences(of: "\\", with: "-")
                .replacingOccurrences(of: "#", with: "")
                .replacingOccurrences(of: "?", with: "")

        let context =
            PersistenceController.shared
                .newBackgroundContext()

        // =====================================================
        // STEP 1: Create / Fetch Core Data record
        // =====================================================

        let objectID: NSManagedObjectID =
            try await context.perform {

                let islandBG =
                    try context.existingObject(
                        with: islandObjectID
                    ) as! PirateIsland

                let fetch: NSFetchRequest<AppDayOfWeek> =
                    AppDayOfWeek.fetchRequest()

                fetch.fetchLimit = 1

                fetch.predicate =
                    NSPredicate(
                        format: "pIsland == %@ AND day == %@",
                        islandBG,
                        day.rawValue
                    )

                // ✅ Return existing if found
                if let existing =
                    try context.fetch(fetch).first {

                    return existing.objectID
                }

                // =====================================================
                // CREATE NEW
                // =====================================================

                guard let islandID = islandBG.islandID else {
                    throw NSError(
                        domain: "AppDayOfWeek",
                        code: 0,
                        userInfo: [
                            NSLocalizedDescriptionKey:
                                "Missing islandID on PirateIsland"
                        ]
                    )
                }

                let new =
                    AppDayOfWeek(context: context)

                new.id = UUID()
                new.day = day.rawValue
                new.appDayOfWeekID = UUID().uuidString
                new.name = "\(islandNameSafe) - \(day.rawValue)"
                new.createdTimestamp = Date()

                // Relationship
                new.pIsland = islandBG

                // ✅ NEW — keep string ID in sync with relationship
                new.pirateIslandID = islandID

                try context.save()

                return new.objectID
            }

        // =====================================================
        // STEP 2: Save to Firestore OUTSIDE context
        // =====================================================

        try await saveAppDayToFirestore(objectID: objectID)

        return objectID
    }

    func createMatTimeSafe(
        appDayID: NSManagedObjectID,
        time: Date
    ) async throws -> Bool {

        let timeString =
            AppDateFormatter.twentyFourHour.string(from: time)

        let context =
            PersistenceController.shared.newBackgroundContext()

        // ✅ COMPUTE VALUES ONCE

        let disciplineValue = discipline.rawValue

        let styleValue: String?
        let customStyleValue: String?

        // ⭐ Enforce Open Mat rule
        if discipline == .openMat {

            styleValue = nil
            customStyleValue = nil

        } else if style == .custom {

            let trimmed = customStyle.trimmingCharacters(in: .whitespacesAndNewlines)

            if trimmed.isEmpty {
                styleValue = nil
                customStyleValue = nil
            } else {
                styleValue = trimmed
                customStyleValue = trimmed
            }

        } else if let selectedStyle = style {

            styleValue = selectedStyle.rawValue
            customStyleValue = nil

        } else {

            styleValue = nil
            customStyleValue = nil
        }

        // ✅ CHECK DUPLICATE
        let exists: Bool = try await context.perform {
            let fetch: NSFetchRequest<MatTime> = MatTime.fetchRequest()
            fetch.fetchLimit = 1

            let appDay = context.object(with: appDayID) as! AppDayOfWeek
            guard let appDayStringID = appDay.appDayOfWeekID else {
                return false
            }

            fetch.predicate = MatTimeDedupe.predicate(
                appDayID: appDayStringID,
                time: timeString,
                discipline: disciplineValue,
                style: styleValue,
                customStyle: customStyleValue,
                type: discipline.displayName,
                restrictionDescription: restrictions ? restrictionText : "",
                kids: kidsClass,
                womensOnly: womensOnly,
                goodForBeginners: goodForBeginners,
                restrictions: restrictions
            )

            return try context.fetch(fetch).first != nil
        }

        // ❌ SKIP

        if exists {
            return false
        }

        // ✅ CREATE

        let matTimeID =
        try await viewModel.updateOrCreateMatTime(

            nil,

            time: timeString,

            type: discipline.displayName,
            style: styleValue,
            customStyle: customStyleValue,

            discipline: disciplineValue,

            restrictions: restrictions,

            restrictionDescription:
                restrictions ? restrictionText : "",

            goodForBeginners: goodForBeginners,

            kids: kidsClass,
            womensOnly: womensOnly,

            for: appDayID
        )

        try await saveMatTimeToFirestore(
            matTimeID: matTimeID,
            appDayID: appDayID
        )

        return true
    }
    
    func saveAppDayToFirestore(
        objectID: NSManagedObjectID
    ) async throws {

        let context =
            PersistenceController.shared
                .newFirestoreContext()

        let result: (
            id: String,
            day: String,
            name: String,
            created: Date,
            islandID: String
        ) = try await context.perform {

            let app =
                try context.existingObject(
                    with: objectID
                ) as! AppDayOfWeek

            guard let id = app.appDayOfWeekID else {
                throw NSError(
                    domain: "AppDayOfWeek",
                    code: 0,
                    userInfo: [
                        NSLocalizedDescriptionKey:
                            "Missing AppDayOfWeek ID"
                    ]
                )
            }

            let islandID =
                app.pIsland?.islandID ??
                app.pirateIslandID

            guard let islandID, !islandID.isEmpty else {
                throw NSError(
                    domain: "AppDayOfWeek",
                    code: 0,
                    userInfo: [
                        NSLocalizedDescriptionKey:
                            "Missing PirateIsland ID"
                    ]
                )
            }

            return (
                id: id,
                day: app.day,
                name: app.name ?? "",
                created: app.createdTimestamp ?? Date(),
                islandID: islandID
            )
        }

        let data: [String: Any] = [
            "appDayOfWeekID": result.id,
            "day": result.day,
            "name": result.name,
            "createdTimestamp": Timestamp(date: result.created),
            "pirateIslandID": result.islandID,
            "pIsland": Firestore.firestore()
                .collection("pirateIslands")
                .document(result.islandID)
        ]

        try await Firestore
            .firestore()
            .collection("AppDayOfWeek")
            .document(result.id)
            .setData(data)
    }
}


// MARK: - Firestore

extension AddNewMatTimeSection2 {

    func saveMatTimeToFirestore(
        matTimeID: NSManagedObjectID,
        appDayID: NSManagedObjectID
    ) async throws {

        let context =
        PersistenceController.shared.newFirestoreContext()

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in

            context.perform {

                do {

                    let mat =
                    try context.existingObject(with: matTimeID) as! MatTime

                    let app =
                    try context.existingObject(with: appDayID) as! AppDayOfWeek

                    guard let id = mat.id?.uuidString else {
                        continuation.resume(
                            throwing: NSError(
                                domain: "MatTime",
                                code: 0,
                                userInfo: [NSLocalizedDescriptionKey: "Missing MatTime ID"]
                            )
                        )
                        return
                    }
                    
                    var data = mat.toFirestoreData()

                    guard let appDayOfWeekID = app.appDayOfWeekID else {
                        continuation.resume(
                            throwing: NSError(
                                domain: "MatTime",
                                code: 0,
                                userInfo: [NSLocalizedDescriptionKey: "Missing AppDayOfWeek ID"]
                            )
                        )
                        return
                    }

                    data["appDayOfWeek"] =
                    Firestore.firestore()
                        .collection("AppDayOfWeek")
                        .document(appDayOfWeekID)

                    data["appDayOfWeekID"] = appDayOfWeekID

                    Firestore.firestore()
                        .collection("MatTime")
                        .document(id)
                        .setData(data) { error in

                            if let error {

                                continuation.resume(throwing: error)

                            } else {

                                continuation.resume(returning: ())

                            }

                        }

                }

                catch {

                    continuation.resume(throwing: error)

                }

            }

        }

    }

}


// MARK: - Helpers

extension AddNewMatTimeSection2 {


    func alert(_ title: String, _ msg: String) {

        alertTitle = title

        alertMessage = msg

        showAlert = true

    }


    func reset() {

        selectedDays.removeAll()
        selectedTimes.removeAll()

        discipline = .bjjGi
        style = nil
        customStyle = ""

        kidsClass = false
        womensOnly = false
        goodForBeginners = false

        restrictions = false
        restrictionText = ""
    }

}


struct AppleStyleDaySelector: View {

    @Binding var selectedDays: Set<DayOfWeek>

    private let columns =
        Array(
            repeating: GridItem(.flexible(), spacing: 6),
            count: 7
        )

    var body: some View {

        LazyVGrid(
            columns: columns,
            spacing: 10
        ) {

            ForEach(
                DayOfWeek.allCases.sorted(),
                id: \.self
            ) { day in

                Button {

                    toggle(day)

                } label: {

                    ZStack {

                        Circle()
                            .fill(
                                selectedDays.contains(day)
                                ? Color.accentColor
                                : Color.clear
                            )

                        Text(day.ultraShortDisplayName)
                            .font(
                                .system(
                                    .footnote,
                                    weight: .semibold
                                )
                            )
                            .foregroundColor(
                                selectedDays.contains(day)
                                ? .white
                                : .primary
                            )

                    }
                    .frame(maxWidth: .infinity)
                    .aspectRatio(1, contentMode: .fit)

                    .contentShape(Circle())

                    .shadow(
                        color:
                            selectedDays.contains(day)
                            ? .black.opacity(0.15)
                            : .clear,
                        radius: 3,
                        y: 2
                    )

                    .scaleEffect(
                        selectedDays.contains(day)
                        ? 1.0
                        : 0.92
                    )

                    .animation(
                        .spring(
                            response: 0.25,
                            dampingFraction: 0.7
                        ),
                        value: selectedDays
                    )

                }
                .buttonStyle(.plain)

            }

        }
        .padding(.horizontal, 6) // ✅ Apple spacing
        .padding(.vertical, 6)
    }

    private func toggle(_ day: DayOfWeek) {

        UIImpactFeedbackGenerator(
            style: .light
        ).impactOccurred()

        if selectedDays.contains(day) {

            selectedDays.remove(day)

        } else {

            selectedDays.insert(day)

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
