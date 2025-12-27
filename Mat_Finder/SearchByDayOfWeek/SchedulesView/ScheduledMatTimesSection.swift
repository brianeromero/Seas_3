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
    @State private var matTimeToDelete: MatTime?
    @State private var showDeleteConfirmation: Bool = false

    @State private var successMessage: String?
    @State private var showSuccessAlert: Bool = false
    @State private var showErrorAlert: Bool = false

    @State private var editingMatTime: MatTime?
    @State private var showEditModal = false


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
            .alert("Delete Mat Time?", isPresented: $showDeleteConfirmation, presenting: matTimeToDelete) { matTime in
                Button("Delete", role: .destructive) {
                    Task {
                        await deleteConfirmed(matTime)
                    }
                }
                Button("Cancel", role: .cancel) {
                    matTimeToDelete = nil
                }
            } message: { matTime in
                Text("Are you sure you want to delete the mat time at \(matTime.time ?? "Unknown")?")
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

    // ✅ Corrected deleteMatTime: just triggers alert
    func deleteMatTime(_ matTime: MatTime) {
        matTimeToDelete = matTime
        showDeleteConfirmation = true
    }

    // Actual deletion happens here
    func deleteConfirmed(_ matTime: MatTime) async {
        do {
            try await viewModel.removeMatTime(matTime)
            await MainActor.run {
                matTimes.removeAll(where: { $0.objectID == matTime.objectID })
                if let currentSelectedDay = selectedDay {
                    viewModel.matTimesForDay[currentSelectedDay]?.removeAll(where: { $0.objectID == matTime.objectID })
                } else {
                    viewModel.matTimesForDay[day]?.removeAll(where: { $0.objectID == matTime.objectID })
                }
                matTimeToDelete = nil
            }
        } catch let deleteError {
            await MainActor.run {
                error = "Failed to delete mat time: \(deleteError.localizedDescription)"
                showErrorAlert = true
            }
        }
    }
}


// MARK: - MatTimesList
struct MatTimesList: View {
    let day: DayOfWeek
    let matTimes: [MatTime]

    var onEdit: ((MatTime) -> Void)?
    var onDelete: ((MatTime) -> Void)?

    var body: some View {
        List {
            ForEach(matTimes, id: \.objectID) { matTime in
                VStack(alignment: .leading, spacing: 8) {

                    // MARK: Time
                    Text(
                        "\(DayOfWeek.formatTime(from: matTime.time ?? "Unknown"))"
                    )
                    .font(.headline)
                    .foregroundColor(.primary)

                    // MARK: Class Type (Gi / NoGi / Open Mat)
                    HStack(spacing: 12) {
                        if matTime.gi {
                            Label("Gi", systemImage: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        }
                        if matTime.noGi {
                            Label("NoGi", systemImage: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        }
                        if matTime.openMat {
                            Label("Open Mat", systemImage: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        }
                    }
                    .font(.subheadline)

                    // MARK: Audience (Beginners / Kids)
                    HStack(spacing: 12) {
                        if matTime.goodForBeginners {
                            Label("Good for Beginners", systemImage: "checkmark.circle.fill")
                                .foregroundColor(.blue)
                        }
                        if matTime.kids {
                            Label("Kids Class", systemImage: "checkmark.circle.fill")
                                .foregroundColor(.blue)
                        }
                    }
                    .font(.subheadline)

                    // MARK: Restrictions (LAST — no divider)
                    if matTime.restrictions {
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.yellow)

                            Text(matTime.restrictionDescription ?? "Restrictions apply")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }


                    // MARK: Actions
                    HStack {
                        Spacer()

                        Button {
                            onEdit?(matTime)
                        } label: {
                            Image(systemName: "pencil")
                                .foregroundColor(.accentColor)
                        }
                        .buttonStyle(.borderless)

                        Button {
                            onDelete?(matTime)
                        } label: {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
                        .buttonStyle(.borderless)
                    }
                }
                .padding(.vertical, 6)
            }
        }
    }
}






func debugPrintMatTimes(_ matTimes: [MatTime]) {
    for matTime in matTimes {
        debugPrint("MatTime: \(matTime.time ?? "Unknown"), GI: \(matTime.gi)")
    }
}
