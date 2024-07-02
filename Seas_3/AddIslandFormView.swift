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
    @Binding var fullAddress: String
    @Binding var createdByUserId: String
    @Binding var gymWebsite: String
    @Binding var gymWebsiteURL: URL?

    @State private var isSaveEnabled = false
    @State private var showAlert = false
    @State private var alertMessage = ""

    init(islandName: Binding<String>, fullAddress: Binding<String>, createdByUserId: Binding<String>, gymWebsite: Binding<String>, gymWebsiteURL: Binding<URL?>) {
        self._islandName = islandName
        self._fullAddress = fullAddress
        self._createdByUserId = createdByUserId
        self._gymWebsite = gymWebsite
        self._gymWebsiteURL = gymWebsiteURL
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Island Details")) {
                    TextField("Island Name", text: $islandName)
                        .onChange(of: islandName) { _ in validateFields() }
                    TextField("Address", text: $fullAddress)
                        .onChange(of: fullAddress) { _ in validateFields() }
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
                        print("Save button tapped")
                        geocodeIslandLocation()
                    } else {
                        print("Save button disabled")
                        alertMessage = "Required fields are empty or invalid"
                        showAlert.toggle()
                    }
                }
                .disabled(!isSaveEnabled)
            }
            .navigationBarTitle("Add Island")
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

    private func validateFields() {
        let isValid = !islandName.isEmpty &&
                      !fullAddress.isEmpty &&
                      !createdByUserId.isEmpty &&
                      (gymWebsite.isEmpty || validateURL(gymWebsite))

        isSaveEnabled = isValid // Update isSaveEnabled based on validation
    }

    private func geocodeIslandLocation() {
        print("Geocoding Island Location: \(fullAddress)")
        // Implement geocoding logic here using Core Location or a geocoding service
        // Example: geocodeAddress(fullAddress) { result in ... }
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
            fullAddress: .constant(""),
            createdByUserId: .constant(""),
            gymWebsite: .constant(""),
            gymWebsiteURL: .constant(nil)
        )
    }
}
