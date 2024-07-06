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
                                    get: { viewModel.matTime ?? "" },
                                    set: { newValue in viewModel.matTime = newValue }
                                ))
                                .onTapGesture {
                                    showTimePicker = true
                                }
                                .sheet(isPresented: $showTimePicker) {
                                    VStack {
                                        DatePicker("Select Time", selection: $selectedTime, displayedComponents: .hourAndMinute)
                                            .datePickerStyle(WheelDatePickerStyle())
                                            .onChange(of: selectedTime) { newValue in
                                                viewModel.matTime = DateFormatter.localizedString(from: newValue, dateStyle: .none, timeStyle: .short)
                                                validateFields()
                                                showTimePicker = false
                                            }
                                        Button("Done") {
                                            showTimePicker = false
                                        }
                                        .padding(.top, 10)
                                    }
                                }

                                Toggle("Open Mat", isOn: $viewModel.openMat)
                                Toggle("GI", isOn: $viewModel.gi)
                                Toggle("No GI", isOn: $viewModel.noGi)

                                // Section: Additional Information
                                Section(header: Text("Additional Information")) {
                                    Toggle("Restrictions", isOn: $viewModel.restrictions)
                                    if viewModel.restrictions {
                                        TextField("Description", text: Binding<String>(
                                            get: { viewModel.restrictionDescription ?? "" },
                                            set: { newValue in viewModel.restrictionDescription = newValue }
                                        ))
                                        .onChange(of: viewModel.restrictionDescription ?? "") { _ in
                                            validateFields()
                                        }
                                    }

                                    Toggle("Good For Beginners", isOn: $viewModel.goodForBeginners)

                                    TextField("Name", text: Binding<String>(
                                        get: { viewModel.name ?? "" },
                                        set: { newValue in viewModel.name = newValue }
                                    ))
                                    .onChange(of: viewModel.name ?? "") { _ in
                                        validateFields()
                                    }
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
            viewModel.fetchDayDetails(for: selectedDay ?? .monday) // Initial validation check
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

        _ = PersistenceController.shared.createAppDayOfWeek(
            pIsland: island,
            dayOfWeek: day.displayName,
            matTime: viewModel.matTime,
            gi: viewModel.gi,
            noGi: viewModel.noGi,
            openMat: viewModel.openMat,
            restrictions: viewModel.restrictions,
            restrictionDescription: viewModel.restrictionDescription
        )

        showAlert = true
        alertMessage = "Schedule saved successfully for \(day.displayName) at \(viewModel.matTime ?? "")."
    }

    private func validateFields() {
        saveEnabled = isSaveEnabled
    }

    private var isSaveEnabled: Bool {
        guard let matTime = viewModel.matTime, !matTime.isEmpty,
              (viewModel.gi || viewModel.noGi), selectedDay != nil else {
            return false
        }
        return true
    }

    private func resetState() {
        selectedDay = nil
        viewModel.matTime = nil
        viewModel.openMat = false
        viewModel.gi = false
        viewModel.noGi = false
        viewModel.restrictions = false
        viewModel.restrictionDescription = nil
        viewModel.goodForBeginners = false
        viewModel.name = nil
    }
}


struct AddOpenMatFormView_Previews: PreviewProvider {
    static var previews: some View {
        // Create a mock selectedAppDayOfWeek and selectedIsland
        let context = PersistenceController.preview.container.viewContext
        let mockAppDayOfWeek = AppDayOfWeek(context: context)
        mockAppDayOfWeek.day = "Monday" // Ensure dayOfWeek is set as a String

        // Ensure pIsland is optional for the preview
        let mockIsland = PirateIsland(context: context)
        mockIsland.islandName = "Mock Island"
        mockIsland.islandLocation = "Mock Location"
        mockIsland.latitude = 0.0
        mockIsland.longitude = 0.0
        mockIsland.gymWebsite = URL(string: "")

        // Create a mock AppDayOfWeekViewModel with mockIsland
        let viewModel = AppDayOfWeekViewModel(selectedIsland: mockIsland)

        // Provide constant bindings for selectedAppDayOfWeek and selectedIsland
        return AddOpenMatFormView(
            viewModel: viewModel,
            selectedAppDayOfWeek: .constant(mockAppDayOfWeek),
            pIsland: mockIsland
        )
        .environment(\.managedObjectContext, context)
    }
}
