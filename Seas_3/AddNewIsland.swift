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
    @State private var showConfirmation = false
    @State private var selectedProtocol = "http://"
    
    @Environment(\.presentationMode) private var presentationMode
    
    // MARK: - Toast Message State
    @State private var toastMessage = ""
    @State private var showToast = false
    
    // MARK: - Body
    var body: some View {
        NavigationView {
            Form {
                islandDetailsSection
                websiteSection
                enteredBySection
                saveButton
            }
            .navigationBarTitle("Add New Island", displayMode: .inline)
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
                        ToastView(message: toastMessage)
                            .transition(.move(edge: .bottom))
                            .animation(.default)
                            .onAppear {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    showToast = false
                                }
                            }
                    }
                }
            )
        }
    }
    
    // MARK: - Sections
    
    private var islandDetailsSection: some View {
        Section(header: Text("Island Details")) {
            TextField("Island Name", text: $islandName)
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
            Picker("Protocol", selection: $selectedProtocol) {
                Text("http://").tag("http://")
                Text("https://").tag("https://")
            }
            .pickerStyle(SegmentedPickerStyle())
            
            TextField("Website URL", text: $gymWebsite, onEditingChanged: { _ in
                if !gymWebsite.isEmpty {
                    let strippedURL = stripProtocol(from: gymWebsite)
                    let fullURLString = selectedProtocol + strippedURL
                    
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
        let newIsland = PirateIsland(context: viewContext)
        newIsland.islandName = islandName
        newIsland.createdByUserId = createdByUserId
        newIsland.gymWebsite = gymWebsiteURL
        newIsland.createdTimestamp = Date()
        
        // Assuming islandLocation is a property in PirateIsland, you set it here
        newIsland.islandLocation = "\(street), \(city), \(state) \(zip)"
        
        do {
            try viewContext.save()
            isSaveEnabled = false
            showToast = true
            toastMessage = "Island added successfully!"
            clearFields()
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
    }
    
    private func validateFields() {
        let nameValid = !islandName.isEmpty
        let locationValid = !street.isEmpty && !city.isEmpty && !state.isEmpty && !zip.isEmpty
        let websiteValid = gymWebsiteURL != nil
        let createdByValid = !createdByUserId.isEmpty
        
        isSaveEnabled = nameValid && locationValid && websiteValid && createdByValid
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
        guard let url = URL(string: urlString) else { return false }
        return UIApplication.shared.canOpenURL(url)
    }
}

struct ToastView: View {
    var message: String
    
    var body: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Text(message)
                    .padding()
                    .background(Color.black.opacity(0.7))
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .padding()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
    }
}
