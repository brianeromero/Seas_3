//
//  ScheduledMatTimesSection.swift
//  Mat_Finder
//
//  Created by Brian Romero on 8/26/24.
//

import Foundation
import SwiftUI
import CoreData
import FirebaseFirestore

struct ScheduledMatTimesSection: View {
    @Environment(\.managedObjectContext) private var context

    let island: PirateIsland
    let day: DayOfWeek
    @ObservedObject var viewModel: AppDayOfWeekViewModel
    @Binding var matTimesForDay: [DayOfWeek: [MatTime]]
    @Binding var selectedDay: DayOfWeek?
    @State private var matTimes: [MatTime] = []
    @State private var error: String?

    @State private var successMessage: String?
    @State private var showSuccessAlert: Bool = false
    @State private var showErrorAlert: Bool = false

    @State private var editingMatTime: MatTime?
    @State private var showEditModal = false

    private let fetchQueue = DispatchQueue(label: "fetch-queue")

    // MARK: - Body
    var body: some View {
        contentView
            .onAppear { fetchMatTimes(day: selectedDay ?? day) }
            .onChange(of: selectedDay) { _, newDay in
                fetchMatTimes(day: newDay ?? day)
            }
            .onChange(of: island) { _, _ in
                fetchMatTimes(day: selectedDay ?? day)
            }
            .alert(isPresented: $showSuccessAlert) {
                Alert(
                    title: Text("Success"),
                    message: Text(successMessage ?? "Update completed successfully."),
                    dismissButton: .default(Text("OK")) { successMessage = nil }
                )
            }
            .alert(isPresented: $showErrorAlert) {
                Alert(
                    title: Text("Error"),
                    message: Text(error ?? "Something went wrong."),
                    dismissButton: .default(Text("OK")) { error = nil }
                )
            }
            .sheet(isPresented: $showEditModal) {
                editSheetView
            }
    }

    // MARK: - Subviews
    private var contentView: some View {
        Group {
            if let errorMessage = error {
                Text("⚠️ \(errorMessage)")
                    .foregroundColor(.red)
            } else if !matTimes.isEmpty {
                matTimesListView
            } else {
                Text("No mat times have been entered for \(day.rawValue.capitalized) at \(island.islandName ?? "this gym").")
                    .foregroundColor(.secondary)
            }
        }
    }

    private var matTimesListView: some View {
        MatTimesList(
            day: day,
            matTimes: matTimes,
            onEdit: { matTime in showEditSheet(for: matTime) },
            onDelete: { matTime in deleteMatTime(matTime) }
        )
    }

    private var editSheetView: some View {
        Group {
            if let editingMatTime = editingMatTime {
                EditMatTimeView(matTime: editingMatTime, viewModel: viewModel)
            } else {
                EmptyView()
            }
        }
    }


    // MARK: - Helper Methods
    func showEditSheet(for matTime: MatTime) {
        editingMatTime = matTime
        showEditModal = true
    }

    func handleEdit(_ updatedMatTime: MatTime) async {
        do {
            try context.save()
            try await viewModel.updateMatTime(updatedMatTime)
            await MainActor.run {
                showEditModal = false
                successMessage = "Mat time updated!"
                showSuccessAlert = true
                fetchMatTimes(day: selectedDay ?? day)
            }
        } catch let saveError {
            await MainActor.run {
                error = "Failed to save changes: \(saveError.localizedDescription)"
                showErrorAlert = true
            }
        }
    }

    func fetchMatTimes(day: DayOfWeek) {
        Task {
            do {
                let fetchedMatTimes = try viewModel.fetchMatTimes(for: day)
                let filteredMatTimes = filterMatTimes(fetchedMatTimes, for: day, and: island)
                let sortedMatTimes = sortMatTimes(filteredMatTimes)

                await MainActor.run {
                    matTimes = sortedMatTimes
                    if let currentSelectedDay = selectedDay {
                        viewModel.matTimesForDay[currentSelectedDay] = sortedMatTimes
                    } else {
                        viewModel.matTimesForDay[day] = sortedMatTimes
                    }
                    error = nil
                }
            } catch let fetchError {
                await MainActor.run {
                    matTimes = []
                    error = fetchError.localizedDescription
                    showErrorAlert = true
                }
            }
        }
    }

