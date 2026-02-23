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
  

enum ClassType: String, CaseIterable, Identifiable {

    case gi = "Gi"
    case noGi = "No Gi"
    case openMat = "Open Mat"

    var id: String { rawValue }
}


struct AddNewMatTimeSection2: View {
    

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


    // MARK: - Restrictions

    @State private var restrictions = false
    @State private var restrictionText = ""

    @State private var classType: ClassType = .gi


    // MARK: - Loading

    @State private var isSaving = false

    // MARK: UI
    var body: some View {

        Group {

            Section("CLASS TYPE") {
                classTypeSection
            }

            Section {
                kidsSection
            }

            Section("DAYS") {
                daysSection
            }

            Section("TIMES") {
                timesSection
            }

            Section("OPTIONS") {
                optionsSection
            }

            Section {
                addButton
            }

        }

        .scrollContentBackground(.hidden)
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Add Schedule")
        .navigationBarTitleDisplayMode(.inline)
        .showAlert(
            isPresented: $showAlert,
            title: alertTitle,
            message: alertMessage
        )

    }

}


// MARK: - Sections

extension AddNewMatTimeSection2 {

    var classTypeSection: some View {

        Picker("", selection: $classType) {

            ForEach(ClassType.allCases) { type in

                Text(type.rawValue)
                    .tag(type)

            }

        }
        .pickerStyle(.segmented)
        .animation(.easeInOut, value: classType)
    }


    var kidsSection: some View {

        Toggle("Kids Class", isOn: $kidsClass)

    }

    var daysSection: some View {

        AppleStyleDaySelector(
            selectedDays: $selectedDays
        )
        .listRowInsets(EdgeInsets()) // ✅ removes Form padding
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
                        .font(.body)
                        .fontWeight(.medium)
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


    var optionsSection: some View {

        VStack(spacing: 12) {

            Toggle(
                "Good for Beginners",
                isOn: $goodForBeginners
            )

            Toggle(
                "Restrictions",
                isOn: $restrictions
            )

            if restrictions {

                TextField(
                    "Description",
                    text: $restrictionText
                )
                .textFieldStyle(.roundedBorder)

            }

        }

    }


    var addButton: some View {

        Button {

            // ✅ HAPTIC FEEDBACK
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
        }
        .disabled(isSaving)
        .animation(.spring(response: 0.3), value: isSaving)
        .listRowBackground(Color.clear)
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

        if restrictions && restrictionText.isEmpty {

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

            Skipped duplicates: \(skippedCount)
            """

            showAlert = true

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
        let islandNameSafe = island.islandName ?? ""

        let context =
            PersistenceController.shared.container.newBackgroundContext()

        return try await context.perform {

            let islandBG =
                try context.existingObject(
                    with: islandObjectID
                ) as! PirateIsland


            // ✅ LOOK FOR EXISTING
            let fetch: NSFetchRequest<AppDayOfWeek> =
                AppDayOfWeek.fetchRequest()

            fetch.fetchLimit = 1

            fetch.predicate = NSPredicate(
                format: "pIsland == %@ AND day == %@",
                islandBG,
                day.rawValue
            )

            if let existing = try context.fetch(fetch).first {

                return existing.objectID
            }


            // ✅ CREATE NEW DAY
            let new = AppDayOfWeek(context: context)

            new.id = UUID()

            new.day = day.rawValue

            new.appDayOfWeekID =
                "\(islandNameSafe)-\(day.rawValue)"

            new.pIsland = islandBG

            try context.save()

            return new.objectID

        }

    }

    func createMatTimeSafe(
        appDayID: NSManagedObjectID,
        time: Date
    ) async throws -> Bool {

        let timeString =
            AppDateFormatter.twentyFourHour.string(from: time)

        let context =
            PersistenceController.shared.container.newBackgroundContext()


        // ✅ CHECK DUPLICATE

        let exists: Bool =
            try await context.perform {

                let fetch: NSFetchRequest<MatTime> =
                    MatTime.fetchRequest()

                fetch.fetchLimit = 1

                fetch.predicate =
                    NSPredicate(
                        format:
                        "appDayOfWeek == %@ AND time == %@",
                        context.object(with: appDayID),
                        timeString
                    )

                return try context.fetch(fetch).first != nil
            }


        // ❌ SKIP

        if exists {
            return false
        }


        // ✅ CREATE

        let type = classType.rawValue

        let matTimeID =
        try await viewModel.updateOrCreateMatTime(

            nil,

            time: timeString,

            type: type,

            gi: classType == .gi,

            noGi: classType == .noGi,

            openMat: classType == .openMat,

            restrictions: restrictions,

            restrictionDescription:
                restrictions ? restrictionText : "",

            goodForBeginners: goodForBeginners,

            kids: kidsClass,

            for: appDayID
        )

        try await saveMatTimeToFirestore(
            matTimeID: matTimeID,
            appDayID: appDayID
        )


        return true
    }
}


// MARK: - Firestore

extension AddNewMatTimeSection2 {

    func saveMatTimeToFirestore(
        matTimeID: NSManagedObjectID,
        appDayID: NSManagedObjectID
    ) async throws {

        let context =
        PersistenceController.shared.container.newBackgroundContext()

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in

            context.perform {

                do {

                    let mat =
                    try context.existingObject(with: matTimeID) as! MatTime

                    let app =
                    try context.existingObject(with: appDayID) as! AppDayOfWeek

                    let id = mat.id!.uuidString

                    var data = mat.toFirestoreData()

                    data["appDayOfWeek"] =
                    Firestore.firestore()
                        .collection("AppDayOfWeek")
                        .document(app.appDayOfWeekID!)

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

        classType = .gi

        kidsClass = false

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
