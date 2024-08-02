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

    private var timeDate: Binding<Date> {
        Binding<Date>(
            get: {
                let formatter = DateFormatter()
                formatter.dateFormat = "HH:mm"
                let date = (viewModel.newMatTime?.time.flatMap { formatter.date(from: $0) }) ?? Date()
                print("Current time: \(date)")  // Print current time
                return date
            },
            set: { newDate in
                let formatter = DateFormatter()
                formatter.dateFormat = "HH:mm"
                viewModel.newMatTime?.time = formatter.string(from: newDate)
                print("New time set: \(viewModel.newMatTime?.time ?? "none")")  // Print new time
            }
        )
    }

    private var isButtonEnabled: Bool {
        guard let newMatTime = viewModel.newMatTime else { return false }
        let enabled = !(newMatTime.time?.isEmpty ?? true) && (newMatTime.gi || newMatTime.noGi || newMatTime.openMat)
        print("Is button enabled: \(enabled)")  // Print button enabled state
        return enabled
    }

    var body: some View {
        Section(header: Text("Add New Mat Time")) {
            VStack(alignment: .leading) {
                DatePicker("Time", selection: timeDate, displayedComponents: .hourAndMinute)
                    .datePickerStyle(WheelDatePickerStyle())

                Toggle("Gi", isOn: Binding(
                    get: { viewModel.newMatTime?.gi ?? false },
                    set: { newValue in
                        viewModel.newMatTime?.gi = newValue
                    }
                ))

                Toggle("No Gi", isOn: Binding(
                    get: { viewModel.newMatTime?.noGi ?? false },
                    set: { newValue in
                        viewModel.newMatTime?.noGi = newValue
                    }
                ))

                Toggle("Open Mat", isOn: Binding(
                    get: { viewModel.newMatTime?.openMat ?? false },
                    set: { newValue in
                        viewModel.newMatTime?.openMat = newValue
                    }
                ))

                Toggle("Good for Beginners", isOn: Binding(
                    get: { viewModel.newMatTime?.goodForBeginners ?? false },
                    set: { newValue in
                        viewModel.newMatTime?.goodForBeginners = newValue
                    }
                ))

                Toggle("Adult", isOn: Binding(
                    get: { viewModel.newMatTime?.adult ?? false },
                    set: { newValue in
                        viewModel.newMatTime?.adult = newValue
                    }
                ))

                Toggle("Restrictions", isOn: Binding(
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

                Button(action: {
                    if isButtonEnabled {
                        if let newMatTime = viewModel.newMatTime {
                            // Update name and ID before adding the new mat time
                            viewModel.updateNameAndID()

                            // Call the correct method in your view model
                            viewModel.addOrUpdateMatTime(
                                time: newMatTime.time ?? "",
                                type: "", // Set the type to an empty string for now
                                gi: newMatTime.gi,
                                noGi: newMatTime.noGi,
                                openMat: newMatTime.openMat,
                                restrictions: newMatTime.restrictions,
                                restrictionDescription: newMatTime.restrictionDescription ?? "",
                                goodForBeginners: newMatTime.goodForBeginners,
                                adult: newMatTime.adult,
                                for: selectedDay
                            )
                            print("Selected Island: \(selectedIsland?.islandName ?? "None")")
                            print("Mat time added with time: \(newMatTime.time ?? "none")")  // Print added time
                            viewModel.newMatTime = MatTime(context: viewModel.viewContext) // Reset newMatTime
                        }
                    } else {
                        viewModel.errorMessage = "Please complete all required fields."
                        print("Button disabled: \(viewModel.errorMessage ?? "")")  // Print button disabled reason
                    }
                }) {
                    Text("Add New Mat Time")
                }
                .disabled(!isButtonEnabled)
                .alert(isPresented: Binding<Bool>(
                    get: { viewModel.errorMessage != nil },
                    set: { _ in viewModel.errorMessage = nil }
                )) {
                    Alert(title: Text("Error"), message: Text(viewModel.errorMessage ?? ""), dismissButton: .default(Text("OK")))
                }
            }
        }
        .onAppear {
            viewModel.initializeNewMatTime()
        }
    }
}
