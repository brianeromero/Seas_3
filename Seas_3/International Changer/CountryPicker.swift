//
//  CountryPicker.swift
//  Seas_3
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
                requiredFields = getAddressFields(for: countryCode)
            }
        }
    }
}
