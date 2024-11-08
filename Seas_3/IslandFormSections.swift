//
// IslandFormSections.swift
// Seas_3
//
// Created by Brian Romero on 10/11/24.
//

import SwiftUI
import Foundation
import CoreData
import Combine
import CoreLocation

struct IslandFormSections: View {
    @ObservedObject var viewModel: PirateIslandViewModel
    @Binding var islandName: String
    @Binding var street: String
    @Binding var city: String
    @Binding var state: String
    @Binding var zip: String
    @Binding var gymWebsite: String
    @Binding var gymWebsiteURL: URL?
    @Binding var selectedProtocol: String
    @Binding var showAlert: Bool
    @Binding var alertMessage: String
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showValidationMessage = false

    var body: some View {
        VStack(spacing: 10) {
            islandDetailsSection
            websiteSection
        }
        .padding()
        .alert(isPresented: $showError) {
            Alert(title: Text("Error"), message: Text(errorMessage), dismissButton: .default(Text("OK")))
        }
    }

    var islandDetailsSection: some View {
        Section(header: Text("Gym Details").fontWeight(.bold)) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Gym Name")
                TextField("Enter Gym Name", text: $islandName)
                    .onChange(of: islandName) { _ in validateGymDetails() }
                    .textFieldStyle(RoundedBorderTextFieldStyle())

                if !islandName.isEmpty {
                    Text("Street")
                    TextField("Enter Street", text: $street)
                        .onChange(of: street) { _ in validateGymDetails() }
                        .textFieldStyle(RoundedBorderTextFieldStyle())

                    Text("City")
                    TextField("Enter City", text: $city)
                        .onChange(of: city) { _ in validateGymDetails() }
                        .textFieldStyle(RoundedBorderTextFieldStyle())

                    Text("State")
                    TextField("Enter State", text: $state)
                        .onChange(of: state) { _ in validateGymDetails() }
                        .textFieldStyle(RoundedBorderTextFieldStyle())

                    Text("Zip")
                    TextField("Enter Zip", text: $zip)
                        .onChange(of: zip) { _ in validateGymDetails() } // Add this line
                        .textFieldStyle(RoundedBorderTextFieldStyle())

                    if showValidationMessage {
                        Text("Street, city, state, and zip are required when gym name is entered.")
                            .foregroundColor(.red)
                    }
                }
            }
        }
        .padding()
    }

    var websiteSection: some View {
        Section(header: Text("Gym Website").fontWeight(.bold)) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Gym Website")
                TextField("Enter Website URL", text: $gymWebsite, onEditingChanged: { _ in
                    processWebsiteURL()
                })
                .keyboardType(.URL)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            .padding()
        }
    }

    private func validateGymDetails() {
        showValidationMessage = !validateGymNameAndAddress()
        updateIslandLocation()
    }

    func validateGymNameAndAddress() -> Bool {
        // Validation logic to ensure fields are not empty
        return !islandName.isEmpty && !street.isEmpty && !city.isEmpty && !state.isEmpty && !zip.isEmpty
    }

    private func updateIslandLocation() {
        // Lightweight address validation (no geocoding)
        if validateAddress() {
            // Update location without geocoding
        }
    }
    
    private func validateAddress() -> Bool {
        !street.isEmpty && !city.isEmpty && !state.isEmpty && !zip.isEmpty && isValidZip(zip)
    }
    
    
    private func isValidZip(_ zip: String) -> Bool {
        // Implement zip code validation logic (e.g., regex)
        let zipRegex = "^[0-9]{5}$"
        return NSPredicate(format: "SELF MATCHES %@", zipRegex).evaluate(with: zip)
    }

    private func processWebsiteURL() {
        if !gymWebsite.isEmpty {
            let strippedURL = stripProtocol(from: gymWebsite)
            let fullURLString = "https://" + strippedURL  // Default to https

            if validateURL(fullURLString) {
                gymWebsiteURL = URL(string: fullURLString)
            } else {
                showAlert = true
                alertMessage = "Invalid URL format"
                gymWebsite = ""
                gymWebsiteURL = nil
            }
        } else {
            gymWebsiteURL = nil
        }
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
        let urlRegex = "^(https?:\\/\\/)?([\\da-z\\.-]+)\\.([a-z\\.]{2,6})([\\/\\w \\.-]*)*\\/?$"
        return NSPredicate(format: "SELF MATCHES %@", urlRegex).evaluate(with: urlString)
    }

    private func validateFields() -> Bool {
        guard !islandName.isEmpty else {
            errorMessage = "Gym name is required."
            return false
        }

        guard !street.isEmpty, !city.isEmpty, !state.isEmpty, !zip.isEmpty else {
            errorMessage = "Street, city, state, and zip are required when gym name is entered."
            return false
        }

        return true
    }

    private func saveButtonAction() async {
        if !validateFields() {
            showError = true
        } else {
            do {
                try await viewModel.saveIslandData(
                    islandName,
                    street,
                    city,
                    state,
                    zip,
                    website: gymWebsiteURL
                )
                print("Island data saved successfully")
            } catch {
                print("Error saving island data: \(error.localizedDescription)")
                self.errorMessage = "Error saving island data: \(error.localizedDescription)"
                self.showError = true
            }
        }
    }
}

struct IslandFormSections_Previews: PreviewProvider {
    static var previews: some View {
        IslandFormSections(
            viewModel: PirateIslandViewModel(persistenceController: PersistenceController.preview),
            islandName: .constant(""),
            street: .constant(""),
            city: .constant(""),
            state: .constant(""),
            zip: .constant(""),
            gymWebsite: .constant(""),
            gymWebsiteURL: .constant(nil),
            selectedProtocol: .constant("http://"),
            showAlert: .constant(false),
            alertMessage: .constant("")
        )
        .previewLayout(.sizeThatFits)
        .previewDisplayName("Island Form Sections")
    }
}

struct IslandFormSectionsWITHDATA_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            IslandFormSections(
                viewModel: PirateIslandViewModel(persistenceController: PersistenceController.preview),
                islandName: .constant("My Gym"),
                street: .constant("123 Main St"),
                city: .constant("Anytown"),
                state: .constant("CA"),
                zip: .constant("12345"),
                gymWebsite: .constant("example.com"),
                gymWebsiteURL: .constant(URL(string: "https://example.com")),
                selectedProtocol: .constant("https://"),
                showAlert: .constant(false),
                alertMessage: .constant("")
            )
            .previewLayout(.sizeThatFits)
            .previewDisplayName("Filled Form")
            
            IslandFormSections(
                viewModel: PirateIslandViewModel(persistenceController: PersistenceController.preview),
                islandName: .constant(""),
                street: .constant(""),
                city: .constant(""),
                state: .constant(""),
                zip: .constant(""),
                gymWebsite: .constant(""),
                gymWebsiteURL: .constant(nil),
                selectedProtocol: .constant("http://"),
                showAlert: .constant(false),
                alertMessage: .constant("")
            )
            .previewLayout(.sizeThatFits)
            .previewDisplayName("Empty Form")
        }
    }
}
