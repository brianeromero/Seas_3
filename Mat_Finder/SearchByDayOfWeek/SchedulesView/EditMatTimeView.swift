//
//  EditMatTimeView.swift
//  Mat_Finder
//
//  Created by Brian Romero on 5/30/25.
//

import Foundation
import SwiftUI
import CoreData

struct EditMatTimeView: View {
    @State private var gi: Bool
    @State private var noGi: Bool
    @State private var openMat: Bool
    @State private var restrictions: Bool
    @State private var restrictionDescription: String
    @State private var goodForBeginners: Bool
    @State private var kids: Bool
    @State private var selectedTime: Date

    // NEW: Success alert flag
    @State private var showSuccessAlert = false

    let matTime: MatTime
    let viewModel: AppDayOfWeekViewModel   // <<< Inject the view model
    @Environment(\.dismiss) var dismiss

    init(matTime: MatTime, viewModel: AppDayOfWeekViewModel) {
        self.matTime = matTime
        self.viewModel = viewModel

        _gi = State(initialValue: matTime.gi)
        _noGi = State(initialValue: matTime.noGi)
        _openMat = State(initialValue: matTime.openMat)
        _restrictions = State(initialValue: matTime.restrictions)
        _restrictionDescription = State(initialValue: matTime.restrictionDescription ?? "")
        _goodForBeginners = State(initialValue: matTime.goodForBeginners)
        _kids = State(initialValue: matTime.kids)

        let parsedDate = DateFormat.time.date(from: matTime.time ?? "") ?? Date()
        _selectedTime = State(initialValue: parsedDate)
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Time")) {
                    DatePicker("Select Time", selection: $selectedTime, displayedComponents: .hourAndMinute)
                        .datePickerStyle(WheelDatePickerStyle())
                }

                Section(header: Text("Class Types")) {
                    Toggle("Gi", isOn: $gi)
                    Toggle("NoGi", isOn: $noGi)
                    Toggle("Open Mat", isOn: $openMat)
                }

                Section(header: Text("Restrictions")) {
                    Toggle("Restrictions", isOn: $restrictions)
                    if restrictions {
                        TextField("Restriction Description", text: $restrictionDescription)
                    }
                }

                Section(header: Text("Additional Info")) {
                    Toggle("Good for Beginners", isOn: $goodForBeginners)
                    Toggle("Kids Class", isOn: $kids)
                }
            }
            .navigationTitle("Edit Mat Time")
            .navigationBarItems(
                leading: Button("Cancel") { dismiss() },
                trailing: Button("Save") { saveChanges() }
            )
            .alert("Mat Time Updated", isPresented: $showSuccessAlert) {
                Button("OK") { dismiss() }
            } message: {
                Text("Your changes were saved successfully.")
            }
        }
    }

    private func saveChanges() {
        // Update local MatTime properties
        matTime.time = DateFormat.time.string(from: selectedTime)
        matTime.gi = gi
        matTime.noGi = noGi
        matTime.openMat = openMat
        matTime.restrictions = restrictions
        matTime.restrictionDescription = restrictionDescription.isEmpty ? nil : restrictionDescription
        matTime.goodForBeginners = goodForBeginners
        matTime.kids = kids

        // Call the viewModel to update Core Data & Firestore
        Task {
            do {
                try await viewModel.updateMatTime(matTime)
                await MainActor.run {
                    self.showSuccessAlert = true
                }
            } catch {
                await MainActor.run {
                    // Handle error as needed
                    print("Failed to update MatTime: \(error.localizedDescription)")
                }
            }
        }
    }
}
