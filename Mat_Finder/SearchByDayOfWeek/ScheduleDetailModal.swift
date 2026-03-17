//  ScheduleDetailModal.swift
//  Mat_Finder
//
//  Created by Brian Romero on 7/8/24.
//

import SwiftUI
import SwiftUI

struct ScheduleDetailModal: View {

    @ObservedObject var viewModel: AppDayOfWeekViewModel
    var day: DayOfWeek

    var body: some View {

        VStack(alignment: .leading) {

            Text(day.ultraShortDisplayName)
                .font(.largeTitle)
                .bold()
                .padding(.bottom)

            ForEach(viewModel.appDayOfWeekList.filter { $0.day == day.rawValue }, id: \.objectID) { schedule in

                let matTimes = (schedule.matTimes?.allObjects as? [MatTime] ?? [])
                    .sorted(by: MatTime.scheduleSort)

                ForEach(matTimes, id: \.objectID) { matTime in
                    scheduleView(for: matTime)
                }
            }
        }
        .padding()
        .navigationBarTitle("Schedule Details", displayMode: .inline)
    }


    // MARK: - Schedule Row
    func scheduleView(for matTime: MatTime) -> some View {

        VStack(alignment: .leading, spacing: 8) {

            HStack {

                Text(matTime.formattedHeader(includeDay: false))
                    .font(.subheadline)
                    .foregroundColor(.primary)

                Spacer()

                if matTime.goodForBeginners {
                    Text("Beginner")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }


            // NEW: badge system from MatTime+Extensions
            HStack(spacing: 6) {

                ForEach(matTime.badges) { badge in
                    Text(badge.text)
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color(badge.color))
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                }
            }


            if matTime.restrictions {
                Text("Restrictions: \(matTime.restrictionDescription ?? "Yes")")
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(8)
    }
}
