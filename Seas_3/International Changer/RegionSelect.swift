//
//  RegionSelect.swift
//  Seas_3
//
//  Created by Brian Romero on 11/14/24.
//

import Foundation
import SwiftUI

struct RegionSelect: View {
    @State private var countries: [Country] = []
    @State private var selectedCountry: Country? = nil  // Change to Country?

    var body: some View {
        Picker("Select Country", selection: $selectedCountry) {
            ForEach(countries, id: \.cca2) { country in
                Text(country.countryName).tag(country as Country?)
            }
        }
        .pickerStyle(SegmentedPickerStyle())
        .padding()
        .onChange(of: selectedCountry) { newValue in
            if let country = newValue {
                print("Selected Country: \(country.countryName)")
            }
        }
        .onAppear {
            fetchCountries()
        }
    }

    func fetchCountries() {
        guard let url = URL(string: "https://restcountries.com/v3.1/all") else {
            return
        }

        URLSession.shared.dataTask(with: url) { data, _, _ in
            if let data = data {
                do {
                    let countries = try JSONDecoder().decode([Country].self, from: data)
                    DispatchQueue.main.async {
                        self.countries = countries
                    }
                } catch {
                    print("Error decoding countries: \(error)")
                }
            }
        }.resume()
    }
}

struct RegionSelect_Previews: PreviewProvider {
    static var previews: some View {
        RegionSelect()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
            .previewLayout(.sizeThatFits)
            .padding()
    }
}
