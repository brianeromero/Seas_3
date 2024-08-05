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
        let timeIsValid = !(newMatTime.time?.isEmpty ?? true)
        let anyToggleIsOn = newMatTime.gi || newMatTime.noGi || newMatTime.openMat
        return timeIsValid && anyToggleIsOn
    }

    var body: some View {
        Section(header: Text("Add New Mat Time")) {
            VStack(alignment: .leading) {
                if let newMatTime = viewModel.newMatTime {
                    DatePicker("Time", selection: $selectedDate, displayedComponents: .hourAndMinute)
                        .datePickerStyle(WheelDatePickerStyle())
                        .onChange(of: selectedDate) { newDate in
                            let formatter = DateFormatter()
                            formatter.dateFormat = "HH:mm"
                            newMatTime.time = formatter.string(from: newDate)
                            viewModel.objectWillChange.send() // Trigger manual update
                        }

                    ToggleView(title: "Gi", isOn: Binding(
                        get: { newMatTime.gi },
                        set: { newMatTime.gi = $0; viewModel.objectWillChange.send() } // Trigger manual update
                    ))

                    ToggleView(title: "No Gi", isOn: Binding(
                        get: { newMatTime.noGi },
                        set: { newMatTime.noGi = $0; viewModel.objectWillChange.send() } // Trigger manual update
                    ))

                    ToggleView(title: "Open Mat", isOn: Binding(
                        get: { newMatTime.openMat },
                        set: { newMatTime.openMat = $0; viewModel.objectWillChange.send() } // Trigger manual update
                    ))

                    ToggleView(title: "Good for Beginners", isOn: Binding(
                        get: { newMatTime.goodForBeginners },
                        set: { newMatTime.goodForBeginners = $0; viewModel.objectWillChange.send() } // Trigger manual update
                    ))

                    ToggleView(title: "Adult", isOn: Binding(
                        get: { newMatTime.adult },
                        set: { newMatTime.adult = $0; viewModel.objectWillChange.send() } // Trigger manual update
                    ))

                    ToggleView(title: "Restrictions", isOn: Binding(
                        get: { newMatTime.restrictions },
                        set: { newMatTime.restrictions = $0; viewModel.objectWillChange.send() } // Trigger manual update
                    ))

                    if newMatTime.restrictions {
                        TextField("Restriction Description", text: Binding(
                            get: { newMatTime.restrictionDescription ?? "" },
                            set: { newMatTime.restrictionDescription = $0; viewModel.objectWillChange.send() } // Trigger manual update
                        ))
                    }
                } else {
                    Text("Error: newMatTime is nil")
                }

                Button(action: {
                    viewModel.updateNameAndID() // Ensure this is called before adding mat time
                    viewModel.addNewMatTime()
                }) {
                    Text("Add New Mat Time")
                }
                .disabled(!isButtonEnabled)
                .alert(isPresented: $viewModel.showError) {
                    Alert(title: Text("Error"), message: Text(viewModel.errorMessage ?? ""), dismissButton: .default(Text("OK")))
                }
                .onAppear {
                    viewModel.updateNameAndID() // Ensure name and ID are updated before initializing new mat time
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
