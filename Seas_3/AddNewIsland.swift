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
                islandDetailsSection
                websiteSection
                enteredBySection
                saveButton
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
    }
    
    // MARK: - Sections
    
    private var islandDetailsSection: some View {
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
    }
    
    private var websiteSection: some View {
        Section(header: Text("Website")) {
<<<<<<< HEAD
            TextField("Website URL", text: $gymWebsite, onEditingChanged: { _ in
                if !gymWebsite.isEmpty {
                    var fullURLString = gymWebsite
                    if !fullURLString.lowercased().hasPrefix("http://") && !fullURLString.lowercased().hasPrefix("https://") {
                        fullURLString = "https://\(gymWebsite)"
                    }
=======
            Picker("Protocol", selection: $selectedProtocol) {
                Text("http://").tag("http://")
                Text("https://").tag("https://")
            }
            .pickerStyle(SegmentedPickerStyle())
            
            TextField("Website URL", text: $gymWebsite, onEditingChanged: { _ in
                if !gymWebsite.isEmpty {
                    let strippedURL = stripProtocol(from: gymWebsite)
                    let fullURLString = selectedProtocol + strippedURL
>>>>>>> 7273ce11e395d25e3e7a55c769b08b51bad6cfb9
                    
                    if validateURL(fullURLString) {
                        gymWebsiteURL = URL(string: fullURLString)
                    } else {
                        showAlert = true
                        alertMessage = "Invalid URL format"
                        gymWebsite = ""
                        gymWebsiteURL = nil
                    }
                } else {
                    gymWebsiteURL = nil // Ensure gymWebsiteURL is nil when gymWebsite is empty
                }
                validateFields()
            })
            .keyboardType(.URL)
<<<<<<< HEAD
=======

>>>>>>> 7273ce11e395d25e3e7a55c769b08b51bad6cfb9
        }
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
                    
                    // Navigate back to IslandMenu
                    self.presentationMode.wrappedValue.dismiss()
                    
                case .failure(let error):
                    self.showToast = true
                    self.toastMessage = "Failed to add gym: \(error.localizedDescription)"
                    // Optionally handle error or retry logic here
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
<<<<<<< HEAD
    }
}

struct AddNewIsland_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.shared.viewContext
        return AddNewIsland(viewModel: PirateIslandViewModel(context: context))
=======
>>>>>>> 7273ce11e395d25e3e7a55c769b08b51bad6cfb9
    }
}
