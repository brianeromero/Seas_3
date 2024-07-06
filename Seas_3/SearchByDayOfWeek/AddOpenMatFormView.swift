//
//  AddOpenMatFormView.swift
//  Seas_3
//
//  Created by Brian Romero on 6/26/24.
//

import SwiftUI

struct AddOpenMatFormView: View {
    @ObservedObject var viewModel: AppDayOfWeekViewModel
    @Binding var selectedAppDayOfWeek: AppDayOfWeek?
    var pIsland: PirateIsland?

    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var selectedTime = Date()
    @State private var selectedDay: DayOfWeek?

    @State private var showTimePicker = false
    @State private var saveEnabled = false

    var body: some View {
        NavigationView {
            Form {
                // Section: Add Open Mat Details
                Section(header: Text("Add Open Mat Details")) {
                    ForEach(DayOfWeek.allCases, id: \.self) { day in
                        HStack {
                            Text(day.displayName)
                            Spacer()
                            Button(action: {
                                self.selectedDay = day
                                viewModel.toggleDaySelection(day)
                            }) {
                                Image(systemName: "plus.circle")
                                    .foregroundColor(.blue)
                                    .accessibility(label: Text("Select \(day.displayName)"))
                            }
                        }
                    }
                }

                // Section: Selected Day
                Section(header: Text("Selected Day")) {
                    if let selectedDay = selectedDay {
                        VStack(alignment: .leading) {
                            Text("Selected Day: \(selectedDay.displayName)")
                                .foregroundColor(.blue)

                            // Section: Schedule Details
                            Section(header: Text("Schedule Details")) {
                                TextField("Time", text: Binding<String>(
                                    get: { viewModel.matTimeForDay[selectedDay] ?? "" },
                                    set: { newValue in viewModel.updateMatTime(for: selectedDay, time: newValue) }
                                ))
                                .onTapGesture {
                                    showTimePicker = true
                                }
                                .sheet(isPresented: $showTimePicker) {
                                    VStack {
                                        DatePicker("Select Time", selection: $selectedTime, displayedComponents: .hourAndMinute)
                                            .datePickerStyle(WheelDatePickerStyle())
                                            .onChange(of: selectedTime) { newValue in
                                                viewModel.updateSelectedTime(for: selectedDay, time: newValue)
                                                validateFields()
                                                showTimePicker = false
                                            }
                                        Button("Done") {
                                            showTimePicker = false
                                        }
                                        .padding(.top, 10)
                                    }
                                }

                                Toggle("Open Mat", isOn: Binding<Bool>(
                                    get: { viewModel.openMatForDay[selectedDay] ?? false },
                                    set: { newValue in viewModel.openMatForDay[selectedDay] = newValue }
                                ))
                                Toggle("GI", isOn: Binding<Bool>(
                                    get: { viewModel.giForDay[selectedDay] ?? false },
                                    set: { newValue in viewModel.giForDay[selectedDay] = newValue }
                                ))
                                Toggle("No GI", isOn: Binding<Bool>(
                                    get: { viewModel.noGiForDay[selectedDay] ?? false },
                                    set: { newValue in viewModel.noGiForDay[selectedDay] = newValue }
                                ))

                                // Section: Additional Information
                                Section(header: Text("Additional Information")) {
                                    Toggle("Restrictions", isOn: Binding<Bool>(
                                        get: { viewModel.restrictionsForDay[selectedDay] ?? false },
                                        set: { newValue in viewModel.restrictionsForDay[selectedDay] = newValue }
                                    ))
                                    if viewModel.restrictionsForDay[selectedDay] ?? false {
                                        TextField("Description", text: Binding<String>(
                                            get: { viewModel.restrictionDescriptionForDay[selectedDay] ?? "" },
                                            set: { newValue in viewModel.restrictionDescriptionForDay[selectedDay] = newValue }
                                        ))
                                        .onChange(of: viewModel.restrictionDescriptionForDay[selectedDay] ?? "") { _ in
                                            validateFields()
                                        }
                                    }

                                    Toggle("Good For Beginners", isOn: Binding<Bool>(
                                        get: { viewModel.goodForBeginnersForDay[selectedDay] ?? false },
                                        set: { newValue in viewModel.goodForBeginnersForDay[selectedDay] = newValue }
                                    ))
                                }
                            }

                            // Save Button
                            Button("Save") {
                                saveSchedule(for: selectedDay)
                            }
                            .disabled(!saveEnabled)
                            .padding(.top, 10)
                        }
                    } else {
                        Text("Please select a day to continue.")
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationBarTitle("Add Open Mat", displayMode: .inline)
            .alert(isPresented: $showAlert) {
                Alert(title: Text("Error"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
            }
        }
        .onAppear {
            validateFields() // Initial validation check
        }
        .onDisappear {
            resetState() // Reset state variables when the view disappears
        }
    }

    private func saveSchedule(for day: DayOfWeek?) {
        guard let day = day else { return }
        guard let island = pIsland else {
            print("Error: Selected island is nil.")
            return
        }

        viewModel.updateSchedulesForSelectedDays()

        showAlert = true
        alertMessage = "Schedule saved successfully for \(day.displayName) at \(viewModel.matTimeForDay[day] ?? "")."
    }

    private func validateFields() {
        saveEnabled = isSaveEnabled
    }

    private var isSaveEnabled: Bool {
        guard let selectedDay = selectedDay,
              let matTime = viewModel.matTimeForDay[selectedDay], !matTime.isEmpty,
              (viewModel.giForDay[selectedDay] ?? false || viewModel.noGiForDay[selectedDay] ?? false) else {
            return false
        }
        return true
    }

    private func resetState() {
        selectedDay = nil
        selectedTime = Date()
        viewModel.selectedDays.removeAll()
    }
}

struct AddOpenMatFormView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext
        let mockIsland = PirateIsland(context: context)
        mockIsland.islandName = "Mock Island"

        let viewModel = AppDayOfWeekViewModel(selectedIsland: mockIsland)

        return AddOpenMatFormView(
            viewModel: viewModel,
            selectedAppDayOfWeek: .constant(nil),
            pIsland: mockIsland
        )
        .environment(\.managedObjectContext, context)
    }
}
