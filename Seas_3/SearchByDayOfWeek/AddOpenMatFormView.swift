//
//  AddOpenMatFormView.swift
//  Seas_3
//
//  Created by Brian Romero on 6/26/24.
//

import SwiftUI
import CoreData

struct AddOpenMatFormView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject var viewModel: AppDayOfWeekViewModel
    @Binding var selectedAppDayOfWeek: AppDayOfWeek?
    var pIsland: PirateIsland?

    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var selectedDay: DayOfWeek?
    @State private var showTimePicker = false
    @State private var saveEnabled = false
    @State private var selectedDate = Date()

    var body: some View {
        NavigationView {
            Form {
                daySelectionSection

                if let selectedDay = selectedDay {
                    selectedDaySection(selectedDay: selectedDay)
                }

                islandScheduleLinkSection
            }
            .navigationTitle("Add Open Mat Form")
            .onAppear {
                viewModel.fetchCurrentDayOfWeek()
                validateFields()
            }
            .alert(isPresented: $showAlert) {
                Alert(title: Text("Error"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
            }
            .onDisappear {
                resetState()
            }
        }
    }

    // MARK: - Form Sections

    private var daySelectionSection: some View {
        Section {
            if selectedDay == nil {
                Text("Please select a day to continue.")
                    .foregroundColor(.red)
            }

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
        }
    }

    private func selectedDaySection(selectedDay: DayOfWeek) -> some View {
        Section(header: Text("Selected Day")) {
            VStack(alignment: .leading) {
                Text("Selected Day: \(selectedDay.displayName)")
                    .foregroundColor(.blue)

                Section(header: Text("Schedule Details")) {
                    timePickerSection(selectedDay: selectedDay)

                    Toggle("Open Mat", isOn: Binding(
                        get: { viewModel.openMatForDay[selectedDay] ?? false },
                        set: { viewModel.openMatForDay[selectedDay] = $0 }
                    ))

                    Toggle("GI", isOn: Binding(
                        get: { viewModel.giForDay[selectedDay] ?? false },
                        set: { viewModel.giForDay[selectedDay] = $0 }
                    ))
                    .onChange(of: viewModel.giForDay[selectedDay] ?? false) { _ in
                        validateFields()
                    }

                    Toggle("No GI", isOn: Binding(
                        get: { viewModel.noGiForDay[selectedDay] ?? false },
                        set: { viewModel.noGiForDay[selectedDay] = $0 }
                    ))
                    .onChange(of: viewModel.noGiForDay[selectedDay] ?? false) { _ in
                        validateFields()
                    }

                    TextField("Time", text: Binding(
                        get: { viewModel.matTimeForDay[selectedDay] ?? "" },
                        set: { newValue in
                            viewModel.matTimeForDay[selectedDay] = newValue
                            validateFields()
                        }
                    ))
                    .onChange(of: viewModel.matTimeForDay[selectedDay] ?? "") { _ in
                        validateFields()
                    }

                    additionalInformationSection(selectedDay: selectedDay)
                }

                Button("Save") {
                    saveSchedule(for: selectedDay)
                }
                .disabled(!saveEnabled)
                .padding(.top, 10)
            }
        }
    }

    private func timePickerSection(selectedDay: DayOfWeek) -> some View {
        VStack {
            TextField("Time", text: Binding(
                get: { viewModel.matTimeForDay[selectedDay] ?? "" },
                set: { newValue in
                    viewModel.matTimeForDay[selectedDay] = newValue
                    validateFields()
                }
            ))
            .onChange(of: viewModel.matTimeForDay[selectedDay] ?? "") { _ in
                validateFields()
            }
            .disabled(showTimePicker) // Disable editing while time picker is shown

            Button(action: {
                showTimePicker = true
            }) {
                Text("Select Time")
            }
            .sheet(isPresented: $showTimePicker) {
                timePickerSheet
            }
        }
    }

    private var timePickerSheet: some View {
        VStack {
            DatePicker("Select Time", selection: $selectedDate, displayedComponents: .hourAndMinute)
                .datePickerStyle(WheelDatePickerStyle())
                .onChange(of: selectedDate) { _ in
                    viewModel.updateMatTime(for: selectedDay!, time: formattedSelectedTime)
                }

            Button("Done") {
                showTimePicker = false
            }
            .padding(.top, 10)
        }
    }

    private var formattedSelectedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "hh:mm a"
        return formatter.string(from: selectedDate)
    }

    private func additionalInformationSection(selectedDay: DayOfWeek) -> some View {
        Section(header: Text("Additional Information")) {
            Toggle("Restrictions", isOn: Binding(
                get: { viewModel.restrictionsForDay[selectedDay] ?? false },
                set: { viewModel.restrictionsForDay[selectedDay] = $0 }
            ))
            if viewModel.restrictionsForDay[selectedDay] ?? false {
                TextField("Description", text: Binding(
                    get: { viewModel.restrictionDescriptionForDay[selectedDay] ?? "" },
                    set: { viewModel.restrictionDescriptionForDay[selectedDay] = $0 }
                ))
            }

            Toggle("Good For Beginners", isOn: Binding(
                get: { viewModel.goodForBeginnersForDay[selectedDay] ?? false },
                set: { viewModel.goodForBeginnersForDay[selectedDay] = $0 }
            ))
        }
    }

    private var islandScheduleLinkSection: some View {
        Section {
            if let pIsland = pIsland {
                Group {
                    NavigationLink("View Island Schedule (List)", destination: IslandScheduleView(viewModel: viewModel, pIsland: pIsland))
                    NavigationLink("View Island Schedule (Calendar)", destination: IslandScheduleAsCal(viewModel: viewModel, pIsland: pIsland))
                }
            }
        }
    }


    // MARK: - Actions

    private func saveSchedule(for day: DayOfWeek) {
        guard pIsland != nil else {
            alertMessage = "Error: Selected island is nil."
            showAlert = true
            return
        }

        viewModel.updateSchedulesForSelectedDays()

        if let selectedAppDayOfWeek = selectedAppDayOfWeek {
            selectedAppDayOfWeek.name = viewModel.generateNameForDay(day)
            // Associate the selectedAppDayOfWeek with the pIsland instance if needed
            // Example: selectedAppDayOfWeek.pirateIsland = pIsland
        } else {
            let newAppDay = AppDayOfWeek(context: viewContext)
            newAppDay.name = viewModel.generateNameForDay(day)
            // Associate the newAppDay with the pIsland instance if needed
            // Example: newAppDay.pirateIsland = pIsland
            selectedAppDayOfWeek = newAppDay
        }

        do {
            try viewContext.save()
            showAlert = true
            alertMessage = "Schedule saved successfully for \(day.displayName) at \(viewModel.matTimeForDay[day] ?? "")."
        } catch {
            let nsError = error as NSError
            alertMessage = "Error saving schedule: \(nsError), \(nsError.userInfo)"
            showAlert = true
        }
    }



    // MARK: - Helpers

    private func validateFields() {
        saveEnabled = isSaveEnabled
    }

    private var isSaveEnabled: Bool {
        guard let selectedDay = selectedDay else { return false }
        let matTime = viewModel.matTimeForDay[selectedDay] ?? ""
        let gi = viewModel.giForDay[selectedDay] ?? false
        let noGi = viewModel.noGiForDay[selectedDay] ?? false
        
        return !matTime.isEmpty && (gi || noGi)
    }

    private func resetState() {
        selectedDay = nil
        selectedDate = Date()
        viewModel.selectedDays.removeAll()
    }
}

struct AddOpenMatFormView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext

        let mockIsland = PirateIsland(context: context)
        mockIsland.islandName = "Mock Island"

        let viewModel = AppDayOfWeekViewModel(selectedIsland: mockIsland)

        return AddOpenMatFormView(viewModel: viewModel, selectedAppDayOfWeek: .constant(nil), pIsland: mockIsland)
            .environment(\.managedObjectContext, context)
    }
}
