//
//  UnifiedCountryPickerView.swift
//  Mat_Finder
//
//  Created by Brian Romero on 11/15/24.
//

import Foundation
import SwiftUI
 

extension Country {
    var flagEmoji: String {
        let base: UInt32 = 127397
        return String(
            cca2.unicodeScalars.compactMap {
                UnicodeScalar(base + $0.value)?.description
            }.joined()
        )
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
                    .progressViewStyle(.circular)
                    .padding()

            } else {

                Button {
                    print("Country selector button tapped")
                    isPickerPresented.toggle()

                } label: {

                    HStack {
                        Text(selectedCountry?.flagEmoji ?? "")
                            .font(.largeTitle)

                        Text(selectedCountry?.name.common ?? "Select Country")
                            .font(.headline)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.blue.opacity(0.1))
                    )
                }
                .sheet(isPresented: $isPickerPresented) {

                    CountryPickerSheetView(
                        countries: countryService.countries,
                        selectedCountry: $selectedCountry,
                        isPickerPresented: $isPickerPresented
                    )
                }
            }
        }
        .onChange(of: selectedCountry) { _, newCountry in

            guard let country = newCountry else {
                print("Error: Selected country is nil.")
                return
            }

            let normalizedCountryCode = country.cca2
                .uppercased()
                .trimmingCharacters(in: .whitespacesAndNewlines)

            print("Normalized Country Code Set: \(normalizedCountryCode)")

            fetchAddressFields(forCountry: normalizedCountryCode)
        }
    }

    private func fetchAddressFields(forCountry countryCode: String) {

        do {
            let addressFields = try getAddressFields(for: countryCode)
            print("Fetched Address Fields for \(countryCode): \(addressFields)")
        } catch {
            print("Error fetching address fields: \(error)")
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

                Button {

                    print("Country selected: \(country.name.common)")
                    selectedCountry = country
                    isPickerPresented = false

                } label: {

                    HStack {
                        Text(country.flagEmoji)
                            .font(.largeTitle)

                        Text(country.name.common)
                    }
                }
            }
            .navigationTitle("Select a Country")
            .toolbar {

                ToolbarItem(placement: .cancellationAction) {

                    Button("Cancel") {
                        isPickerPresented = false
                    }
                }
            }
        }
    }
}
