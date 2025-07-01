//
//  AddIslandFormView.swift
//  Seas_3
//
//  Created by Brian Romero on 6/26/24.
//

import SwiftUI
import CoreData
import Combine
import Foundation

struct AddIslandFormView: View {
    // MARK: - Environment Variables
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) var dismiss // ✅ Correct way to use @Environment(\.dismiss)

    
    // MARK: - Observed Objects
    @ObservedObject var islandViewModel: PirateIslandViewModel
    @ObservedObject var profileViewModel: ProfileViewModel
    @State var islandDetails: IslandDetails
    @ObservedObject var authViewModel: AuthViewModel

    
    // MARK: - State Variables
    @State private var isSaveEnabled = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var showToast = false
    @State private var toastMessage = ""
    @State private var isGeocoding = false
    @State private var error: String?
    @State private var requiredFields: [AddressFieldType] = []
    



    // MARK: - Initialization
    init(
        islandViewModel: PirateIslandViewModel,
        profileViewModel: ProfileViewModel,
        authViewModel: AuthViewModel,
        islandDetails: IslandDetails
    ) {
        self.islandViewModel = islandViewModel
        self.profileViewModel = profileViewModel
        self.authViewModel = authViewModel
        self.islandDetails = islandDetails
    }

    
    // MARK: - Body
    var body: some View {
        NavigationView {
            Form {
                gymDetailsSection
                countrySpecificFieldsSection
                enteredBySection
                instagramOrWebsiteSection
                saveButton
                cancelButton
            }
            .navigationBarTitle(islandDetails.islandName.isEmpty ? "Add New Gym" : "Edit Gym", displayMode: .inline)
            .alert(isPresented: $showAlert) {
                Alert(title: Text("Error"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
            }
            .onAppear(perform: validateForm)
            .overlay(toastOverlay)
        }
    }
    
    // MARK: - Extracted Sections
    private var gymDetailsSection: some View {
        Section(header: Text("Gym Details")) {
            TextField("Gym Name", text: $islandDetails.islandName)
            TextField("Gym Location", text: $islandDetails.street)
            TextField("City", text: $islandDetails.city)
            TextField("State", text: $islandDetails.state)
            TextField("Postal Code", text: $islandDetails.postalCode)
        }
    }
    
    private var countrySpecificFieldsSection: some View {
        Section(header: Text("Country Specific Fields")) {
            VStack {
                if let selectedCountry = islandDetails.selectedCountry {
                    if let error = error {
                        Text("Error getting address fields for country code 252627 \(selectedCountry.cca2): \(error)")
                    } else {
                        ForEach(requiredFields, id: \.self) { field in
                            self.addressField(for: field)
                        }
                        
                        if selectedCountry.cca2.uppercased().trimmingCharacters(in: .whitespacesAndNewlines) == "IE" {
                            TextField("County", text: $islandDetails.county)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                    }
                } else {
                    Text("Please select a country")
                }
            }
            .onAppear {
                if let selectedCountry = islandDetails.selectedCountry {
                    let normalizedCountryCode = selectedCountry.cca2.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
                    print("Fetching address fields for normalized country code456: \(normalizedCountryCode)")

                    do {
                        requiredFields = try getAddressFields(for: normalizedCountryCode)
                    } catch {
                        self.error = "Error getting address fields for country code 282930 \(normalizedCountryCode): \(error.localizedDescription)"
                    }
                }
            }
        }
    }


    // MARK: - Address Fields
    // Ensure consistency between AddressField and AddressFieldType
    private func addressField(for field: AddressFieldType) -> some View {
        // Adjusting to use AddressFieldType
        switch field {
        case .street:
            return AnyView(TextField("Street", text: $islandDetails.street).textFieldStyle(RoundedBorderTextFieldStyle()))
        // Handle other cases similarly
        case .city:
            return AnyView(TextField("City", text: $islandDetails.city).textFieldStyle(RoundedBorderTextFieldStyle()))
        case .state:
            return AnyView(TextField("State", text: $islandDetails.state).textFieldStyle(RoundedBorderTextFieldStyle()))
        case .postalCode:
            return AnyView(TextField("Postal Code", text: $islandDetails.postalCode).textFieldStyle(RoundedBorderTextFieldStyle()))
        case .province:
            return AnyView(TextField("Province", text: $islandDetails.province).textFieldStyle(RoundedBorderTextFieldStyle()))
        case .neighborhood:
            return AnyView(TextField("Neighborhood", text: $islandDetails.neighborhood).textFieldStyle(RoundedBorderTextFieldStyle()))
        case .district:
            return AnyView(TextField("District", text: $islandDetails.district).textFieldStyle(RoundedBorderTextFieldStyle()))
        case .department:
            return AnyView(TextField("Department", text: $islandDetails.department).textFieldStyle(RoundedBorderTextFieldStyle()))
        case .governorate:
            return AnyView(TextField("Governorate", text: $islandDetails.governorate).textFieldStyle(RoundedBorderTextFieldStyle()))
        case .emirate:
            return AnyView(TextField("Emirate", text: $islandDetails.emirate).textFieldStyle(RoundedBorderTextFieldStyle()))
        case .apartment:
            return AnyView(TextField("Apartment", text: $islandDetails.apartment).textFieldStyle(RoundedBorderTextFieldStyle()))
        case .additionalInfo:
            return AnyView(TextField("Additional Info", text: $islandDetails.additionalInfo).textFieldStyle(RoundedBorderTextFieldStyle()))
        default:
            return AnyView(EmptyView())
        }
    }
    
    private var enteredBySection: some View {
        Section(header: Text("Entered By")) {
            Text(profileViewModel.name)
                .foregroundColor(.primary)
                .padding()
        }
    }

    private var instagramOrWebsiteSection: some View {
        Section(header: Text("Instagram/Facebook/Website")) {
            TextField("Gym Website8910", text: $islandDetails.gymWebsite)
                .keyboardType(.URL)
            // Updated onChange signature for iOS 17 and later
            .onChange(of: islandDetails.gymWebsite) { newValue in
                if !newValue.isEmpty {
                    if ValidationUtility.validateURL(newValue) == nil {
                        islandDetails.gymWebsiteURL = URL(string: newValue)
                    } else {
                        showAlert = true
                        alertMessage = "Invalid website URL."
                    }
                } else {
                    islandDetails.gymWebsiteURL = nil
                }
            }

        }
    }


    private var saveButton: some View {
        Button("Save") {
            saveIsland()
        }
        .disabled(!isSaveEnabled)
        .padding()
    }

    private var cancelButton: some View {
        Button("Cancel") {
            dismiss()
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
        Task {
            guard let currentUser = await authViewModel.getCurrentUser() else {
                toastMessage = "You must be logged in to save a gym."
                showToast = true
                return
            }

            if currentUser.name.isEmpty {
                toastMessage = "Your profile info is incomplete. Please log in again."
                showToast = true
                return
            }

            do {
                _ = try await islandViewModel.createPirateIsland(
                    islandDetails: islandDetails,
                    createdByUserId: currentUser.userName,
                    gymWebsite: nil,
                    country: islandDetails.country,
                    selectedCountry: islandDetails.selectedCountry!,
                    createdByUser: currentUser
                )

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
        islandDetails.postalCode = ""
        islandDetails.gymWebsite = ""
        islandDetails.gymWebsiteURL = nil
    }

    private func validateForm() {
        let normalizedCountryCode = islandDetails.selectedCountry?.cca2.uppercased().trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        let (isValid, errorMessage) = ValidationUtility.validateIslandForm(
            islandName: islandDetails.islandName,
            street: islandDetails.street,
            city: islandDetails.city,
            state: islandDetails.state,
            postalCode: islandDetails.postalCode,
            selectedCountry: Country(
                name: .init(common: islandDetails.selectedCountry?.name.common ?? ""),
                cca2: normalizedCountryCode,
                flag: ""
            ),
            gymWebsite: islandDetails.gymWebsite
        )

        if !isValid {
            alertMessage = errorMessage
            showAlert = true
        } else {
            isSaveEnabled = true
        }
    }

    
    private func binding(for field: AddressFieldType) -> Binding<String> {
        switch field {
        case .street: return $islandDetails.street
        case .city: return $islandDetails.city
        case .state: return $islandDetails.state
        case .postalCode: return $islandDetails.postalCode
        default: return .constant("")
        }
    }
}

