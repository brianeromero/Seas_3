//
//  AllpIslandScheduleView.swift
//  Seas_3
//
//  Created by Brian Romero on 7/12/24.
//

import Foundation
import SwiftUI

struct AllpIslandScheduleView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \AppDayOfWeek.day, ascending: true)],
        animation: .default)
    private var appDayOfWeeks: FetchedResults<AppDayOfWeek>

    var body: some View {
        List {
            ForEach(appDayOfWeeks) { schedule in
                ForEach(Array(schedule.matTimes as? Set<MatTime> ?? [])) { matTime in
                    ScheduleRow(matTime: matTime)
                }
            }
            .onDelete(perform: deleteItems)
        }
        .navigationTitle("All Island Schedules")
        .navigationBarItems(trailing: EditButton())
    }

    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            offsets.map { appDayOfWeeks[$0] }.forEach(viewContext.delete)
            do {
                try viewContext.save()
            } catch {
                let nsError = error as NSError
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
        }
    }
}

struct AllpIslandScheduleView_Previews: PreviewProvider {
    static var previews: some View {
        AllpIslandScheduleView()
    }
}
