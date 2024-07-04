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
    @Binding var pIsland: PirateIsland?
    @Binding var goodForBeginners: String
    @Binding var matTime: String?
    @Binding var openMat: Bool
    @Binding var restrictions: Bool
    @Binding var restrictionDescription: String?
    @Binding var name: String?

    @State private var showAlert = false
    @State private var alertMessage = ""

    private var isSaveEnabled: Bool {
        guard let island = pIsland else { return false }
        return !goodForBeginners.isEmpty && (matTime ?? "").isEmpty == false
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Select Schedule and Details")) {
                    TextField("Time", text: Binding<String>(
                        get: { matTime ?? "" },
                        set: { matTime = $0 }
                    ))
                    .onChange(of: matTime ?? "") { _ in validateFields() }

                    TextField("Details", text: $goodForBeginners)
                    .onChange(of: goodForBeginners) { _ in validateFields() }
                }

                Section(header: Text("More Details")) {
                    Toggle("Restrictions", isOn: $restrictions)
                    if restrictions {
                        TextField("Description", text: Binding<String>(
                            get: { restrictionDescription ?? "" },
                            set: { restrictionDescription = $0 }
                        ))
                        .onChange(of: restrictionDescription ?? "") { _ in validateFields() }
                    }
                }

                Section(header: Text("Name (if applicable)")) {
                    TextField("Name", text: Binding<String>(
                        get: { name ?? "" },
                        set: { name = $0 }
                    ))
                    .onChange(of: name ?? "") { _ in validateFields() }
                }
            }
            .navigationBarTitle("Add Open Mat", displayMode: .inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveSchedule()
                    }
                    .disabled(!isSaveEnabled)
                }
            }
            .alert(isPresented: $showAlert) {
                Alert(title: Text("Error"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
            }
        }
        .onAppear {
            validateFields() // Initial validation check
        }
    }

    private func saveSchedule() {
        guard let island = pIsland else {
            print("Error: Selected island is nil.")
            return
        }

        // Ensure selectedAppDayOfWeek is set correctly
        guard let selectedAppDayOfWeek = selectedAppDayOfWeek else {
            print("Error: Selected AppDayOfWeek is nil.")
            return
        }

        // Get the display name of the day of the week
        let dayOfWeekName = selectedAppDayOfWeek.dayOfWeek ?? ""

        // Save the schedule details
        let newAppDayOfWeek = PersistenceController.shared.createAppDayOfWeek(
            pIsland: island,
            dayOfWeek: dayOfWeekName,
            matTime: matTime,
            gi: viewModel.gi, // Access gi through viewModel
            noGi: viewModel.noGi, // Access noGi through viewModel
            openMat: openMat,
            restrictions: restrictions,
            restrictionDescription: restrictionDescription
        )

        // Optionally do something with newAppDayOfWeek

        // Close the form or perform any other action upon saving
        showAlert = true
        alertMessage = "Schedule saved successfully."
    }

    private func validateFields() {
        // Implement validation logic if needed
    }
}

struct AddOpenMatFormView_Previews: PreviewProvider {
    static var previews: some View {
        // Create a mock selectedAppDayOfWeek and selectedIsland
        let context = PersistenceController.preview.container.viewContext
        let mockAppDayOfWeek = AppDayOfWeek(context: context)
        mockAppDayOfWeek.dayOfWeek = "Monday" // Set the dayOfWeek property
        let mockIsland = PirateIsland(context: context)
        mockIsland.islandName = "Mock Island"
        mockIsland.islandLocation = "Mock Location"
        mockIsland.latitude = 0.0
        mockIsland.longitude = 0.0
        mockIsland.gymWebsite = URL(string: "https://mockisland.com")
        
        // Create a mock AppDayOfWeekViewModel with mockIsland
        let viewModel = AppDayOfWeekViewModel(selectedIsland: mockIsland)
        viewModel.gi = true // Example assignment
        viewModel.noGi = false // Example assignment
        
        // Provide constant bindings for selectedAppDayOfWeek and selectedIsland
        return AddOpenMatFormView(
            viewModel: viewModel,
            selectedAppDayOfWeek: .constant(mockAppDayOfWeek),
            pIsland: .constant(mockIsland),
            goodForBeginners: .constant(""),
            matTime: .constant(nil),
            openMat: .constant(false),
            restrictions: .constant(false),
            restrictionDescription: .constant(nil),
            name: .constant(nil)
        )
        .environment(\.managedObjectContext, context)
    }
}

