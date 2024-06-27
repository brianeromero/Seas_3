//
//  DaysOfWeekFormView.swift
//  Seas_3
//
//  Created by Brian Romero on 6/26/24.
//

import Foundation
import SwiftUI

struct DaysOfWeekFormView: View {
    @ObservedObject var viewModel: AppDayOfWeekViewModel
    @State private var showClassScheduleModal = false
    @State private var showOpenMatModal = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Select Schedule Type")) {
                    Button(action: {
                        self.showClassScheduleModal = true
                    }) {
                        Text("Add Class Schedule")
                    }
                    .sheet(isPresented: $showClassScheduleModal) {
                        AddClassScheduleView(viewModel: self.viewModel)
                    }
                    
                    Button(action: {
                        self.showOpenMatModal = true
                    }) {
                        Text("Add Open Mat")
                    }
                    .sheet(isPresented: $showOpenMatModal) {
                        AddOpenMatFormView(viewModel: self.viewModel)
                    }
                }
            }
            .navigationBarTitle("Add Open Mat Times / Class Schedule", displayMode: .inline)
        }
    }
}

struct DaysOfWeekFormView_Previews: PreviewProvider {
    static var previews: some View {
        DaysOfWeekFormView(viewModel: AppDayOfWeekViewModel())
    }
}
