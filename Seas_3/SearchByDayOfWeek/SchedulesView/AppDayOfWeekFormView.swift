//
//  AppDayOfWeekFormView.swift
//  Seas_3
//
//  Created by Brian Romero on 7/30/24.
//

import Foundation
import SwiftUI
import CoreData
import FirebaseFirestore

struct AppDayOfWeekFormView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var day: String = ""
    @State private var name: String = ""
    @State private var appDayOfWeekID: String = ""
    @State private var selectedIsland: PirateIsland?
    @State private var matTimes: [MatTime] = []
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \PirateIsland.islandName, ascending: true)],
        animation: .default
    ) private var islands: FetchedResults<PirateIsland>
    
    @ObservedObject var viewModel: AppDayOfWeekViewModel

    
    var body: some View {
        Form {
            Section(header: Text("Day Information")) {
                TextField("Day", text: $day)
                TextField("Name", text: $name)
                TextField("App Day of Week ID", text: $appDayOfWeekID)
                
                Picker("Select D Gym", selection: $selectedIsland) {
                    ForEach(islands, id: \.self) { island in
                        Text(island.islandName ?? "Unknown Gym").tag(island as PirateIsland?)
                    }
                }
            }
            
            Section(header: Text("MatTimes")) {
                // You can implement a more advanced MatTime management UI here
                // For simplicity, this example doesn't include that part
                Text("Add and manage MatTimes here")
            }
            
            Button("Save") {
                viewModel.saveAppDayOfWeek()
            }
        }
    }
    
    private func saveAppDayOfWeekLocally() {
        let newAppDayOfWeek = AppDayOfWeek(context: viewContext)
        newAppDayOfWeek.day = day
        newAppDayOfWeek.name = name
        newAppDayOfWeek.appDayOfWeekID = appDayOfWeekID
        newAppDayOfWeek.pIsland = selectedIsland
        
        // Add MatTimes if needed
        matTimes.forEach { matTime in
            newAppDayOfWeek.addToMatTimes(matTime)
        }
        
        do {
            try viewContext.save()
        } catch {
            print("Failed to save AppDayOfWeek locally: \(error.localizedDescription)")
        }
    }
    

}

struct AppDayOfWeekFormView_Previews: PreviewProvider {
    static var previews: some View {
        let repository = AppDayOfWeekRepository(persistenceController: PersistenceController.preview)
        let enterZipCodeViewModel = EnterZipCodeViewModel(repository: repository, persistenceController: PersistenceController.preview)
        AppDayOfWeekFormView(viewModel: AppDayOfWeekViewModel(repository: repository, enterZipCodeViewModel: enterZipCodeViewModel))
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
