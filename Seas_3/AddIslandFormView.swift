//  AddIslandFormView.swift
//  Seas_3
//
//  Created by Brian Romero on 6/26/24.
//

import SwiftUI
import CoreData
import Combine
import CoreLocation
import Foundation

struct AddIslandFormView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.presentationMode) private var presentationMode

    @Binding var islandName: String
    @Binding var street: String
    @Binding var city: String
    @Binding var state: String
    @Binding var zip: String
    @Binding var createdByUserId: String
    @Binding var gymWebsite: String
    @Binding var gymWebsiteURL: URL?
    @State private var isSaveEnabled = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @ObservedObject var pirateIslandViewModel: PirateIslandViewModel


    init(
        islandName: Binding<String>,
        street: Binding<String>,
        city: Binding<String>,
        state: Binding<String>,
        zip: Binding<String>,
        createdByUserId: Binding<String>,
        gymWebsite: Binding<String>,
        gymWebsiteURL: Binding<URL?>,
        pirateIslandViewModel: PirateIslandViewModel
    ) {
        self._islandName = islandName
        self._street = street
        self._city = city
        self._state = state
        self._zip = zip
        self._createdByUserId = createdByUserId
        self._gymWebsite = gymWebsite
        self._gymWebsiteURL = gymWebsiteURL
        self.pirateIslandViewModel = pirateIslandViewModel
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Gym Details")) {
                    TextField("Gym Name", text: $islandName)
                        .onChange(of: islandName) { _ in validateFields() }
                    TextField("Street", text: $street)
                        .onChange(of: street) { _ in updateIslandLocation() }
                    TextField("City", text: $city)
                        .onChange(of: city) { _ in updateIslandLocation() }
                    TextField("State", text: $state)
                        .onChange(of: state) { _ in updateIslandLocation() }
                    TextField("Zip", text: $zip)
                        .onChange(of: zip) { _ in updateIslandLocation() }
                }

                Section(header: Text("Entered By")) {
                    TextField("Your Name", text: $createdByUserId)
                        .onChange(of: createdByUserId) { _ in validateFields() }
                }

                Section(header: Text("Website (if applicable)")) {
                    TextField("Website", text: $gymWebsite, onCommit: {
                        if !gymWebsite.isEmpty {
                            gymWebsiteURL = URL(string: gymWebsite)
                            validateFields()
                        }
                    })
                }

                Button("Save") {
                    if isSaveEnabled {
                        Task {
                            try await saveIslandData()
                        }
                    } else {
                        print("Save button disabled")
                        alertMessage = "Required fields are empty or invalid"
                        showAlert.toggle()
                    }
                }
                .disabled(!isSaveEnabled)
            }
            .navigationBarTitle("Add Gym")
            .navigationBarItems(leading: Button("Cancel") {
                presentationMode.wrappedValue.dismiss()
            })
            .alert(isPresented: $showAlert) {
                Alert(title: Text("Error"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
            }
        }
        .onAppear {
            validateFields() // Initial validation check
        }
    }

    
    private func updateIslandLocation() {
        // Implement geocoding logic or any other necessary updates based on street, city, state, zip fields
        validateFields() // Update field validation after location update
    }

    
    private func validateFields() {
        let isValid = !islandName.isEmpty &&
                      !street.isEmpty &&
                      !city.isEmpty &&
                      !state.isEmpty &&
                      !zip.isEmpty &&
                      !createdByUserId.isEmpty &&
                      (gymWebsite.isEmpty || validateURL(gymWebsite))

        isSaveEnabled = isValid // Update isSaveEnabled based on validation
    }


    private func saveIslandData() async throws {
        try await pirateIslandViewModel.saveIslandData(
            islandName,
            street,
            city,
            state,
            zip,
            website: gymWebsiteURL
        )
        presentationMode.wrappedValue.dismiss()
    }

    private func validateURL(_ urlString: String) -> Bool {
        guard let url = URL(string: urlString) else { return false }
        return UIApplication.shared.canOpenURL(url)
    }
}

struct AddIslandFormView_Previews: PreviewProvider {
    static var previews: some View {
        AddIslandFormView(
            islandName: .constant(""),
            street: .constant(""),
            city: .constant(""),
            state: .constant(""),
            zip: .constant(""),
            createdByUserId: .constant(""),
            gymWebsite: .constant(""),
            gymWebsiteURL: .constant(nil),
            pirateIslandViewModel: PirateIslandViewModel(persistenceController: PersistenceController.shared)
        )
    }
}
