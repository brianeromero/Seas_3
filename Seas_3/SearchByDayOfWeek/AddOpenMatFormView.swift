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

    private let repository: AppDayOfWeekRepository

    init(viewModel: AppDayOfWeekViewModel, selectedAppDayOfWeek: Binding<AppDayOfWeek?>, pIsland: PirateIsland?) {
        self.viewModel = viewModel
        self._selectedAppDayOfWeek = selectedAppDayOfWeek
        self.pIsland = pIsland
        self.repository = AppDayOfWeekRepository(persistence: PersistenceController.shared)
    }

    static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "hh:mm a"
        return formatter
    }()

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
                print("AddOpenMatFormView - onAppear")
                viewModel.fetchCurrentDayOfWeek()
                validateFields()
            }
            .alert(isPresented: $showAlert) {
                Alert(title: Text("Error"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
            }
            .onDisappear {
                print("AddOpenMatFormView - onDisappear")
                resetState()
            }
        }
    }

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
                            print("AddOpenMatFormView - day button tapped: \(day.displayName)")
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
                        print("AddOpenMatFormView - GI toggle changed")
                        validateFields()
                    }

                    Toggle("No GI", isOn: Binding(
                        get: { viewModel.noGiForDay[selectedDay] ?? false },
                        set: { viewModel.noGiForDay[selectedDay] = $0 }
                    ))
                    .onChange(of: viewModel.noGiForDay[selectedDay] ?? false) { _ in
                        print("AddOpenMatFormView - No GI toggle changed")
                        validateFields()
                    }

                    additionalInformationSection(selectedDay: selectedDay)
                }

                Button("Save") {
                    print("AddOpenMatFormView - Save button tapped")
                    saveSchedule()
                }
                .disabled(!saveEnabled)
                .padding(.top, 10)
            }
        }
    }

    private func timePickerSection(selectedDay: DayOfWeek) -> some View {
        VStack {
            DatePicker(
                "Mat Time",
                selection: Binding(
                    get: { viewModel.selectedTimeForDay[selectedDay] ?? Date() },
                    set: {
                        viewModel.selectedTimeForDay[selectedDay] = $0
                        viewModel.updateMatTime(for: selectedDay, time: AddOpenMatFormView.dateFormatter.string(from: $0))
                    }
                ),
                displayedComponents: .hourAndMinute
            )
            .datePickerStyle(WheelDatePickerStyle())
        }
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
    private func saveSchedule() {
        guard let selectedDay = selectedDay else {
            alertMessage = "Error: Please select a day."
            showAlert = true
            return
        }

        guard let pIsland = pIsland else {
            alertMessage = "Error: Selected island is nil."
            showAlert = true
            return
        }

        // Attempt to fetch or create the entity
        if let selectedEntity = repository.fetchOrCreateAppDayOfWeek(for: pIsland, day: selectedDay) {
            // Update matTime
            if let matTime = viewModel.matTimeForDay[selectedDay] {
                selectedEntity.matTime = matTime
                print("Mat Time updated: \(String(describing: selectedEntity.matTime))")
            }
            if let gi = viewModel.giForDay[selectedDay] {
                selectedEntity.gi = gi
                print("GI updated: \(String(describing: selectedEntity.gi))")
            }
            if let noGi = viewModel.noGiForDay[selectedDay] {
                selectedEntity.noGi = noGi
                print("No GI updated: \(String(describing: selectedEntity.noGi))")
            }

            // Check if either day or matTime is nil or empty
            guard let dayName = selectedEntity.day, !dayName.isEmpty else {
                alertMessage = "Error: Day is missing."
                showAlert = true
                return
            }
            
            guard let entityMatTime = selectedEntity.matTime, !entityMatTime.isEmpty else {
                alertMessage = "Error: Mat time is missing."
                showAlert = true
                return
            }

            // Generate the name using the function
            selectedEntity.name = viewModel.generateNameForDay(selectedEntity)

            // Save the entity
            repository.persistence.saveContext()

            // Update the selectedAppDayOfWeek binding
            selectedAppDayOfWeek = selectedEntity
        } else {
            // Handle case where fetchOrCreateAppDayOfWeek returns nil
            alertMessage = "Error: Failed to fetch or create AppDayOfWeek entity."
            showAlert = true
        }

        resetState()
    }

    private func validateFields() {
        guard let selectedDay = selectedDay else {
            saveEnabled = false
            return
        }

        saveEnabled = !(viewModel.matTimeForDay[selectedDay] ?? "").isEmpty
        saveEnabled = saveEnabled && ((viewModel.giForDay[selectedDay] ?? false) || (viewModel.noGiForDay[selectedDay] ?? false))
    }

    private func resetState() {
        selectedDay = nil
        selectedDate = Date()
        viewModel.clearSelections()
        print("AddOpenMatFormView - Resetting state")
    }
}

// MARK: - Preview

struct AddOpenMatFormView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext
        let island = PirateIsland(context: context)
        island.name = "Sample Island"

        return AddOpenMatFormView(
            viewModel: AppDayOfWeekViewModel(selectedIsland: island, repository: AppDayOfWeekRepository(persistence: PersistenceController.preview)),
            selectedAppDayOfWeek: .constant(nil),
            pIsland: island
        )
    }
}
