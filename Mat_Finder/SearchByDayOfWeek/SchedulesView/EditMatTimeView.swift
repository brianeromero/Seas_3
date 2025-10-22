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

    let matTime: MatTime
    let onSave: (MatTime) -> Void
    @Environment(\.dismiss) var dismiss // ✅ Correct way to use @Environment(\.dismiss)

    init(matTime: MatTime, onSave: @escaping (MatTime) -> Void) {
        self.matTime = matTime
        self.onSave = onSave
        
        _gi = State(initialValue: matTime.gi)
        _noGi = State(initialValue: matTime.noGi)
        _openMat = State(initialValue: matTime.openMat)
        _restrictions = State(initialValue: matTime.restrictions)
        _restrictionDescription = State(initialValue: matTime.restrictionDescription ?? "")
        _goodForBeginners = State(initialValue: matTime.goodForBeginners)
        _kids = State(initialValue: matTime.kids)
        
        // Parse the matTime.time string into Date using your DateFormat.time formatter
        let parsedDate = DateFormat.time.date(from: matTime.time ?? "") ?? Date()
        _selectedTime = State(initialValue: parsedDate)
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Time")) {
                    DatePicker("Select Time", selection: $selectedTime, displayedComponents: .hourAndMinute)
                        .datePickerStyle(WheelDatePickerStyle()) // Change style if you want
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
                leading: Button("Cancel") {
                    dismiss()
                },
                trailing: Button("Save") {
                    saveChanges()
                }
            )
        }
    }

    private func saveChanges() {
        // Format selectedTime Date to string (e.g., "18:30") using your DateFormat.time
        matTime.time = DateFormat.time.string(from: selectedTime)
        
        matTime.gi = gi
        matTime.noGi = noGi
        matTime.openMat = openMat
        matTime.restrictions = restrictions
        matTime.restrictionDescription = restrictionDescription.isEmpty ? nil : restrictionDescription
        matTime.goodForBeginners = goodForBeginners
        matTime.kids = kids

        onSave(matTime)
        dismiss()    }
}
