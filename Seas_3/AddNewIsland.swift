// AddNewIsland.swift
// Seas_3
//
// Created by Brian Romero on 6/26/24.
//

import SwiftUI
import CoreData
import Combine
import FirebaseFirestore

struct AddNewIsland: View {
    // MARK: - Environment Variables
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.presentationMode) private var presentationMode

    // MARK: - Observed Objects
    @ObservedObject var islandViewModel: PirateIslandViewModel
    @ObservedObject var profileViewModel: ProfileViewModel
    @State var islandDetails: IslandDetails

    // MARK: - State Variables
    @State private var isSaveEnabled = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var showToast = false
    @State private var toastMessage = ""

    // MARK: - Initialization
    init(viewModel: PirateIslandViewModel, profileViewModel: ProfileViewModel, islandDetails: IslandDetails) {
        self.islandViewModel = viewModel
        self.profileViewModel = profileViewModel
        self.islandDetails = islandDetails  // Initialize IslandDetails
    }

    // MARK: - Body
    var body: some View {
        NavigationView {
            Form {
                islandFormSection
                enteredBySection
                countrySpecificFieldsSection
                saveButton
                cancelButton
            }
            .navigationBarTitle("Add New Gym", displayMode: .inline)
            .alert(isPresented: $showAlert) {
                Alert(title: Text("Error"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
            }
            .onAppear {
                validateFields()
            }
            .overlay(toastOverlay)
        }
    }

    // MARK: - Extracted Views
    private var islandFormSection: some View {
        IslandFormSections(
            viewModel: islandViewModel,
            islandName: $islandDetails.islandName,
            street: $islandDetails.street,
            city: $islandDetails.city,
            state: $islandDetails.state,
            zip: $islandDetails.zip,
            province: $islandDetails.province,
            postalCode: $islandDetails.postalCode,
            gymWebsite: $islandDetails.gymWebsite,
            gymWebsiteURL: $islandDetails.gymWebsiteURL,
            selectedCountry: $islandDetails.country, // Selected country binding
            showAlert: $showAlert,
            alertMessage: $alertMessage,
            islandDetails: $islandDetails
        )
    }


    private var enteredBySection: some View {
        Section(header: Text("Entered By")) {
            Text(profileViewModel.name)
                .foregroundColor(.primary)
                .padding()
        }
    }

    private var countrySpecificFieldsSection: some View {
        Section(header: Text("Gym Information")) {
            // Use AddressFormView for country-specific dynamic fields
            AddressFormView()
        }
    }

    private var saveButton: some View {
        Button("Save") {
            Task {
                await saveIsland()
            }
        }
        .disabled(!isSaveEnabled)
        .padding()
    }

    private var cancelButton: some View {
        Button("Cancel") {
            presentationMode.wrappedValue.dismiss()
        }
        .padding()
    }

    private var toastOverlay: some View {
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
    }

    // MARK: - Private Methods
    private func saveIsland() async {
        guard !islandDetails.islandName.isEmpty,
              !islandDetails.street.isEmpty,
              !islandDetails.city.isEmpty,
              !islandDetails.state.isEmpty,
              !islandDetails.zip.isEmpty else {
            showToast = true
            toastMessage = "Please fill in all fields."
            return
        }

        // First, save the island to Core Data
        let result = await islandViewModel.createPirateIslandAsync(
            islandDetails: islandDetails,
            createdByUserId: profileViewModel.name,
            gymWebsiteURL: islandDetails.gymWebsiteURL
        )

        switch result {
        case .success:
            // After successfully saving to Core Data, save the island to Firestore
            await saveIslandToFirestore()
            clearFields()
        case .failure(let error):
            showToast = true
            toastMessage = error.localizedDescription
        }
    }

    private func saveIslandToFirestore() async {
        // Prepare the data for Firestore
        let islandData: [String: Any] = [
            "islandName": islandDetails.islandName,
            "street": islandDetails.street,
            "city": islandDetails.city,
            "state": islandDetails.state,
            "zip": islandDetails.zip,
            "website": islandDetails.gymWebsite,
            "createdBy": profileViewModel.name
        ]
        
        do {
            // Save to Firestore
            let documentRef = try await islandViewModel.firestore.collection("islands").addDocument(data: islandData)
            
            // Store the Firestore document ID in the ViewModel
            islandViewModel.firestoreDocumentID = documentRef.documentID
            
            // Save the island data to Core Data as a local cache
            let newIsland = PirateIsland(context: viewContext) // Using viewContext directly from @Environment
            newIsland.islandName = islandDetails.islandName
            newIsland.islandLocation = "\(islandDetails.street), \(islandDetails.city), \(islandDetails.state) \(islandDetails.zip)"
            
            // Convert the gymWebsite string to a URL
            newIsland.gymWebsite = URL(string: islandDetails.gymWebsite)
            
            newIsland.createdByUserId = profileViewModel.name
            newIsland.islandID = UUID()
            newIsland.createdTimestamp = Date()
            newIsland.lastModifiedTimestamp = Date()
            
            // Save to Core Data
            try viewContext.save()
            
            toastMessage = "Island saved successfully!"
            showToast = true
        } catch {
            toastMessage = "Error saving to Firestore: \(error.localizedDescription)"
            showToast = true
        }
    }

    private func validateFields() {
        isSaveEnabled = !islandDetails.islandName.isEmpty &&
                        !islandDetails.street.isEmpty &&
                        !islandDetails.city.isEmpty &&
                        !islandDetails.state.isEmpty &&
                        !islandDetails.zip.isEmpty
    }

    private func clearFields() {
        islandDetails.islandName = ""
        islandDetails.street = ""
        islandDetails.city = ""
        islandDetails.state = ""
        islandDetails.zip = ""
        islandDetails.gymWebsite = ""
        islandDetails.gymWebsiteURL = nil
    }
}

struct AddNewIsland_Previews: PreviewProvider {
    static var previews: some View {
        let persistenceController = PersistenceController.preview
        let profileViewModel = ProfileViewModel(
            viewContext: PersistenceController.preview.container.viewContext,
            authViewModel: AuthViewModel.shared
        )
        profileViewModel.name = "Brian Romero" // Example name for preview
        return AddNewIsland(
            viewModel: PirateIslandViewModel(persistenceController: persistenceController),
            profileViewModel: profileViewModel,
            islandDetails: IslandDetails() // Pass IslandDetails here
        )
    }
}
