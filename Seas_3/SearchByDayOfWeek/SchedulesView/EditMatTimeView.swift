//
//  EditMatTimeView.swift
//  Seas_3
//
//  Created by Brian Romero on 5/30/25.
//

import Foundation
import SwiftUI
import CoreData


struct EditMatTimeView: View {
    @State private var time: String
    @State private var gi: Bool
    @State private var noGi: Bool
    @State private var openMat: Bool
    @State private var restrictions: Bool
    @State private var restrictionDescription: String
    @State private var goodForBeginners: Bool
    @State private var kids: Bool
    
    let matTime: MatTime
    let onSave: (MatTime) -> Void
    @Environment(\.presentationMode) var presentationMode

    init(matTime: MatTime, onSave: @escaping (MatTime) -> Void) {
        self.matTime = matTime
        self.onSave = onSave
        // Initialize state with current values from matTime
        _time = State(initialValue: matTime.time ?? "")
        _gi = State(initialValue: matTime.gi)
        _noGi = State(initialValue: matTime.noGi)
        _openMat = State(initialValue: matTime.openMat)
        _restrictions = State(initialValue: matTime.restrictions)
        _restrictionDescription = State(initialValue: matTime.restrictionDescription ?? "")
        _goodForBeginners = State(initialValue: matTime.goodForBeginners)
        _kids = State(initialValue: matTime.kids)
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Time")) {
                    TextField("Time (e.g., 18:30)", text: $time)
                        .keyboardType(.numbersAndPunctuation)
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
            .navigationBarItems(leading: Button("Cancel") {
                presentationMode.wrappedValue.dismiss()
            }, trailing: Button("Save") {
                saveChanges()
            })
        }
    }

    private func saveChanges() {
        // Update the matTime instance with new values
        matTime.time = time
        matTime.gi = gi
        matTime.noGi = noGi
        matTime.openMat = openMat
        matTime.restrictions = restrictions
        matTime.restrictionDescription = restrictionDescription.isEmpty ? nil : restrictionDescription
        matTime.goodForBeginners = goodForBeginners
        matTime.kids = kids

        onSave(matTime)
        presentationMode.wrappedValue.dismiss()
    }
}