    func filterMatTimes(_ matTimes: [MatTime], for day: DayOfWeek, and island: PirateIsland) -> [MatTime] {
        guard let islandUUID = island.islandID else { return [] }
        let normalized = islandUUID.uuidString.replacingOccurrences(of: "-", with: "")

        return matTimes.filter { matTime in
            guard let appDay = matTime.appDayOfWeek,
                  let pIsland = appDay.pIsland,
                  let pIslandUUID = pIsland.islandID
            else { return false }

            let pNorm = pIslandUUID.uuidString.replacingOccurrences(of: "-", with: "")
            let sameIsland = (normalized == pNorm)
            let sameDay = appDay.day.caseInsensitiveCompare(day.rawValue) == .orderedSame

            return sameIsland && sameDay
        }
    }

    func sortMatTimes(_ matTimes: [MatTime]) -> [MatTime] {
        matTimes.sorted { $0.time ?? "" < $1.time ?? "" }
    }

    func deleteMatTime(_ matTime: MatTime) {
        Task {
            do {
                try await viewModel.removeMatTime(matTime)
                await MainActor.run {
                    if let index = matTimes.firstIndex(where: { $0.objectID == matTime.objectID }) {
                        matTimes.remove(at: index)
                    }
                    if let currentSelectedDay = selectedDay {
                        viewModel.matTimesForDay[currentSelectedDay]?.removeAll(where: { $0.objectID == matTime.objectID })
                    } else {
                        viewModel.matTimesForDay[day]?.removeAll(where: { $0.objectID == matTime.objectID })
                    }
                }
            } catch let deleteError {
                await MainActor.run {
                    error = "Failed to delete mat time: \(deleteError.localizedDescription)"
                    showErrorAlert = true
                }
            }
        }
    }
}



// MARK: - MatTimesList
struct MatTimesList: View {
    let day: DayOfWeek
    let matTimes: [MatTime]

    // Callbacks for edit and delete actions
    var onEdit: ((MatTime) -> Void)?
    var onDelete: ((MatTime) -> Void)?

    var body: some View {
        List {
            ForEach(matTimes, id: \.objectID) { matTime in
                VStack(alignment: .leading) {
                    if let timeString = matTime.time {
                        Text("Time: \(DayOfWeek.formatTime(from: timeString))")
                            .font(.headline)
                            .foregroundColor(.primary) // Ensure readability in both modes
                    } else {
                        Text("Time: Unknown")
                            .font(.headline)
                            .foregroundColor(.primary) // Ensure readability in both modes
                    }
                    HStack {
                        if matTime.gi {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("Gi")
                                    .foregroundColor(.primary) // Ensure readability
                            }
                        }
                        if matTime.noGi {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("NoGi")
                                    .foregroundColor(.primary) // Ensure readability
                            }
                        }
                        if matTime.openMat {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("Open Mat")
                                    .foregroundColor(.primary) // Ensure readability
                            }
                        }
                    }

                    if matTime.restrictions {
                        Text("Restrictions: \(matTime.restrictionDescription ?? "Yes")")
                            .font(.caption)
                            .foregroundColor(.red) // Keep red for warnings, ensure it stands out
                    }

                    HStack {
                        if matTime.goodForBeginners {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.blue)
                                Text("Good for Beginners")
                                    .foregroundColor(.primary) // Ensure readability
                            }
                        }
                        if matTime.kids {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.blue)
                                Text("Kids Class")
                                    .foregroundColor(.primary) // Ensure readability
                            }
                        }
                    }

                    // Edit & Delete buttons
                    HStack {
                        Spacer()
                        Button(action: {
                            onEdit?(matTime)
                        }) {
                            Image(systemName: "pencil")
                                .foregroundColor(.accentColor) // Use accentColor for interactive elements
                        }
                        .buttonStyle(BorderlessButtonStyle())

                        Button(action: {
                            onDelete?(matTime)
                        }) {
                            Image(systemName: "trash")
                                .foregroundColor(.red) // Keep red for destructive actions
                        }
                        .buttonStyle(BorderlessButtonStyle())
                    }
                }
                .padding(.vertical, 4) // Add a little vertical padding to each row
            }
        }
        // Removed .navigationBarTitle(Text("Scheduled Mat Times for \(day.rawValue.capitalized)"))
        // This title should be set in the parent `NavigationView` that contains this `ScheduledMatTimesSection`.
        // This allows more flexibility and avoids redundant titles.
    }
}


func debugPrintMatTimes(_ matTimes: [MatTime]) {
    for matTime in matTimes {
        debugPrint("MatTime: \(matTime.time ?? "Unknown"), GI: \(matTime.gi)")
    }
}
