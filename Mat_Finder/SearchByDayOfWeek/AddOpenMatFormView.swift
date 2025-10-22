// AddOpenMatFormView.swift
// Mat_Finder
//
// Created by Brian Romero on 6/26/24.
//

import SwiftUI
import Foundation
import CoreData

struct AddOpenMatFormView: View {
    @StateObject var viewModel: AppDayOfWeekViewModel
    @Binding var selectedAppDayOfWeek: AppDayOfWeek?
    var selectedIsland: PirateIsland? // Make this optional
    
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    init(viewModel: AppDayOfWeekViewModel, selectedAppDayOfWeek: Binding<AppDayOfWeek?>, selectedIsland: PirateIsland?) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self._selectedAppDayOfWeek = selectedAppDayOfWeek
        self.selectedIsland = selectedIsland
    }
    
    var body: some View {
        Form {
            daySelectionSection
            
            if let selectedDay = viewModel.selectedDay {
                matTimeSection(for: selectedDay)
                matTimesListSection(for: selectedDay)
                settingsSection(for: selectedDay)
            }
            
            saveButton
        }
        .onAppear {
            viewModel.fetchPirateIslands()
            if let selectedIsland = selectedIsland, let selectedDay = viewModel.selectedDay {
                Task {
                    _ = await viewModel.fetchCurrentDayOfWeek(
                        for: selectedIsland,
                        day: selectedDay,
                        selectedDayBinding: Binding(
                            get: { viewModel.selectedDay },
                            set: { viewModel.selectedDay = $0 }
                        )
                    )
                }
            } else {
                print("No gym or day selected")
            }
        }
    }

    var daySelectionSection: some View {
        Section(header: Text("Select Day3")) {
            Picker("Day", selection: $viewModel.selectedDay) {
                ForEach(DayOfWeek.allCases) { day in
                    Text(day.displayName).tag(day as DayOfWeek?)
                    
                }
            }
            .pickerStyle(MenuPickerStyle())
        }
    }
    
    func matTimeSection(for day: DayOfWeek) -> some View {
        Section(header: Text("Mat Time")) {
            DatePicker(
                "Select Time",
                selection: Binding(
                    get: { viewModel.selectedTimeForDay[day] ?? Date() },
                    set: { newDate in
                        Task {
                            let formattedTime = DateFormat.time.string(from: newDate)
                            await viewModel.addOrUpdateMatTime(
                                time: formattedTime,
                                type: viewModel.selectedType,
                                gi: viewModel.giForDay[day] ?? false,
                                noGi: viewModel.noGiForDay[day] ?? false,
                                openMat: viewModel.openMatForDay[day] ?? false,
                                restrictions: viewModel.restrictionsForDay[day] ?? false,
                                restrictionDescription: viewModel.restrictionDescriptionForDay[day] ?? "",
                                goodForBeginners: viewModel.goodForBeginnersForDay[day] ?? false,
                                kids: viewModel.kidsForDay[day] ?? false,
                                for: day
                            )
                        }
                    }
                ),
                displayedComponents: .hourAndMinute
            )
            .datePickerStyle(WheelDatePickerStyle())
        }
    }
    
    func removeMatTimes(at indices: IndexSet, for day: DayOfWeek) {
        indices.forEach { index in
            guard let matTime = viewModel.matTimesForDay[day]?[index] else { return }

            Task {
                do {
                    try await viewModel.removeMatTime(matTime)
                    
                    // 🔄 Re-fetch updated list
                    let updatedMatTimes = try viewModel.fetchMatTimes(for: day)
                    
                    // 👇 Ensure UI update on main thread
                    await MainActor.run {
                        viewModel.matTimesForDay[day] = updatedMatTimes
                    }
                } catch {
                    await MainActor.run {
                        self.alertMessage = "Failed to remove mat time: \(error.localizedDescription)"
                        self.showAlert = true
                    }
                }
            }
        }
    }

    func matTimesListSection(for day: DayOfWeek) -> some View {
        Section(header: Text("Scheduled Mat Timesssss")) {
            if let matTimes = viewModel.matTimesForDay[day] {
                ForEach(matTimes, id: \.self) { matTime in
                    HStack {
                        Text(matTime.time ?? "")
                        Spacer()
                        if matTime.gi {
                            Text("Gi")
                        }
                        if matTime.noGi {
                            Text("No Gi")
                        }
                    }
                }
                .onDelete { indices in
                    removeMatTimes(at: indices, for: day)
                }
            }
        }
    }
    
    func settingsSection(for day: DayOfWeek) -> some View {
        Section(header: Text("Settings")) {
            Toggle(isOn: Binding(
                get: { viewModel.giForDay[day] ?? false },
                set: { newValue in viewModel.giForDay[day] = newValue }
            )) {
                Text("Gi")
            }
            Toggle(isOn: Binding(
                get: { viewModel.noGiForDay[day] ?? false },
                set: { newValue in viewModel.noGiForDay[day] = newValue }
            )) {
                Text("No Gi")
            }
            Toggle(isOn: Binding(
                get: { viewModel.openMatForDay[day] ?? false },
                set: { newValue in viewModel.openMatForDay[day] = newValue }
            )) {
                Text("Open Mat")
            }
            Toggle(isOn: Binding(
                get: { viewModel.goodForBeginnersForDay[day] ?? false },
                set: { newValue in viewModel.goodForBeginnersForDay[day] = newValue }
            )) {
                Text("Good for Beginners")
            }
            Toggle(isOn: Binding(
                get: { viewModel.kidsForDay[day] ?? false },
                set: { newValue in viewModel.kidsForDay[day] = newValue }
            )) {
                Text("Kids Class")
            }
            Toggle(isOn: Binding(
                get: { viewModel.restrictionsForDay[day] ?? false },
                set: { newValue in viewModel.restrictionsForDay[day] = newValue }
            )) {
                Text("Restrictions")
            }
            if viewModel.restrictionsForDay[day] ?? false {
                TextField("Restriction Description", text: Binding(
                    get: { viewModel.restrictionDescriptionForDay[day] ?? "" },
                    set: { newValue in viewModel.restrictionDescriptionForDay[day] = newValue }
                ))
            }
        }
    }
    
    var saveButton: some View {
        Button(action: {
            Task {
                if viewModel.validateFields() {
                    let timeString = DateFormat.time.string(from: viewModel.selectedTimeForDay[viewModel.selectedDay ?? DayOfWeek.monday] ?? Date())
                    await viewModel.addOrUpdateMatTime(
                        time: timeString,
                        type: viewModel.selectedType,
                        gi: viewModel.giForDay[viewModel.selectedDay ?? DayOfWeek.monday] ?? false,
                        noGi: viewModel.noGiForDay[viewModel.selectedDay ?? DayOfWeek.monday] ?? false,
                        openMat: viewModel.openMatForDay[viewModel.selectedDay ?? DayOfWeek.monday] ?? false,
                        restrictions: viewModel.restrictionsForDay[viewModel.selectedDay ?? DayOfWeek.monday] ?? false,
                        restrictionDescription: viewModel.restrictionDescriptionForDay[viewModel.selectedDay ?? DayOfWeek.monday] ?? "",
                        goodForBeginners: viewModel.goodForBeginnersForDay[viewModel.selectedDay ?? DayOfWeek.monday] ?? false,
                        kids: viewModel.kidsForDay[viewModel.selectedDay ?? DayOfWeek.monday] ?? false,
                        for: viewModel.selectedDay ?? DayOfWeek.monday
                    )
                } else {
                    alertMessage = "Please fill in all required fields202122."
                    showAlert = true
                }
            }
        }) {
            Text("Save")
        }
        .disabled(!viewModel.isSaveEnabled)
    }
}
