// AddressFormView.swift
// Seas_3
//
// Created by Brian Romero on 11/18/24.
//


import SwiftUI
import Foundation

struct AddressFormView: View {
    @State private var selectedCountry: String = "US"
    @State private var street: String = ""
    @State private var city: String = ""
    @State private var state: String = ""
    @State private var province: String = ""
    @State private var postalCode: String = ""
    @State private var postcode: String = ""
    @State private var governorate: String = ""
    @State private var region: String = ""
    @State private var district: String = ""
    @State private var department: String = ""
    @State private var emirate: String = ""
    @State private var pincode: String = ""
    @State private var block: String = ""
    @State private var county: String = ""
    @State private var neighborhood: String = ""
    @State private var complement: String = ""
    @State private var apartment: String = ""
    @State private var islandDetails: IslandDetails = IslandDetails()


    // Fetch required address fields based on the selected country
    var requiredFields: [AddressFieldType] {
        getAddressFields(for: selectedCountry)
    }

    // Country options from addressFieldRequirements dictionary
    let countryOptions = Array(addressFieldRequirements.keys).sorted()

    var body: some View {
        VStack {
            // Country Picker
            Picker("Select Country", selection: $selectedCountry) {
                ForEach(countryOptions, id: \.self) { country in
                    Text(country).tag(country)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()
            .onChange(of: selectedCountry) { newCountry in
                print("Country selected: \(newCountry)")  // Log country change
            }

            // Dynamically display required fields based on selected country
            ForEach(requiredFields, id: \.rawValue) { field in
                Text("Rendering field: \(field.rawValue)")
                    .onAppear {
                        print("Rendering field: \(field.rawValue) for country \(selectedCountry)")
                    }
                addressField(for: field)
            }
        }
        .padding()
    }

    // Function to display the appropriate address field
    func addressField(for field: AddressFieldType) -> some View {
        AddressFieldView(field: AddressField(rawValue: field.rawValue)!, islandDetails: $islandDetails)
    }

    // Return the correct Binding for each field
    func binding(for field: AddressFieldType) -> Binding<String> {
        switch field {
        case .street: return $street
        case .city: return $city
        case .state: return $state
        case .province: return $province
        case .postalCode, .postcode, .pincode: return $postalCode
        case .governorate: return $governorate
        case .region: return $region
        case .district: return $district
        case .department: return $department
        case .emirate: return $emirate
        case .block: return $block
        case .county: return $county
        case .neighborhood: return $neighborhood
        case .complement: return $complement
        case .apartment: return $apartment
        case .additionalInfo: return .constant("")
        case .multilineAddress: return .constant("")
        }
    }
}

struct AddressFormView_Previews: PreviewProvider {
    static var previews: some View {
        AddressFormView()
    }
}
