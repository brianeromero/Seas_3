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

    var body: some View {
        Picker("Select Country", selection: $selectedCountry) {
            ForEach(countries, id: \.cca2) { country in
                Text(country.name.common).tag(country as Country?)
            }
        }
    }
}
