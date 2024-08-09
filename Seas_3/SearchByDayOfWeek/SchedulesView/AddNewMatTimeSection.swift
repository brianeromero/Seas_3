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
    @Binding var daySelected: Bool

    private var isButtonEnabled: Bool {
        guard let newMatTime = viewModel.newMatTime else { return false }
        let timeIsValid = !(newMatTime.time?.isEmpty ?? true)
        let anyToggleIsOn = newMatTime.gi || newMatTime.noGi || newMatTime.openMat || newMatTime.goodForBeginners || newMatTime.adult || newMatTime.restrictions
        return daySelected && timeIsValid && anyToggleIsOn
    }

    var body: some View {
        Section(header: Text("Add New Mat Time")) {
            VStack(alignment: .leading) {
                if let newMatTime = viewModel.newMatTime {
                    DatePicker("Time", selection: Binding(
                        get: {
                            let formatter = DateFormatter()
                            formatter.dateFormat = "HH:mm"
                            return formatter.date(from: newMatTime.time ?? "") ?? Date()
                        },
                        set: { newDate in
                            let formatter = DateFormatter()
                            formatter.dateFormat = "HH:mm"
                            newMatTime.time = formatter.string(from: newDate)
                            print("Selected Date Changed: \(newMatTime.time ?? "No Time")")
                        }
                    ), displayedComponents: .hourAndMinute)
                    .datePickerStyle(WheelDatePickerStyle())

                    // Safely unwrap newMatTime properties and use Binding
                    ToggleView(title: "Gi", isOn: Binding(
                        get: { newMatTime.gi },
                        set: { newMatTime.gi = $0 }
                    ))
                    ToggleView(title: "No Gi", isOn: Binding(
                        get: { newMatTime.noGi },
                        set: { newMatTime.noGi = $0 }
                    ))
                    ToggleView(title: "Open Mat", isOn: Binding(
                        get: { newMatTime.openMat },
                        set: { newMatTime.openMat = $0 }
                    ))
                    ToggleView(title: "Good for Beginners", isOn: Binding(
                        get: { newMatTime.goodForBeginners },
                        set: { newMatTime.goodForBeginners = $0 }
                    ))
                    ToggleView(title: "Adult", isOn: Binding(
                        get: { newMatTime.adult },
                        set: { newMatTime.adult = $0 }
                    ))
                    ToggleView(title: "Restrictions", isOn: Binding(
                        get: { newMatTime.restrictions },
                        set: { newMatTime.restrictions = $0 }
                    ))

                    TextField("Time", text: Binding(
                        get: { newMatTime.time ?? "" },
                        set: { newMatTime.time = $0 }
                    ))

                    if newMatTime.restrictions {
                        TextField("Restriction Description", text: Binding(
                            get: { newMatTime.restrictionDescription ?? "" },
                            set: {
                                newMatTime.restrictionDescription = $0
                                print("Restriction Description Changed: \(newMatTime.restrictionDescription ?? "No Description")")
                            }
                        ))
                    }
                } else {
                    Text("Error: newMatTime is nil")
                }
                if !daySelected {
                    Text("Please select a day.")
                        .foregroundColor(.red)
                }
                Button(action: {
                    print("Add New Mat Time button tapped!")
                    guard let selectedIsland = selectedIsland, let newMatTime = viewModel.newMatTime else {
                        print("Selected island or newMatTime is nil")
                        return
                    }

                    newMatTime.createdTimestamp = Date()

                    viewModel.addMatTimes(
                        day: selectedDay,
                        matTimes: [(time: newMatTime.time ?? "", type: "", gi: newMatTime.gi, noGi: newMatTime.noGi, openMat: newMatTime.openMat, restrictions: newMatTime.restrictions, restrictionDescription: newMatTime.restrictionDescription, goodForBeginners: newMatTime.goodForBeginners, adult: newMatTime.adult)]
                    )

                    if let newAppDayOfWeek = viewModel.repository.fetchAppDayOfWeek(for: selectedIsland, day: selectedDay) {
                        viewModel.selectedAppDayOfWeek = newAppDayOfWeek
                    }

                    viewModel.addNewMatTime()
                }) {
                    Text("Add New Mat Time")
                }
                .disabled(!isButtonEnabled)
                .alert(isPresented: $viewModel.showError) {
                    Alert(title: Text("Error"), message: Text(viewModel.errorMessage ?? ""), dismissButton: .default(Text("OK")))
                }
            }
        }
    }
}

struct ToggleView: View {
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            Text(title)
        }
    }
}
