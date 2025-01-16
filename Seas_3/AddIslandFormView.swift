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
    @State private var isGeocoding = false

    // MARK: - Initialization
    init(
        islandViewModel: PirateIslandViewModel,
        profileViewModel: ProfileViewModel,
        islandDetails: IslandDetails
    ) {
        self.islandViewModel = islandViewModel
        self.profileViewModel = profileViewModel
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
            if let selectedCountry = islandDetails.selectedCountry {
                let requiredFields = getAddressFields(for: selectedCountry.cca2)
                
                // Dynamically create fields based on the country-specific requirements
                ForEach(requiredFields, id: \.self) { field in
                    self.addressField(for: field)
                }
                
                // Conditional field specifically for countries like Ireland
                if selectedCountry.cca2 == "IE" {
                    TextField("County", text: $islandDetails.county)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
            } else {
                Text("Please select a country")
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
        guard !profileViewModel.name.isEmpty else { return }
        
        Task {
            do {
                // Pass nil for gymWebsite if it's not available
                _ = try await islandViewModel.createPirateIsland(
                    islandDetails: islandDetails,
                    createdByUserId: profileViewModel.name,
                    gymWebsite: nil
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
        let (isValid, errorMessage) = ValidationUtility.validateIslandForm(
            islandName: islandDetails.islandName,
            street: islandDetails.street,
            city: islandDetails.city,
            state: islandDetails.state,
            postalCode: islandDetails.postalCode,
            selectedCountry: Country(name: .init(common: islandDetails.selectedCountry?.name.common ?? ""), cca2: "", flag: ""),
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
    
    private func binding(for field: AddressFieldType) -> Binding<String> {
        switch field {
        case .street: return $islandDetails.street
        case .city: return $islandDetails.city
        case .state: return $islandDetails.state
        case .postalCode: return $islandDetails.postalCode
        default: return .constant("")
        }
    }
    
    private func getAddressFields(for country: String) -> [AddressFieldType] {
        // Fetch the address field requirements for the country using the predefined mapping
        return addressFieldRequirements[country] ?? []
    }
}

// MARK: - Preview
struct AddIslandFormView_Previews: PreviewProvider {
    static var previews: some View {
        let profileViewModel = ProfileViewModel(
            viewContext: PersistenceController.preview.viewContext,
            authViewModel: AuthViewModel.shared
        )
        profileViewModel.name = "Brian Romero"

        // Adjust IslandDetails initialization based on available initializer
        let islandDetails = IslandDetails(
            islandName: "Example Gym",
            street: "123 Main St",
            city: "Anytown",
            state: "CA",
            postalCode: "90210",
            selectedCountry: Country(name: .init(common: "USA"), cca2: "US", flag: "")
        )

        // Create an instance of PirateIslandViewModel
        let islandViewModel = PirateIslandViewModel(persistenceController: PersistenceController.preview)

        return AddIslandFormView(
            islandViewModel: islandViewModel,
            profileViewModel: profileViewModel,
            islandDetails: islandDetails
        )
    }
}
