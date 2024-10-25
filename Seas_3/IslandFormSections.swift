//
//  IslandFormSections.swift
//  Seas_3
//
//  Created by Brian Romero on 10/11/24.
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

    var body: some View {
        VStack(spacing: 10) { // Reduce spacing
            islandDetailsSection
            websiteSection
        }
        .padding() // Optional padding around the VStack
    }


    var islandDetailsSection: some View {
        Section(header: Text("Gym Details").fontWeight(.bold)) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Gym Name")
                TextField("Enter Gym Name", text: $islandName)
                    .onChange(of: islandName) { _ in validateFields() }
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                Text("Street")
                TextField("Enter Street", text: $street)
                    .onChange(of: street) { _ in updateIslandLocation() }
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                Text("City")
                TextField("Enter City", text: $city)
                    .onChange(of: city) { _ in updateIslandLocation() }
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                Text("State")
                TextField("Enter State", text: $state)
                    .onChange(of: state) { _ in updateIslandLocation() }
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                Text("Zip")
                TextField("Enter Zip", text: $zip)
                    .onChange(of: zip) { _ in updateIslandLocation() }
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
        }
        .padding() // Add padding to the section
    }

    var websiteSection: some View {
        Section(header: Text("Gym Website").fontWeight(.bold)) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Gym Website")
                TextField("Enter Website URL", text: $gymWebsite, onEditingChanged: { _ in
                    if !gymWebsite.isEmpty {
                        let strippedURL = stripProtocol(from: gymWebsite)
                        let fullURLString = "https://" + strippedURL // Default to https
                        
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
                    validateFields()
                })
                .keyboardType(.URL)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            .padding() // Add padding to the section
        }
    }

    
    private func validateFields() {
        // Call viewModel's validation logic here
    }
    
    private func updateIslandLocation() {
        // Call viewModel's geocoding logic here
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
}



// IslandFormSections_Previews.swift
import SwiftUI

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


// IslandFormSections_Previews.swift
import SwiftUI

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
