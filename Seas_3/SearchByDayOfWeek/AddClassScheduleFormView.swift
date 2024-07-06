//
//  AddClassScheduleFormView.swift
//  Seas_3
//
//  Created by Brian Romero on 6/26/24.
//

import SwiftUI

struct AddClassScheduleView: View {
    @ObservedObject var viewModel: AppDayOfWeekViewModel
    @Binding var selectedAppDayOfWeek: AppDayOfWeek?
    var pIsland: PirateIsland
    @Binding var goodForBeginners: Bool
    @Binding var matTime: String
    @Binding var openMat: Bool
    @Binding var restrictions: Bool
    @Binding var restrictionDescription: String
    @Binding var selectedIsland: PirateIsland?
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
                        set: { viewModel.matTimeForDay[selectedDay] = $0 }
                    ))
                    Toggle("Gi", isOn: Binding(
                        get: { viewModel.giForDay[selectedDay] ?? false },
                        set: { viewModel.giForDay[selectedDay] = $0 }
                    ))
                    Toggle("No-Gi", isOn: Binding(
                        get: { viewModel.noGiForDay[selectedDay] ?? false },
                        set: { viewModel.noGiForDay[selectedDay] = $0 }
                    ))
                    Toggle("Good for Beginners", isOn: Binding(
                        get: { viewModel.goodForBeginnersForDay[selectedDay] ?? false },
                        set: { viewModel.goodForBeginnersForDay[selectedDay] = $0 }
                    ))
                    Toggle("Open Mat", isOn: Binding(
                        get: { viewModel.openMatForDay[selectedDay] ?? false },
                        set: { viewModel.openMatForDay[selectedDay] = $0 }
                    ))
                    Toggle("Restrictions", isOn: Binding(
                        get: { viewModel.restrictionsForDay[selectedDay] ?? false },
                        set: { viewModel.restrictionsForDay[selectedDay] = $0 }
                    ))
                    TextField("Restriction Description", text: Binding(
                        get: { viewModel.restrictionDescriptionForDay[selectedDay] ?? "" },
                        set: { viewModel.restrictionDescriptionForDay[selectedDay] = $0 }
                    ))
                }
            }
            .navigationTitle("Add Class Schedule")
            .navigationBarItems(trailing: Button(action: {
                viewModel.saveDayDetails(for: selectedDay)
                presentationMode.wrappedValue.dismiss()
            }) {
                Text("Save")
            })
        }
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
            pIsland: PirateIsland(), // Provide a mock PirateIsland instance
            goodForBeginners: .constant(false),
            matTime: .constant(""),
            openMat: .constant(false),
            restrictions: .constant(false),
            restrictionDescription: .constant(""),
            selectedIsland: .constant(nil) // Add the selectedIsland binding
        )
    }
}
