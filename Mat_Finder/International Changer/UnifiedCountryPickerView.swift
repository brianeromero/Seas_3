//
//  UnifiedCountryPickerView.swift
//  Mat_Finder
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
        .onChange(of: selectedCountry) { newCountry in
            if let country = newCountry {
                let countryCode = country.cca2 // no need for `if let` since `cca2` is non-optional
                let normalizedCountryCode = countryCode.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
                print("Normalized Country Code Set: \(normalizedCountryCode)")
                
                // Fetch address fields
                fetchAddressFields(forCountry: normalizedCountryCode)
            } else {
                print("Error: Selected country is nil.")
            }
        }
    }

    // Function to fetch address fields based on the normalized country code
    func fetchAddressFields(forCountry countryCode: String) {
        do {
            let addressFields = try getAddressFields(for: countryCode)
            
            // Update your UI or model with the fetched address fields
            print("Fetched Address Fields for \(countryCode): \(addressFields)")
            
            // Now you can use the address fields as needed
            // For example, you might show/hide input fields based on this information
        } catch {
            print("Error fetching address fields123: \(error)")
            
            // Handle error, such as showing a default address format or an error message
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
                    print("Updated selectedCountry to: \(country.name.common)")
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
