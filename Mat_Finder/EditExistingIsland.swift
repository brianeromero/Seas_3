//  EditExistingIsland.swift
//  Mat_Finder
//
//  Created by Brian Romero on 6/26/24.
//

import Foundation
import SwiftUI
import CoreData
import Combine
import FirebaseFirestore
import os
import OSLog // Ensure OSLog is imported for os_log


public struct EditExistingIsland: View {
    // MARK: - Environment Variables
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) var dismiss
    
    // MARK: - Observed Objects
    @ObservedObject var island: PirateIsland
    @EnvironmentObject var pirateIslandViewModel: PirateIslandViewModel
    @EnvironmentObject var profileViewModel: ProfileViewModel
    @EnvironmentObject var authViewModel: AuthViewModel
    
    @StateObject var islandDetails = IslandDetails()
    @ObservedObject var countryService = CountryService.shared
    
    // MARK: - State Variables
    
    @Binding var showSuccessToast: Bool
    @Binding var successToastMessage: String
    @Binding var successToastType: ToastView.ToastType
    
    @State private var originalIslandName: String = ""
    @State private var originalMultilineAddress: String = ""
    @State private var originalSelectedCountryCCA2: String? = nil
    @State private var originalGymWebsite: String = ""
    
    @State private var createdByName: String = "Loading..."
    @State private var lastModifiedByName: String = "Loading..."
    
    @State private var hasDropInFee: HasDropInFee = .notConfirmed
    @State private var feeAmount: Double = 0
    @State private var feeNote: String = ""
    
    @State private var originalHasDropInFee: HasDropInFee = .notConfirmed
    @State private var originalFeeAmount: Double = 0
    @State private var originalFeeNote: String = ""
    
    @State private var isSaving = false
    
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    // MARK: - Initialization
    init(
        island: PirateIsland,
        showSuccessToast: Binding<Bool>,
        successToastMessage: Binding<String>,
        successToastType: Binding<ToastView.ToastType>
    ) {
        _island = ObservedObject(wrappedValue: island)
        _showSuccessToast = showSuccessToast
        _successToastMessage = successToastMessage
        _successToastType = successToastType
    }
    
    // MARK: - Body
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                
                // Gym Name
                VStack(alignment: .leading, spacing: 6) {
                    Text("Gym Details")
                        .font(.headline)
                    TextField("Gym Name", text: $islandDetails.islandName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .font(.body)
                }
                
                // Country
                VStack(alignment: .leading, spacing: 6) {
                    Text("Country")
                        .font(.headline)
                    
                    if countryService.countries.isEmpty {
                        
                        ProgressView("Loading countries...")
                            .font(.body)
                        
                    } else {
                        
                        CountryPicker(selectedCountry: $islandDetails.selectedCountry)
                            .foregroundColor(.primary)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .font(.body)
                    }
                }
                
                // Address
                VStack(alignment: .leading, spacing: 6) {
                    Text("Address")
                        .font(.headline)
                    TextEditor(text: $islandDetails.multilineAddress)
                        .frame(minHeight: 100)
                        .border(Color.gray.opacity(0.5), width: 1)
                        .cornerRadius(5)
                }
                
                // Website
                VStack(alignment: .leading, spacing: 6) {
                    Text("Website (optional)")
                        .font(.headline)
                    TextField("Gym Website", text: $islandDetails.gymWebsite)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .font(.body)
                        .keyboardType(.URL)
                        .onChange(of: islandDetails.gymWebsite) { _, newValue in
                            if !newValue.isEmpty && !validateURL(newValue) {
                                alertMessage = "Invalid website URL"
                                showAlert = true
                            }
                        }
                }
                
                // Drop-In Fee
                VStack(alignment: .leading, spacing: 12) {
                    
                    // Drop-In Fee
                    DropInFeeSection(
                        hasDropInFee: $hasDropInFee,
                        feeAmount: $feeAmount,
                        feeNote: $feeNote
                    )
                    
                }
                
                // Entered By
                VStack(alignment: .leading, spacing: 6) {
                    Text("Entered By")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text(createdByName).foregroundColor(.primary)
                    
                }
                
                // Last Modified By
                VStack(alignment: .leading, spacing: 6) {
                    Text("Last Modified By")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text(lastModifiedByName).foregroundColor(.primary)
                }
                
                // Action Buttons
                actionButtons
            }
            .padding()
            .overlay(
                VStack {
                    Spacer()
                    if showSuccessToast {
                        Text(successToastMessage)
                            .padding()
                            .background(Color.black.opacity(0.8))
                            .foregroundColor(.white)
                            .cornerRadius(8)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                            .onAppear {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                    withAnimation { showSuccessToast = false }
                                }
                            }
                    }
                }
                    .padding()
                    .animation(.easeInOut, value: showSuccessToast)
            )
        }
        
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 2) {
                    Text("Edit Gym")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text("Ensure all required fields are entered below")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text("Error"),
                message: Text(alertMessage),
                dismissButton: .default(Text("OK"))
            )
        }
        .onAppear {
            Task {
                await countryService.fetchCountries()
                os_log("Countries loaded: %{public}d",
                       log: OSLog.default,
                       type: .info,
                       countryService.countries.count)
            }

            loadIslandData()
        }

        .onChange(of: countryService.countries) { _, _ in
            selectStoredCountry()
        }
    }

    private func selectStoredCountry() {
        guard islandDetails.selectedCountry == nil else { return }
        guard let code = island.country else { return }

        if let country = countryService.countries.first(where: { $0.cca2 == code }) {
            islandDetails.selectedCountry = country
            originalSelectedCountryCCA2 = code
        }
    }
    

    // MARK: - Helper Methods
    private func loadIslandData() {
        os_log("EditExistingIsland Appeared", log: OSLog.default, type: .info)

        // Initialize islandDetails from Core Data
        islandDetails.islandName = island.islandName?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        islandDetails.multilineAddress = island.islandLocation ?? ""
        islandDetails.latitude = island.latitude
        islandDetails.longitude = island.longitude
        islandDetails.gymWebsite = island.gymWebsite?.absoluteString ?? ""
        islandDetails.islandID = island.islandID

        // Drop-in fee
        hasDropInFee = HasDropInFee(rawValue: island.hasDropInFee) ?? .notConfirmed

        feeAmount = hasDropInFee == .hasFee ? island.dropInFeeAmount : 0
        feeNote = island.dropInFeeNote ?? ""

        originalHasDropInFee = hasDropInFee
        originalFeeAmount = feeAmount
        originalFeeNote = feeNote

 
        os_log("Initial Display Values:", log: OSLog.default, type: .info)
        os_log("  islandDetails.islandName: %{public}@", log: OSLog.default, type: .info, islandDetails.islandName)
        os_log("  islandDetails.multilineAddress: %{public}@", log: OSLog.default, type: .info, islandDetails.multilineAddress)
        os_log("  islandDetails.gymWebsite: %{public}@", log: OSLog.default, type: .info, islandDetails.gymWebsite)
        os_log("  island.country: %{public}@", log: OSLog.default, type: .info, island.country ?? "nil")
        os_log("  island.createdByUserId: %{public}@", log: OSLog.default, type: .info, island.createdByUserId ?? "nil")



        // Store original values
        originalIslandName = islandDetails.islandName
        originalMultilineAddress = islandDetails.multilineAddress
        originalGymWebsite = islandDetails.gymWebsite

        // Resolve "Entered By"
        Task {
            if let createdByValue = island.createdByUserId {

                var resolvedName: String?

                resolvedName = await authViewModel.fetchUserName(forUserID: createdByValue)

                if resolvedName == nil {
                    resolvedName = await authViewModel.fetchUserName(forUserName: createdByValue)
                }

                await MainActor.run {
                    self.createdByName = resolvedName ?? "Unknown Creator"
                }

            } else {

                await MainActor.run {
                    self.createdByName = "N/A (No creator ID/UserName)"
                }
            }

            // Last Modified By
            if let currentUser = authViewModel.currentUser {

                await MainActor.run {
                    self.lastModifiedByName = currentUser.userName
                }

            } else {

                await MainActor.run {
                    self.lastModifiedByName = "Not Logged In"
                }
            }
        }
    }

    // MARK: - Helper Methods
    private func hasChanges() -> Bool {
        let currentIslandName = islandDetails.islandName.trimmingCharacters(in: .whitespacesAndNewlines)
        let currentMultilineAddress = islandDetails.multilineAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        let currentGymWebsite = islandDetails.gymWebsite.trimmingCharacters(in: .whitespacesAndNewlines)

        let originalName = originalIslandName.trimmingCharacters(in: .whitespacesAndNewlines)
        let originalAddress = originalMultilineAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        let originalWebsite = originalGymWebsite.trimmingCharacters(in: .whitespacesAndNewlines)

        if currentIslandName != originalName {
            os_log("Change detected: Island Name", log: OSLog.default, type: .info)
            return true
        }
        if currentMultilineAddress != originalAddress {
            os_log("Change detected: Address", log: OSLog.default, type: .info)
            return true
        }
        // If you removed the country picker, remove this block
        if islandDetails.selectedCountry?.cca2 != originalSelectedCountryCCA2 {
            os_log("Change detected: Country", log: OSLog.default, type: .info)
            return true
        }
        if currentGymWebsite != originalWebsite {
            os_log("Change detected: Website", log: OSLog.default, type: .info)
            return true
        }
        
        if hasDropInFee != originalHasDropInFee {
            return true
        }

        if feeAmount != originalFeeAmount {
            return true
        }

        if feeNote.trimmingCharacters(in: .whitespacesAndNewlines)
            != originalFeeNote.trimmingCharacters(in: .whitespacesAndNewlines) {
            return true
        }

        return false
    }

    private func validateURL(_ urlString: String) -> Bool {
        if let url = URL(string: urlString), UIApplication.shared.canOpenURL(url) {
            return true
        }
        if !urlString.hasPrefix("http://") && !urlString.hasPrefix("https://") {
            if let urlWithHTTPS = URL(string: "https://" + urlString), UIApplication.shared.canOpenURL(urlWithHTTPS) {
                return true
            }
        }
        return false
    }

    private func saveIsland() async {

        os_log("saveIsland() called.", log: OSLog.default, type: .info)

        guard hasChanges() else {
            await MainActor.run {
                showAlert = true
                alertMessage = "No changes detected. Please make a change to one of the fields to save."
            }
            return
        }

        let isIslandNameNonEmpty = !islandDetails.islandName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let isLocationNonEmpty = !islandDetails.multilineAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        guard isIslandNameNonEmpty && isLocationNonEmpty else {
            await MainActor.run {
                showAlert = true
                alertMessage = "Please fill in all required fields (Gym Name, Address)."
            }
            return
        }
        
        if hasDropInFee == .hasFee && feeAmount <= 0 {
            await MainActor.run {
                showAlert = true
                alertMessage = "Please enter a valid drop-in fee amount."
            }
            return
        }

        guard let currentUserId = authViewModel.currentUser?.userID else {
            await MainActor.run {
                showAlert = true
                alertMessage = "User not logged in."
            }
            return
        }

        // MARK: Capture Values
        let newIslandName = islandDetails.islandName
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let newIslandLocation = islandDetails.multilineAddress
        let newGymWebsite = islandDetails.gymWebsite
        let newCountryCode = islandDetails.selectedCountry?.cca2

        var newLatitude = islandDetails.latitude ?? 0
        var newLongitude = islandDetails.longitude ?? 0

        let feeFlag: Int16 = hasDropInFee.rawValue
        let amount: Double = hasDropInFee == .hasFee ? feeAmount : 0
        let note = feeNote.isEmpty ? nil : feeNote

        let addressChanged =
            newIslandLocation.trimmingCharacters(in: .whitespacesAndNewlines)
            != originalMultilineAddress.trimmingCharacters(in: .whitespacesAndNewlines)

        do {

            // MARK: Re-Geocode If Address Changed
            if addressChanged {

                os_log("Address changed. Re-geocoding...", log: OSLog.default, type: .info)

                let coordinates = try await geocodeAddress(newIslandLocation)

                newLatitude = coordinates.latitude
                newLongitude = coordinates.longitude

                os_log("Updated coordinates: %{public}f %{public}f",
                       log: OSLog.default,
                       type: .info,
                       newLatitude,
                       newLongitude)
            }

            // MARK: Duplicate Check
            let exists = await pirateIslandViewModel.pirateIslandExists(
                name: newIslandName,
                latitude: newLatitude,
                longitude: newLongitude,
                excludingID: island.islandID
            )

            if exists {
                await MainActor.run {
                    showAlert = true
                    alertMessage = "A gym with this name already exists nearby."
                }
                return
            }

            // MARK: Update Core Data
            try await viewContext.perform {

                if island.createdByUserId == nil || island.createdByUserId?.isEmpty == true {
                    island.createdByUserId = currentUserId
                }

                island.islandName = newIslandName
                island.islandLocation = newIslandLocation
                island.latitude = newLatitude
                island.longitude = newLongitude

                if let newCountryCode {
                    island.country = newCountryCode
                }

                island.lastModifiedByUserId = currentUserId
                island.lastModifiedTimestamp = Date()

                island.hasDropInFee = feeFlag
                island.dropInFeeAmount = amount
                island.dropInFeeNote = note

                if !newGymWebsite.isEmpty {
                    let urlString = newGymWebsite.hasPrefix("http")
                        ? newGymWebsite
                        : "https://\(newGymWebsite)"
                    island.gymWebsite = URL(string: urlString)
                } else {
                    island.gymWebsite = nil
                }

                try viewContext.save()
            }

            // MARK: Update Firestore
            if let islandID = island.islandID {

                var dataToUpdate: [String: Any] = [
                    "name": newIslandName,
                    "location": newIslandLocation,
                    "latitude": newLatitude,
                    "longitude": newLongitude,
                    "lastModifiedByUserId": currentUserId,
                    "lastModifiedTimestamp": Timestamp(date: Date()),
                    "hasDropInFee": feeFlag,
                    "dropInFeeAmount": amount
                ]

                if let newCountryCode {
                    dataToUpdate["country"] = newCountryCode
                }

                if let note {
                    dataToUpdate["dropInFeeNote"] = note
                }

                if !newGymWebsite.isEmpty {
                    let urlString = newGymWebsite.hasPrefix("http")
                        ? newGymWebsite
                        : "https://\(newGymWebsite)"
                    dataToUpdate["gymWebsite"] = urlString
                }

                try await pirateIslandViewModel.updatePirateIsland(
                    id: islandID,
                    data: dataToUpdate
                )
            }

            await MainActor.run {
                successToastMessage = "Update saved successfully!"
                successToastType = .success
                showSuccessToast = true
                dismiss()
            }

        } catch {

            os_log("Error saving island: %@", log: OSLog.default, type: .error, error.localizedDescription)

            await MainActor.run {
                showAlert = true
                alertMessage = "Failed to save update: \(error.localizedDescription)"
            }
        }
    }

    private func clearFields() {
        islandDetails.islandName = ""
        islandDetails.multilineAddress = ""
        islandDetails.selectedCountry = nil
        islandDetails.gymWebsite = ""
        islandDetails.latitude = 0.0
        islandDetails.longitude = 0.0
        hasDropInFee = .notConfirmed
        feeAmount = 0
        feeNote = ""
    }
    
    // MARK: - Action Buttons
    private var actionButtons: some View {
        VStack(spacing: 14) {
            saveButton
            cancelButton
        }
        .padding(.top, 20)
    }

    // Save button with validation and async save
    private var saveButton: some View {
        Button(action: {
            guard !isSaving else { return }
            isSaving = true

            os_log("Save button clicked", log: OSLog.default, type: .info)

            Task {
                defer { isSaving = false }
                await saveIsland()
            }
        }) {
            Text(isSaving ? "Saving..." : "Save")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.accentColor)
                .foregroundColor(.white)
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(0.15), radius: 4, x: 0, y: 2)
        }
        .disabled(isSaving)
        .opacity(isSaving ? 0.6 : 1)
    }

    // Cancel button to clear fields and dismiss
    private var cancelButton: some View {
        Button(action: {
            os_log("Cancel button clicked", log: OSLog.default, type: .info)
            clearFields()
            dismiss()
        }) {
            Text("Cancel")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.systemGray6))
                .foregroundColor(.red)
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(0.08), radius: 3, x: 0, y: 1)
        }
    }

    
    
    
}
