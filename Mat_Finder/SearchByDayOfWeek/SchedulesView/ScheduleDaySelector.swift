//
//  ScheduleDaySelector.swift
//  Mat_Finder
//
//  Created by Brian Romero on 2/23/26.
//

import SwiftUI

struct ScheduleDaySelector: View {

    let island: PirateIsland?

    @Binding var selectedDay: DayOfWeek?

    @ObservedObject var viewModel: AppDayOfWeekViewModel


    var body: some View {

        HStack(spacing: 12) {

            ForEach(DayOfWeek.allCases.sorted(), id: \.self) { day in

                Button {

                    withAnimation(.easeInOut(duration: 0.18)) {

                        selectedDay = day
                        viewModel.selectedDay = day

                    }

                } label: {

                    VStack(spacing: 4) {

                        Text(day.shortDisplayName)
                            .font(.footnote.weight(.semibold))

                        Circle()
                            .fill(
                                hasSchedule(day)
                                ? Color.accentColor
                                : Color.clear
                            )
                            .frame(width: 6, height: 6)
                            .animation(.easeInOut(duration: 0.18),
                                       value: hasSchedule(day))

                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)

                    .background(
                        selectedDay == day
                        ? Color.accentColor.opacity(0.15)
                        : Color.clear
                    )
                    .animation(.easeInOut(duration: 0.18),
                               value: selectedDay)

                    .clipShape(RoundedRectangle(cornerRadius: 10))

                }
                .buttonStyle(.plain)

            }

        }

    }


    private func hasSchedule(_ day: DayOfWeek) -> Bool {

        guard let times = viewModel.matTimesForDay[day] else {
            return false
        }

        return !times.isEmpty

    }

}
