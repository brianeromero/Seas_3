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

    @State private var discipline: Discipline

    @State private var restrictions: Bool
    @State private var restrictionDescription: String
    @State private var goodForBeginners: Bool
    @State private var kids: Bool
    @State private var womensOnly: Bool
    @State private var selectedTime: Date

    @State private var showSuccessAlert = false
    
    @State private var style: Style?
    @State private var customStyle: String
    
    let matTime: MatTime
    let viewModel: AppDayOfWeekViewModel

    @Environment(\.dismiss) var dismiss

    init(matTime: MatTime, viewModel: AppDayOfWeekViewModel) {

        self.matTime = matTime
        self.viewModel = viewModel

        let loadedDiscipline =
            Discipline(rawValue: matTime.discipline ?? "") ?? .bjjGi

        _discipline = State(initialValue: loadedDiscipline)
        
        let loadedStyle: Style?

        if let styleString = matTime.style,
           let parsed = Style(rawValue: styleString) {
            loadedStyle = parsed
        }
        else if let custom = matTime.customStyle, !custom.isEmpty {
            loadedStyle = .custom
        }
        else {
            loadedStyle = nil
        }

        _style = State(initialValue: loadedStyle)

        _customStyle = State(initialValue: matTime.customStyle ?? "")

 

        _restrictions = State(initialValue: matTime.restrictions)
        _restrictionDescription = State(initialValue: matTime.restrictionDescription ?? "")
        _goodForBeginners = State(initialValue: matTime.goodForBeginners)
        _kids = State(initialValue: matTime.kids)
        _womensOnly = State(initialValue: matTime.womensOnly)

        let parsedDate: Date

        if let timeString = matTime.time,
           let date = AppDateFormatter.stringToDate(timeString) {

            let calendar = Calendar.current
            let nowComponents = calendar.dateComponents([.year,.month,.day], from: Date())
            let timeComponents = calendar.dateComponents([.hour,.minute], from: date)

            parsedDate = calendar.date(
                bySettingHour: timeComponents.hour ?? 0,
                minute: timeComponents.minute ?? 0,
                second: 0,
                of: calendar.date(from: nowComponents)!
            ) ?? Date()

        } else {
            parsedDate = Date()
        }

        _selectedTime = State(initialValue: parsedDate)
    }

    var body: some View {

        NavigationStack {

            Form {

                Section("Time") {

                    DatePicker(
                        "Select Time",
                        selection: $selectedTime,
                        displayedComponents: .hourAndMinute
                    )
                    .datePickerStyle(.wheel)
                }

                Section("Discipline") {

                    DisciplinePicker(discipline: $discipline)

                    StylePicker(
                        style: $style,
                        discipline: $discipline,
                        customStyle: $customStyle
                    )
                }
 

                Section("Restrictions") {

                    Toggle("Restrictions", isOn: $restrictions)

                    if restrictions {

                        TextField(
                            "Restriction Description",
                            text: $restrictionDescription
                        )
                    }
                }

                Section("Additional Info") {

                    Toggle("Good for Beginners", isOn: $goodForBeginners)
                    Toggle("Kids Class", isOn: $kids)
                    Toggle("Women’s Class", isOn: $womensOnly)
                }

            }
            .navigationTitle("Edit Mat Time")

            .toolbar {

                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") { saveChanges() }
                }
            }

            .alert("Mat Time Updated", isPresented: $showSuccessAlert) {

                Button("OK") { dismiss() }

            } message: {

                Text("Your changes were saved successfully.")
            }

            .onChange(of: style) { _, newStyle in
                if newStyle != .custom {
                    customStyle = ""
                }
            }
        }
    }

    private func saveChanges() {

        matTime.time =
            AppDateFormatter.twelveHour.string(from: selectedTime)

        matTime.discipline = discipline.rawValue

        if style == .custom {

            let trimmed = customStyle.trimmingCharacters(in: .whitespacesAndNewlines)

            if trimmed.isEmpty {
                matTime.style = ""
                matTime.customStyle = ""
            } else {
                matTime.style = trimmed
                matTime.customStyle = trimmed
            }

        } else if let style {

            matTime.style = style.rawValue
            matTime.customStyle = ""

        } else {

            matTime.style = ""
            matTime.customStyle = ""
        }

        matTime.gi = discipline == .bjjGi
        matTime.noGi = discipline == .bjjNoGi
        matTime.openMat = style == .openMat

        matTime.restrictions = restrictions
        matTime.restrictionDescription =
            restrictionDescription.isEmpty ? nil : restrictionDescription

        matTime.goodForBeginners = goodForBeginners
        matTime.kids = kids
        matTime.womensOnly = womensOnly

        Task {
            do {
                try await viewModel.updateMatTime(matTime)

                await MainActor.run {
                    showSuccessAlert = true
                }

            } catch {
                print("Failed to update MatTime:", error.localizedDescription)
            }
        }
    }
}
