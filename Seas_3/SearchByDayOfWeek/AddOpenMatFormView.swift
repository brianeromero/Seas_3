// AddOpenMatFormView.swift
// Seas_3
//
// Created by Brian Romero on 6/26/24.
//

import SwiftUI
import Foundation
import CoreData

struct AddOpenMatFormView: View {
    @StateObject var viewModel: AppDayOfWeekViewModel
    @Binding var selectedAppDayOfWeek: AppDayOfWeek?
    var selectedIsland: PirateIsland
    
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    init(viewModel: AppDayOfWeekViewModel, selectedAppDayOfWeek: Binding<AppDayOfWeek?>, selectedIsland: PirateIsland) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self._selectedAppDayOfWeek = selectedAppDayOfWeek
        self.selectedIsland = selectedIsland
    }
    
    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "hh:mm a"
        return formatter
    }()
    
    var body: some View {
        Form {
            daySelectionSection
            matTimeSection(for: viewModel.selectedDay)
            matTimesListSection(for: viewModel.selectedDay)
            settingsSection(for: viewModel.selectedDay)
            saveButton
        }
        .onAppear {
            viewModel.fetchPirateIslands()
            viewModel.fetchCurrentDayOfWeek(for: selectedIsland)
        }
        .alert(isPresented: $showAlert) {
            Alert(title: Text("Error"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
        }
    }
    
    var daySelectionSection: some View {
        Section(header: Text("Select Day")) {
            Picker("Day", selection: $viewModel.selectedDay) {
                ForEach(DayOfWeek.allCases) { day in
                    Text(day.displayName).tag(day)
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
                        viewModel.selectedTimeForDay[day] = newDate
                        let formattedTime = Self.dateFormatter.string(from: newDate)
                        viewModel.addOrUpdateMatTime(
                            time: formattedTime,
                            type: viewModel.selectedType,
                            gi: viewModel.giForDay[day] ?? false,
                            noGi: viewModel.noGiForDay[day] ?? false,
                            openMat: viewModel.openMatForDay[day] ?? false,
                            restrictions: viewModel.restrictionsForDay[day] ?? false,
                            restrictionDescription: viewModel.restrictionDescriptionForDay[day] ?? "",
                            goodForBeginners: viewModel.goodForBeginnersForDay[day] ?? false,
                            adult: viewModel.adultForDay[day] ?? false
                        )
                    }
                ),
                displayedComponents: .hourAndMinute
            )
            .datePickerStyle(WheelDatePickerStyle())
        }
    }
    
    
    func matTimesListSection(for day: DayOfWeek) -> some View {
        Section(header: Text("Scheduled Mat Times")) {
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
                .onDelete { indexSet in
                    indexSet.forEach { index in
                        let matTime = matTimes[index]
                        viewModel.removeMatTime(matTime)
                    }
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
                get: { viewModel.adultForDay[day] ?? false },
                set: { newValue in viewModel.adultForDay[day] = newValue }
            )) {
                Text("Adult Class")
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
            if viewModel.validateFields() {
                let timeString = Self.dateFormatter.string(from: viewModel.selectedTimeForDay[viewModel.selectedDay] ?? Date())
                viewModel.addOrUpdateMatTime(
                    time: timeString,
                    type: viewModel.selectedType,
                    gi: viewModel.giForDay[viewModel.selectedDay] ?? false,
                    noGi: viewModel.noGiForDay[viewModel.selectedDay] ?? false,
                    openMat: viewModel.openMatForDay[viewModel.selectedDay] ?? false,
                    restrictions: viewModel.restrictionsForDay[viewModel.selectedDay] ?? false,
                    restrictionDescription: viewModel.restrictionDescriptionForDay[viewModel.selectedDay] ?? "",
                    goodForBeginners: viewModel.goodForBeginnersForDay[viewModel.selectedDay] ?? false,
                    adult: viewModel.adultForDay[viewModel.selectedDay] ?? false
                )
            } else {
                alertMessage = "Please fill in all required fields."
                showAlert = true
            }
        }) {
            Text("Save")
        }
        .disabled(!viewModel.isSaveEnabled)
    }
}

struct AddOpenMatFormView_Previews: PreviewProvider {
    static var previews: some View {
        // Create a mock PirateIsland with default values
        let sampleIsland = PirateIsland()
        
        // Create a mock AppDayOfWeek with default values
        let sampleAppDayOfWeek = AppDayOfWeek()
        
        // Create a mock AppDayOfWeekViewModel with sampleIsland
        let mockViewModel = AppDayOfWeekViewModel(selectedIsland: sampleIsland)
        
        // Create a sample binding for AppDayOfWeek
        let binding = Binding<AppDayOfWeek?>(
            get: { sampleAppDayOfWeek },
            set: { _ in }
        )
        
        AddOpenMatFormView(
            viewModel: mockViewModel,
            selectedAppDayOfWeek: binding,
            selectedIsland: sampleIsland
        )
    }
}
