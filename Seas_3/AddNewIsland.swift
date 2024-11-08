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
    @ObservedObject var profileViewModel: ProfileViewModel
    
    // MARK: - State Variables
    @State private var islandName = ""
    @State private var street = ""
    @State private var city = ""
    @State private var state = ""
    @State private var zip = ""
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
    init(viewModel: PirateIslandViewModel, profileViewModel: ProfileViewModel) {
        self.islandViewModel = viewModel
        self.profileViewModel = profileViewModel
    }
    
    // MARK: - Body
    var body: some View {
        NavigationView {
            Form {
                IslandFormSections(
                    viewModel: islandViewModel,
                    islandName: $islandName,
                    street: $street,
                    city: $city,
                    state: $state,
                    zip: $zip,
                    gymWebsite: $gymWebsite,
                    gymWebsiteURL: $gymWebsiteURL,
                    selectedProtocol: $selectedProtocol,
                    showAlert: $showAlert,
                    alertMessage: $alertMessage
                )
                .onChange(of: islandName) { _ in validateFields() }
                .onChange(of: street) { _ in validateFields() }
                .onChange(of: city) { _ in validateFields() }
                .onChange(of: state) { _ in validateFields() }
                .onChange(of: zip) { _ in validateFields() }

                enteredBySection
                saveButton
            }
        }
        .navigationBarTitle("Add New Gym", displayMode: .inline)
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
                            .onAppear {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    showToast = false
                                }
                            }
                    }
                }
            }
        )
    }
    
    private var enteredBySection: some View {
        Section(header: Text("Entered By")) {
            Text(profileViewModel.name)
                .foregroundColor(.primary)
                .padding()
        }
    }
    
    private var saveButton: some View {
        Button("Save") {
            Task {
                await saveIsland()
            }
        }
        .disabled(!isSaveEnabled)
    }
    private var cancelButton: some View {
        Button("Cancel") {
            presentationMode.wrappedValue.dismiss()
        }
    }
    
    // MARK: - Private Methods
    private func saveIsland() async {
        print("Saving Island:")
        print("Name: \(islandName)")
        print("Street: \(street)")
        print("City: \(city)")
        print("State: \(state)")
        print("Zip: \(zip)")
        print("Gym Website: \(gymWebsite)")
        print("Gym Website URL: \(String(describing: gymWebsiteURL))")
        print("Location: \(street), \(city), \(state) \(zip)")
        
        await islandViewModel.createPirateIsland(
            name: islandName,
            location: "\(street), \(city), \(state) \(zip)",
            createdByUserId: profileViewModel.name,
            gymWebsiteURL: gymWebsiteURL
        ) { result in
            switch result {
            case .success(let island):
                print("Gym saved successfully: \(island.islandName)")
                clearFields() // Clear fields after successful save
            case .failure(let error):
                self.showToast = true
                self.toastMessage = "Error saving island: \(error.localizedDescription)"
                
                // Log specific error types for detailed feedback
                if let pirateIslandError = error as? PirateIslandError {
                    switch pirateIslandError {
                    case .savingError:
                        print("Saving error occurred in Core Data.")
                    case .invalidInput:
                        print("Invalid input detected.")
                    case .islandExists:
                        print("An island with this name or location already exists.")
                        alertMessage = "An island with this name already exists. Please enter a unique name or location."
                        showAlert = true
                    case .geocodingError:
                        print("Geocoding failed for the provided location.")
                    }
                }
            }
        }
    }
    
    private func validateFields() {
        let location = "\(street), \(city), \(state) \(zip)"
        isSaveEnabled = islandViewModel.validateIslandData(
            islandName,
            location,
            profileViewModel.name  // Include `profileViewModel.name` if required for validation
        ) && !islandName.isEmpty && !street.isEmpty && !city.isEmpty && !state.isEmpty && !zip.isEmpty
    }

    private func clearFields() {
        islandName = ""
        street = ""
        city = ""
        state = ""
        zip = ""
        gymWebsite = ""
        gymWebsiteURL = nil
    }
}

struct AddNewIsland_Previews: PreviewProvider {
    static var previews: some View {
        let persistenceController = PersistenceController.shared
        let profileViewModel = ProfileViewModel(viewContext: persistenceController.container.viewContext)
        profileViewModel.name = "Brian Romero" // Example name for preview
        return AddNewIsland(viewModel: PirateIslandViewModel(persistenceController: persistenceController), profileViewModel: profileViewModel)
    }
}
