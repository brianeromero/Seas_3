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
    @State var matTime: MatTime?

    @State private var timeInput: Date = Date()
    @State private var restrictionDescriptionInput: String = ""

    var body: some View {
        Section(header: Text("Add New Mat Time")) {
            VStack(alignment: .leading) {
                if let matTime = matTime {
                    DatePicker(
                        "Time",
                        selection: $timeInput,
                        displayedComponents: .hourAndMinute
                    )
                    .datePickerStyle(WheelDatePickerStyle())
                    .onChange(of: timeInput) { newValue in
                        matTime.time = formatDateToString(newValue)
                    }

                    ToggleView(title: "Gi", isOn: binding(\.gi))
                    ToggleView(title: "No Gi", isOn: binding(\.noGi))
                    ToggleView(title: "Open Mat", isOn: binding(\.openMat))
                    ToggleView(title: "Good for Beginners", isOn: binding(\.goodForBeginners))
                    ToggleView(title: "Adult", isOn: binding(\.adult))
                    ToggleView(title: "Restrictions", isOn: binding(\.restrictions))
                    
                    if matTime.restrictions {
                        TextField("Restriction Description", text: $restrictionDescriptionInput)
                            .onAppear {
                                restrictionDescriptionInput = matTime.restrictionDescription ?? ""
                            }
                            .onChange(of: restrictionDescriptionInput) { newValue in
                                matTime.restrictionDescription = newValue
                            }
                    }
                } else {
                    Text("Error: matTime is nil")
                }

                if !daySelected {
                    Text("Please select a day.")
                        .foregroundColor(.red)
                }

                Button(action: {
                    guard let selectedIsland = selectedIsland, let matTime = matTime else {
                        print("Selected island or matTime is nil")
                        return
                    }

                    matTime.createdTimestamp = Date()

                    // Fetch or create AppDayOfWeek directly
                    let appDayOfWeek = viewModel.repository.fetchOrCreateAppDayOfWeek(for: selectedDay.rawValue, pirateIsland: selectedIsland)
                    
                    // Assign the fetched or created AppDayOfWeek to the view model
                    viewModel.selectedAppDayOfWeek = appDayOfWeek
                    appDayOfWeek.addToMatTimes(matTime)
                    
                    // Save the changes
                    do {
                        try viewModel.viewContext.save()
                    } catch {
                        print("Error saving changes: \(error)")
                    }

                    // Add the new mat time
                    viewModel.addNewMatTime()
                }) {
                    Text("Add New Mat Time")
                }
                .disabled(!(daySelected && matTime != nil))

            }
            .onAppear {
                if let newMatTime = viewModel.newMatTime {
                    if matTime == nil {
                        matTime = newMatTime
                        timeInput = stringToDate(newMatTime.time ?? "")
                        restrictionDescriptionInput = newMatTime.restrictionDescription ?? ""
                    }
                }
            }
        }
    }
    
    func binding(_ keyPath: WritableKeyPath<MatTime, Bool>) -> Binding<Bool> {
        return Binding(
            get: { matTime?[keyPath: keyPath] ?? false },
            set: { if var matTime = self.matTime { matTime[keyPath: keyPath] = $0; self.matTime = matTime } }
        )
    }

    private func formatDateToString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mma"
        return formatter.string(from: date)
    }

    private func stringToDate(_ string: String) -> Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mma"
        return formatter.date(from: string) ?? Date()
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
