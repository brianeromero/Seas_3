//
//  ScheduleDetailModal.swift
//  Seas_3
//
//  Created by Brian Romero on 7/8/24.
//

import Foundation
import SwiftUI

struct ScheduleDetailModal: View {
    @ObservedObject var viewModel: AppDayOfWeekViewModel
    var day: DayOfWeek

    var body: some View {
        VStack(alignment: .leading) {
            Text(day.displayName)
                .font(.largeTitle)
                .bold()
                .padding(.bottom)

            ForEach(viewModel.appDayOfWeekList.filter { $0.day == day.rawValue }, id: \.self) { schedule in
                scheduleView(for: schedule)
            }
        }
        .padding()
        .navigationBarTitle("Schedule Details", displayMode: .inline)
    }

    private func scheduleView(for schedule: AppDayOfWeek) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(schedule.matTime ?? "Unknown time")
                    .font(.subheadline)
                    .foregroundColor(.primary)
                Spacer()
                Text(schedule.goodForBeginners ? "Beginners" : "")
                    .font(.caption)
                    .foregroundColor(.green)
            }
            HStack {
                Label("Gi", systemImage: schedule.gi ? "checkmark.circle.fill" : "xmark.circle")
                    .foregroundColor(schedule.gi ? .green : .red)
                Label("NoGi", systemImage: schedule.noGi ? "checkmark.circle.fill" : "xmark.circle")
                    .foregroundColor(schedule.noGi ? .green : .red)
                Label("Open Mat", systemImage: schedule.openMat ? "checkmark.circle.fill" : "xmark.circle")
                    .foregroundColor(schedule.openMat ? .green : .red)
            }
            if schedule.restrictions {
                Text("Restrictions: \(schedule.restrictionDescription ?? "Yes")")
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(8)
    }
}


struct ScheduleDetailModal_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext
        let viewModel = AppDayOfWeekViewModel(selectedIsland: nil)

        // Mock data for a specific day
        let mockSchedule1 = AppDayOfWeek(context: context)
        mockSchedule1.day = DayOfWeek.monday.displayName
        mockSchedule1.matTime = "10:00 AM"
        mockSchedule1.gi = true
        mockSchedule1.noGi = false
        mockSchedule1.openMat = true
        mockSchedule1.restrictions = false
        mockSchedule1.restrictionDescription = nil
        mockSchedule1.goodForBeginners = true

        let mockSchedule2 = AppDayOfWeek(context: context)
        mockSchedule2.day = DayOfWeek.monday.displayName
        mockSchedule2.matTime = "12:00 PM"
        mockSchedule2.gi = false
        mockSchedule2.noGi = true
        mockSchedule2.openMat = false
        mockSchedule2.restrictions = true
        mockSchedule2.restrictionDescription = "No kids allowed"
        mockSchedule2.goodForBeginners = false

        viewModel.appDayOfWeekList = [mockSchedule1, mockSchedule2]

        return NavigationView {
            ScheduleDetailModal(viewModel: viewModel, day: .monday)
                .environment(\.managedObjectContext, context)
        }
    }
}
