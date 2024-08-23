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
    @Binding var selectedDay: DayOfWeek
    @Binding var daySelected: Bool
    @State var matTime: MatTime?
    @State private var isMatTimeSet: Bool = false
    @State private var showAlert: Bool = false
    @State private var alertTitle: String = ""
    @State private var alertMessage: String = ""

    @State private var selectedTime: Date = Date()
    @State private var restrictionDescriptionInput: String = ""

    // Define state properties for toggles
    @State private var gi: Bool = false
    @State private var noGi: Bool = false
    @State private var openMat: Bool = false
    @State private var goodForBeginners: Bool = false
    @State private var kids: Bool = false
    @State private var restrictions: Bool = false

    @ObservedObject var viewModel: AppDayOfWeekViewModel

    var body: some View {
        Section(header: Text("Add New Mat Time")) {
            VStack(alignment: .leading) {
                DatePicker("Select Time", selection: $selectedTime, displayedComponents: .hourAndMinute)
                    .onChange(of: selectedTime) { newValue in
                        isMatTimeSet = true
                    }

                ToggleView(title: "Gi", isOn: $gi)
                ToggleView(title: "No Gi", isOn: $noGi)
                ToggleView(title: "Open Mat", isOn: $openMat)
                ToggleView(title: "Good for Beginners", isOn: $goodForBeginners)
                ToggleView(title: "Kids", isOn: $kids)
                ToggleView(title: "Restrictions", isOn: $restrictions)

                if restrictions {
                    TextField("Restriction Description", text: $restrictionDescriptionInput)
                }

                if !daySelected {
                    Text("Please select a day.")
                        .foregroundColor(.red)
                }

                Button(action: {
                    if daySelected && isMatTimeSet && selectedAppDayOfWeek != nil && (gi || noGi || openMat) {
                        // Create a new MatTime object here
                        self.matTime = MatTime(context: self.viewModel.viewContext)
                        self.matTime?.createdTimestamp = Date()
                        self.matTime?.time = self.formatDateToString(selectedTime)
                        self.matTime?.restrictionDescription = restrictionDescriptionInput
                        self.matTime?.gi = gi
                        self.matTime?.noGi = noGi
                        self.matTime?.openMat = openMat
                        self.matTime?.goodForBeginners = goodForBeginners
                        self.matTime?.kids = kids
                        self.matTime?.restrictions = restrictions

                        // Add to AppDayOfWeek
                        if let appDayOfWeek = selectedAppDayOfWeek {
                            appDayOfWeek.addToMatTimes(matTime!)
                            viewModel.saveContext()
                        }
                        
                        // Reset state variables after saving
                        self.selectedTime = Date()
                        self.gi = false
                        self.noGi = false
                        self.openMat = false
                        self.goodForBeginners = false
                        self.kids = false
                        self.restrictions = false
                        self.restrictionDescriptionInput = ""
                        self.isMatTimeSet = false
                    } else {
                        alertTitle = "Error"
                        alertMessage = "Please select a day, time, and at least one type."
                        showAlert = true
                    }
                }) {
                    Text("Add New Mat Time")
                }
                .disabled(!(daySelected && isMatTimeSet && selectedAppDayOfWeek != nil && (gi || noGi || openMat)))
            }
        }
    }

    func binding(_ keyPath: WritableKeyPath<MatTime, Bool>) -> Binding<Bool> {
        return Binding(
            get: { matTime?[keyPath: keyPath] ?? false },
            set: { if var matTime = self.matTime { matTime[keyPath: keyPath] = $0; self.matTime = matTime } }
        )
    }

    func formatDateToString(_ date: Date) -> String {
        return DateFormat.time.string(from: date)
    }

    func stringToDate(_ string: String) -> Date? {
        return DateFormat.time.date(from: string)
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
}
