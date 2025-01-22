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
    var countries: [Country]
    @State private var requiredFields: [AddressFieldType] = []

    var body: some View {
        Picker("Select Country", selection: $selectedCountry) {
            ForEach(countries, id: \.cca2) { country in
                Text(country.countryName).tag(country as Country?)
            }
        }
        .onChange(of: selectedCountry) { newValue in
            if let countryCode = newValue?.cca2 {
                requiredFields = getAddressFields(for: countryCode)
            }
        }
    }
}
