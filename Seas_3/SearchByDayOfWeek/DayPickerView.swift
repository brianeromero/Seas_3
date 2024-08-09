//
//  DayPickerView.swift
//  Seas_3
//
//  Created by Brian Romero on 7/16/24.
//

import Foundation
import SwiftUI

struct DayPickerView: View {
    @Binding var selectedDay: DayOfWeek?
    @Binding var daySelected: Bool

    var body: some View {
        VStack {
            Text("Select a Day")
                .font(.headline)

            HStack {
                ForEach(DayOfWeek.allCases) { day in
                    Button(action: {
                        selectedDay = day
                        daySelected = true
                    }) {
                        Text(day.displayName)
                            .padding()
                            .background(selectedDay == day ? Color.blue : Color.clear)
                            .cornerRadius(8)
                            .foregroundColor(selectedDay == day ? .white : .primary)
                    }
                }
            }
        }
    }
}
