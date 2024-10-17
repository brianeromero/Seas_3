//
//  AddNewIsland.swift
//  Seas_3
//
//  Created by Brian Romero on 6/26/24.
//

import SwiftUI
import CoreData
import Combine

struct AddNewIsland: View {
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject private var islandViewModel: PirateIslandViewModel

    // MARK: - State Variables
    @State private var islandName = ""
    @State private var street = ""
    @State private var city = ""
    @State private var state = ""
    @State private var zip = ""
    @State private var createdByUserId = ""
    @State private var gymWebsite = ""
    @State private var gymWebsiteURL: URL?
    @State private var isSaveEnabled = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var selectedProtocol = "http://"
    
    @Environment(\.presentationMode) private var presentationMode

    // MARK: - Toast Message State
    @State private var showToast = false
    @State private var toastMessage = ""

    // MARK: - Initialization
    init(viewModel: PirateIslandViewModel) {
        self.islandViewModel = viewModel
    }

    // MARK: - Body
    var body: some View {
        NavigationView {
            Form {
                IslandFormSections(viewModel: islandViewModel,
                                  islandName: $islandName,
                                  street: $street,
                                  city: $city,
                                  state: $state,
                                  zip: $zip,
                                  gymWebsite: $gymWebsite,
                                  gymWebsiteURL: $gymWebsiteURL,
                                  selectedProtocol: $selectedProtocol,
                                  showAlert: $showAlert,
                                  alertMessage: $alertMessage)
                enteredBySection
                saveButton
            }
        }
        .navigationBarTitle("Add New Gym", displayMode: .inline)
        .navigationBarItems(leading: cancelButton)
        .alert(isPresented: $showAlert) {
            Alert(title: Text("Error"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
        }
        .onAppear {
            validateFields()
        }
        .overlay(
            Group {
                if showToast {
                    withAnimation {
                        ToastView(showToast: $showToast, message: toastMessage)
                            .transition(.move(edge: .bottom))
                    }
                }
            }
        )
    }

    private var enteredBySection: some View {
        Section(header: Text("Entered By")) {
            TextField("Your Name", text: $createdByUserId)
                .onChange(of: createdByUserId) { _ in validateFields() }
        }
    }

    private var saveButton: some View {
        Button("Save") {
            saveIsland()
        }
        .disabled(!isSaveEnabled)
    }

    private var cancelButton: some View {
        Button("Cancel") {
            presentationMode.wrappedValue.dismiss()
        }
    }

    // MARK: - Private Methods
    private func saveIsland() {
        islandViewModel.createPirateIsland(
            name: islandName,
            location: "\(street), \(city), \(state) \(zip)",
            createdByUserId: createdByUserId,
            gymWebsiteURL: gymWebsiteURL
        ) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self.showToast = true
                    self.toastMessage = "Gym added successfully!"
                    self.clearFields()
                    self.presentationMode.wrappedValue.dismiss() // Navigate back to IslandMenu
                case .failure(let error):
                    self.showToast = true
                    self.toastMessage = "Failed to add gym: \(error.localizedDescription)"
                }
            }
        }
    }

    private func validateFields() {
        let nameValid = !islandName.isEmpty
        let locationValid = !street.isEmpty && !city.isEmpty && !state.isEmpty && !zip.isEmpty
        let createdByValid = !createdByUserId.isEmpty

        isSaveEnabled = nameValid && locationValid && createdByValid
    }

    private func clearFields() {
        islandName = ""
        street = ""
        city = ""
        state = ""
        zip = ""
        createdByUserId = ""
        gymWebsite = ""
        gymWebsiteURL = nil
    }

    private func updateIslandLocation() {
        // Perform geocoding or any other location updates if needed
        validateFields()
    }

    private func stripProtocol(from urlString: String) -> String {
        if urlString.lowercased().starts(with: "http://") {
            return String(urlString.dropFirst(7))
        } else if urlString.lowercased().starts(with: "https://") {
            return String(urlString.dropFirst(8))
        }
        return urlString
    }

    private func validateURL(_ urlString: String) -> Bool {
        // Simplified URL validation using a regex pattern
        let urlRegex = "^(https?:\\/\\/)?([\\da-z\\.-]+)\\.([a-z\\.]{2,6})([\\/\\w \\.-]*)*\\/?$"
        return NSPredicate(format: "SELF MATCHES %@", urlRegex).evaluate(with: urlString)
    }
}

struct AddNewIsland_Previews: PreviewProvider {
    static var previews: some View {
        let persistenceController = PersistenceController.shared
        return AddNewIsland(viewModel: PirateIslandViewModel(persistenceController: persistenceController))
    }
}
