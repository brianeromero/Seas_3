//
//  AddClassScheduleView.swift
//  Seas_3
//
//  Created by Brian Romero on 6/26/24.
//

import SwiftUI

struct AddClassScheduleView: View {
    @ObservedObject var viewModel: AppDayOfWeekViewModel
    @Binding var selectedAppDayOfWeek: AppDayOfWeek?
    var pIsland: PirateIsland
    @Environment(\.presentationMode) var presentationMode
    
    @State private var selectedDay: DayOfWeek = .monday
    @State private var matTime: String = ""
    @State private var gi: Bool = false
    @State private var noGi: Bool = false
    @State private var openMat: Bool = false
    @State private var restrictions: Bool = false
    @State private var restrictionDescription: String = ""
    @State private var goodForBeginners: Bool = false
    @State private var adult: Bool = false

    var body: some View {
        VStack {
            Text("Select Day:")
            Picker("Day", selection: $selectedDay) {
                ForEach(DayOfWeek.allCases, id: \.self) { day in
                    Text(day.displayName).tag(day)
                }
            }
            .pickerStyle(MenuPickerStyle())

            Form {
                Section(header: Text("Class Schedule Details")) {
                    TextField("Mat Time", text: $matTime)
                        .keyboardType(.numbersAndPunctuation)
                    Toggle("Gi", isOn: $gi)
                    Toggle("No-Gi", isOn: $noGi)
                    Toggle("Good for Beginners", isOn: $goodForBeginners)
                    Toggle("Open Mat", isOn: $openMat)
                    Toggle("Restrictions", isOn: $restrictions)
                    if restrictions {
                        TextField("Restriction Description", text: $restrictionDescription)
                    }
                    Toggle("Adult", isOn: $adult)
                }
            }
            .navigationTitle("Add Class Schedule")
            .navigationBarItems(trailing:
                Button("Save") {
                    saveAction()
                }
            )
        }
    }
    
    private func saveAction() {
        // Validate matTime to ensure it is not empty
        guard !matTime.isEmpty else {
            // Optionally, show an alert to the user about the empty matTime
            return
        }

        // Create a MatTime tuple
        let matTimeEntry = (time: matTime,
                            type: "",  // Adjust if needed
                            gi: gi,
                            noGi: noGi,
                            openMat: openMat,
                            restrictions: restrictions,
                            restrictionDescription: restrictionDescription.isEmpty ? nil : restrictionDescription,
                            goodForBeginners: goodForBeginners,
                            adult: adult)

        // Call the method to add MatTimes for the selected day
        viewModel.addMatTimesForDay(day: selectedDay, matTimes: [matTimeEntry], for: pIsland)
        
        // Dismiss the view
        presentationMode.wrappedValue.dismiss()
    }


}

struct AddClassScheduleView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.shared.container.viewContext

        let previewIsland = PirateIsland(context: context)
        previewIsland.islandName = "Sample Island"

        let viewModel = AppDayOfWeekViewModel(
            selectedIsland: previewIsland
        )

        return AddClassScheduleView(
            viewModel: viewModel,
            selectedAppDayOfWeek: .constant(nil),
            pIsland: previewIsland
        )
        .environment(\.managedObjectContext, context)
    }
}
