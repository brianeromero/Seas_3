//
//  CountryPicker.swift
//  Mat_Finder
//
//  Created by Brian Romero on 11/15/24.
//

import Foundation
import SwiftUI

struct CountryPicker: View {
    @Binding var selectedCountry: Country?
    @State private var isPickerPresented = false
    @StateObject var countryService = CountryService()
    @State private var requiredFields: [AddressFieldType] = []

    var body: some View {
        UnifiedCountryPickerView(
            countryService: countryService,
            selectedCountry: $selectedCountry,
            isPickerPresented: $isPickerPresented
        )
        .onChange(of: selectedCountry) { newValue in
            if let countryCode = newValue?.cca2 {
                let normalizedCountryCode = countryCode.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
                print("Normalized Country Code Set123: \(normalizedCountryCode)") // Debugging Log
                
                do {
                    requiredFields = try getAddressFields(for: normalizedCountryCode)
                    print("Address Fields Required456: \(requiredFields)") // Debugging Log
                } catch {
                    print("Error getting address fields for country code 456 \(normalizedCountryCode): \(error)")
                }
            } else {
                print("Error: Selected country is nil or does not have a valid cca2 code.")
            }
        }
    }
}

