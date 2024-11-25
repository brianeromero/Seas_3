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
                Logger.logCreatedByIdEvent(createdByUserId: profileViewModel.name, fileName: "AddNewIsland", functionName: "onAppear")

                let (isValid, errorMessage) = ValidationUtility.validateIslandForm(
                    islandName: islandDetails.islandName,
                    street: islandDetails.street,
                    city: islandDetails.city,
                    state: islandDetails.state,
                    zip: islandDetails.zip,
                    neighborhood: islandDetails.neighborhood,
                    complement: islandDetails.complement,
                    province: islandDetails.province,
                    region: islandDetails.region,
                    district: islandDetails.district,
                    department: islandDetails.department,
                    governorate: islandDetails.governorate,
                    emirate: islandDetails.emirate,
                    apartment: islandDetails.apartment,
                    additionalInfo: islandDetails.additionalInfo,
                    selectedCountry: Country(name: .init(common: islandDetails.country ?? ""), cca2: ""),
                    createdByUserId: profileViewModel.name,
                    gymWebsite: islandDetails.gymWebsite
                )

                if !isValid {
                    alertMessage = errorMessage
                    showAlert = true
                } else {
                    isSaveEnabled = true
                }
            }
        }
        .overlay(toastOverlay)
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
            neighborhood: $islandDetails.neighborhood,
            complement: $islandDetails.complement,
            apartment: $islandDetails.apartment,
            region: $islandDetails.region,
            county: $islandDetails.county,
            governorate: $islandDetails.governorate,
            additionalInfo: $islandDetails.additionalInfo,
            gymWebsite: $islandDetails.gymWebsite,
            gymWebsiteURL: $islandDetails.gymWebsiteURL,
            showAlert: $showAlert,
            alertMessage: $alertMessage,
            selectedCountry: Binding<Country?>(
                get: {
                    guard let countryName = self.islandDetails.country else { return nil }
                    return Country(name: .init(common: countryName), cca2: "")
                },
                set: {
                    self.islandDetails.country = $0?.countryName
                }
            ),
            islandDetails: $islandDetails,
            profileViewModel: ProfileViewModel(viewContext: viewContext)
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
            AddressFormView()
        }
    }

    private var saveButton: some View {
        Button("Save") {
            Task {
                saveIsland()
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
        
    private func saveIsland() {
        Logger.logCreatedByIdEvent(createdByUserId: profileViewModel.name, fileName: "AddNewIsland", functionName: "saveIsland")
        guard !profileViewModel.name.isEmpty else { return }
            
        Task {
            do {
                _ = try await islandViewModel.createPirateIsland(islandDetails: islandDetails, createdByUserId: profileViewModel.name)
                toastMessage = "Island saved successfully!"
                clearFields()
            } catch {
                toastMessage = "Error saving island: \(error.localizedDescription)"
            }
            showToast = true
        }
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
