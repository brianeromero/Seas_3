//
//  AddClassScheduleView.swift
//  Seas_3
//
//  Created by Brian Romero on 6/26/24.
//

import SwiftUI

struct AddClassScheduleView: View {
    @ObservedObject var viewModel: AppDayOfWeekViewModel
    @Binding var selectedAppDayOfWeek: AppDayOfWeek?
    var pIsland: PirateIsland  // Ensure this parameter is defined
    @Environment(\.presentationMode) var presentationMode
    @State private var selectedDay: DayOfWeek = .monday

    var body: some View {
        VStack {
            Text("Select Day:")
            Picker("Day", selection: $selectedDay) {
                ForEach(DayOfWeek.allCases, id: \.self) { day in
                    Text(day.displayName).tag(day)
                }
            }
            .pickerStyle(MenuPickerStyle())

            Form {
                Section(header: Text("Class Schedule Details")) {
                    TextField("Mat Time", text: Binding(
                        get: { viewModel.matTimeForDay[selectedDay] ?? "" },
                        set: { newValue in viewModel.matTimeForDay[selectedDay] = newValue }
                    ))
                    Toggle("Gi", isOn: Binding(
                        get: { viewModel.giForDay[selectedDay] ?? false },
                        set: { newValue in viewModel.giForDay[selectedDay] = newValue }
                    ))
                    Toggle("No-Gi", isOn: Binding(
                        get: { viewModel.noGiForDay[selectedDay] ?? false },
                        set: { newValue in viewModel.noGiForDay[selectedDay] = newValue }
                    ))
                    Toggle("Good for Beginners", isOn: Binding(
                        get: { viewModel.goodForBeginnersForDay[selectedDay] ?? false },
                        set: { newValue in viewModel.goodForBeginnersForDay[selectedDay] = newValue }
                    ))
                    Toggle("Open Mat", isOn: Binding(
                        get: { viewModel.openMatForDay[selectedDay] ?? false },
                        set: { newValue in viewModel.openMatForDay[selectedDay] = newValue }
                    ))
                    Toggle("Restrictions", isOn: Binding(
                        get: { viewModel.restrictionsForDay[selectedDay] ?? false },
                        set: { newValue in viewModel.restrictionsForDay[selectedDay] = newValue }
                    ))
                    TextField("Restriction Description", text: Binding(
                        get: { viewModel.restrictionDescriptionForDay[selectedDay] ?? "" },
                        set: { newValue in viewModel.restrictionDescriptionForDay[selectedDay] = newValue }
                    ))
                }
            }
            .navigationTitle("Add Class Schedule")
            .navigationBarItems(trailing:
                Button("Save") {
                    saveAction()
                }
            )
        }
    }
    
    private func saveAction() {
        viewModel.updateSchedulesForSelectedDays() // Example method from AppDayOfWeekViewModel
        presentationMode.wrappedValue.dismiss()
    }
}

struct AddClassScheduleView_Previews: PreviewProvider {
    static var previews: some View {
        // Create a mock AppDayOfWeekViewModel with a selected island
        let viewModel = AppDayOfWeekViewModel(selectedIsland: PirateIsland())

        // Provide bindings for all required properties
        return AddClassScheduleView(
            viewModel: viewModel,
            selectedAppDayOfWeek: .constant(nil),
            pIsland: PirateIsland() // Ensure correct initialization of PirateIsland
        )
    }
}
