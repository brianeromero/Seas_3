//
//  UnifiedCountryPickerView.swift
//  Seas_3
//
//  Created by Brian Romero on 11/15/24.
//

import Foundation
import SwiftUI

extension Country {
    // Computed property to get the flag emoji based on the `cca2` code.
    var flagEmoji: String {
        let base: UInt32 = 127397
        return String(cca2.unicodeScalars.compactMap { UnicodeScalar(base + $0.value)?.description }.joined())
    }
}

struct UnifiedCountryPickerView: View {
    @ObservedObject var countryService: CountryService
    @Binding var selectedCountry: Country?
    @Binding var isPickerPresented: Bool

    var body: some View {
        VStack {
            if countryService.isLoading {
                ProgressView("Loading countries...")
                    .progressViewStyle(CircularProgressViewStyle())
                    .padding()
            } else {
                Button(action: {
                    print("Country selector button tapped")
                    isPickerPresented.toggle()
                }) {
                    HStack {
                        Text(selectedCountry?.flagEmoji ?? "")
                            .font(.largeTitle)
                        Text(selectedCountry?.name.common ?? "Select Country")
                            .font(.headline)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.blue.opacity(0.1)))
                }
                .sheet(isPresented: $isPickerPresented) {
                    CountryPickerSheetView(
                        countries: countryService.countries,
                        selectedCountry: $selectedCountry,
                        isPickerPresented: $isPickerPresented
                    )
                    .onDisappear {
                        print("Country picker sheet dismissed")
                    }
                }
            }
        }
    }
}


struct CountryPickerSheetView: View {
    let countries: [Country]
    @Binding var selectedCountry: Country?
    @Binding var isPickerPresented: Bool

    var body: some View {
        NavigationView {
            List(countries, id: \.cca2) { country in
                Button(action: {
                    print("Country selected: \(country.name.common)")
                    selectedCountry = country
                    isPickerPresented = false
                }) {
                    HStack {
                        Text(country.flagEmoji)
                            .font(.largeTitle)
                        Text(country.name.common)
                            .font(.body)
                    }
                }
            }
            .navigationTitle("Select a Country")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        print("Country picker cancelled")
                        isPickerPresented = false
                    }
                }
            }
        }
    }
}

struct UnifiedCountryPickerView_Previews: PreviewProvider {
    static var previews: some View {
        let countries = [
            Country(name: Country.Name(common: "United States"), cca2: "US", flag: ""),
            Country(name: Country.Name(common: "Canada"), cca2: "CA", flag: "")
        ]
        let countryService = CountryService()
        countryService.countries = countries
        
        return UnifiedCountryPickerView(
            countryService: countryService,
            selectedCountry: .constant(countries.first),
            isPickerPresented: .constant(false)
        )
    }
}
