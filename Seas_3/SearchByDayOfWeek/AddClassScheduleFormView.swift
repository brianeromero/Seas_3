//
//  AddClassScheduleFormView.swift
//  Seas_3
//
//  Created by Brian Romero on 6/26/24.
//

import Foundation
import SwiftUI


struct AddClassScheduleView: View {
    @ObservedObject var viewModel: AppDayOfWeekViewModel

    // Computed property to determine if the Save button should be enabled
    private var isSaveEnabled: Bool {
        return viewModel.isFormValid
    }

    var body: some View {
        NavigationView {
            Form {
                // Days of Week Section
                Section(header: Text("Days of Week")) {
                    ForEach(viewModel.daysOfWeek, id: \.self) { day in
                        Toggle(day.displayName, isOn: viewModel.binding(for: day))
                    }
                }
                
                // Time per Day Section
                Section(header: Text("Time per Day")) {
                    TextField("Enter Time (e.g., 7:00 PM)", text: $viewModel.matTime)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .keyboardType(.asciiCapable)
                        .onChange(of: viewModel.matTime) { newValue in
                            viewModel.validateTime()
                        }
                }

                // Gi or NoGi Section
                giOrNoGiSection
                
                // Open to All Levels Section
                Section(header: Text("Open to All Levels")) {
                    Toggle("Open to All Levels", isOn: $viewModel.goodForBeginners)
                }
                
                // Restrictions Section
                Section(header: Text("Restrictions")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("e.g. White Gis Only")
                            .foregroundColor(.secondary)
                        Text("Must Wear Rashguard underneath...")
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 8)
                    
                    Toggle("Any Restrictions?", isOn: $viewModel.restrictions.animation())
                    
                    if viewModel.restrictions {
                        TextField("Description", text: $viewModel.restrictionDescription)
                    }
                }
                
                // Save Button Section
                Button("Save") {
                    viewModel.saveDayOfWeek()
                }
                .disabled(!isSaveEnabled)
            }
            .navigationBarTitle("Add Open Mat Times / Class Schedule", displayMode: .inline)
        }
    }
    
    private var giOrNoGiSection: some View {
        Section(header: Text("Gi or NoGi")) {
            Toggle("Gi", isOn: $viewModel.gi.animation())
            Toggle("NoGi", isOn: $viewModel.noGi.animation())
        }
    }
}

struct AddClassScheduleView_Previews: PreviewProvider {
    static var previews: some View {
        AddClassScheduleView(viewModel: AppDayOfWeekViewModel())
    }
}
