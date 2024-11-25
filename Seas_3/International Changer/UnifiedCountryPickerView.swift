
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
    @State var countries: [Country] = []
    @Binding var selectedCountry: Country?
    @State private var isPickerPresented: Bool = false

    var body: some View {
        VStack {
            if countries.isEmpty {
                Text("Loading countries...")
            } else {
                // Selector Button
                Button(action: {
                    print("Picker button tapped") // Log when the button is tapped
                    isPickerPresented.toggle() // Show the picker
                }) {
                    HStack {
                        Text(selectedCountry?.flagEmoji ?? "🌍") // Default to a globe emoji
                            .font(.largeTitle)
                        Text(selectedCountry?.cca2 ?? "Select Country")
                            .font(.headline)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.blue.opacity(0.1)))
                }
                .sheet(isPresented: $isPickerPresented) {
                    // Present the picker in a sheet
                    CountryPickerSheetView(
                        countries: countries,
                        selectedCountry: $selectedCountry,
                        isPickerPresented: $isPickerPresented
                    )
                }

                // Display Selected Country's Details
                if let selectedCountry = selectedCountry {
                    Text("Selected Country: \(selectedCountry.name.common)")
                        .padding()
                }
            }
        }
        .onAppear {
            print("UnifiedCountryPickerView appeared") // Log when the view appears
            fetchCountries()
        }
    }

    func fetchCountries() {
        print("Fetching countries...") // Log when fetching starts
        CountryService.shared.fetchCountries { fetchedCountries in
            if let fetchedCountries = fetchedCountries {
                print("Fetched countries: \(fetchedCountries.map { $0.name.common })") // Log the fetched country names
                DispatchQueue.main.async {
                    self.countries = fetchedCountries.sorted { $0.name.common < $1.name.common }
                    
                    // Set the selected country to "US" if available
                    if let usCountry = self.countries.first(where: { $0.cca2 == "US" }) {
                        self.selectedCountry = usCountry
                    } else if let firstCountry = self.countries.first {
                        // Fallback to the first country in the list
                        self.selectedCountry = firstCountry
                    }
                }
            } else {
                print("Failed to fetch countries") // Log failure to fetch countries
            }
        }
    }
}

struct CountryPickerSheetView: View {
    let countries: [Country]
    @Binding var selectedCountry: Country?
    @Binding var isPickerPresented: Bool // Controls the sheet visibility

    var body: some View {
        NavigationView {
            List(countries, id: \.cca2) { country in
                Button(action: {
                    print("Country selected: \(country.name.common)") // Log the selected country
                    selectedCountry = country
                    isPickerPresented = false // Dismiss the sheet
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
                        print("Picker cancelled") // Log when the cancel button is tapped
                        isPickerPresented = false // Dismiss the sheet
                    }
                }
            }
        }
    }
}

struct UnifiedCountryPickerView_Previews: PreviewProvider {
    static var previews: some View {
        let countries = [Country(name: Country.Name(common: "USA"), cca2: "US")]
        UnifiedCountryPickerView(countries: countries, selectedCountry: .constant(nil))
    }
}
