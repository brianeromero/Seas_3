//
//  AddNewMatTimeSection.swift
//  Seas_3
//
//  Created by Brian Romero on 8/1/24.
//

import SwiftUI
import CoreData

struct AddNewMatTimeSection: View {
    @Binding var selectedAppDayOfWeek: AppDayOfWeek?
    @Binding var selectedIsland: PirateIsland?
    @ObservedObject var viewModel: AppDayOfWeekViewModel
    @Binding var selectedDay: DayOfWeek
    @Binding var name: String
    @Binding var appDayOfWeekID: String?
    @State private var selectedDate = Date()

    private var isButtonEnabled: Bool {
        guard let newMatTime = viewModel.newMatTime else { return false }
        return !(newMatTime.time?.isEmpty ?? true) && (newMatTime.gi || newMatTime.noGi || newMatTime.openMat)
    }

    var body: some View {
        Section(header: Text("Add New Mat Time")) {
            VStack(alignment: .leading) {
                DatePicker("Time", selection: $selectedDate, displayedComponents: .hourAndMinute)
                    .datePickerStyle(WheelDatePickerStyle())
                    .onChange(of: selectedDate) { newDate in
                        let formatter = DateFormatter()
                        formatter.dateFormat = "HH:mm"
                        viewModel.newMatTime?.time = formatter.string(from: newDate)
                    }

                ToggleView(title: "Gi", isOn: Binding(
                    get: { viewModel.newMatTime?.gi ?? false },
                    set: { newValue in
                        viewModel.newMatTime?.gi = newValue
                    }
                ))

                ToggleView(title: "No Gi", isOn: Binding(
                    get: { viewModel.newMatTime?.noGi ?? false },
                    set: { newValue in
                        viewModel.newMatTime?.noGi = newValue
                    }
                ))

                ToggleView(title: "Open Mat", isOn: Binding(
                    get: { viewModel.newMatTime?.openMat ?? false },
                    set: { newValue in
                        viewModel.newMatTime?.openMat = newValue
                    }
                ))

                ToggleView(title: "Good for Beginners", isOn: Binding(
                    get: { viewModel.newMatTime?.goodForBeginners ?? false },
                    set: { newValue in
                        viewModel.newMatTime?.goodForBeginners = newValue
                    }
                ))

                ToggleView(title: "Adult", isOn: Binding(
                    get: { viewModel.newMatTime?.adult ?? false },
                    set: { newValue in
                        viewModel.newMatTime?.adult = newValue
                    }
                ))

                ToggleView(title: "Restrictions", isOn: Binding(
                    get: { viewModel.newMatTime?.restrictions ?? false },
                    set: { newValue in
                        viewModel.newMatTime?.restrictions = newValue
                    }
                ))

                if viewModel.newMatTime?.restrictions ?? false {
                    TextField("Restriction Description", text: Binding(
                        get: { viewModel.newMatTime?.restrictionDescription ?? "" },
                        set: { newValue in
                            viewModel.newMatTime?.restrictionDescription = newValue
                        }
                    ))
                }

                Button(action: viewModel.addNewMatTime) {
                    Text("Add New Mat Time")
                }
                .disabled(!isButtonEnabled)
                .alert(isPresented: $viewModel.showError) {
                    Alert(title: Text("Error"), message: Text(viewModel.errorMessage ?? ""), dismissButton: .default(Text("OK")))
                }
                .onAppear {
                    viewModel.initializeNewMatTime()
                }
            }
        }
    }
}

struct ToggleView: View {
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(title, isOn: $isOn)
    }
}
