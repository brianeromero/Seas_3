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
    @State private var zip: String = "" // Added `zip` field
    @State private var region: String = "" // Added `region` field
    @State private var district: String = "" // Added `district` field
    @State private var department: String = "" // Added `department` field
    @State private var emirate: String = "" // Added `emirate` field
    @State private var pincode: String = "" // Added `pincode` field
    @State private var block: String = "" // Added `block` field
    @State private var county: String = "" // Added `county` field
    @State private var neighborhood: String = ""
    @State private var complement: String = ""
    @State private var apartment: String = ""

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
        VStack(alignment: .leading) {
            Text(field.rawValue.capitalized)
            TextField("Enter \(field.rawValue.capitalized)", text: binding(for: field))
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()
                .onChange(of: binding(for: field).wrappedValue) { newValue in
                    print("Field \(field.rawValue) updated to: \(newValue)")  // Log field changes
                }
        }
    }

    // Return the correct Binding for each field
    func binding(for field: AddressFieldType) -> Binding<String> {
        switch field {
        case .street: return $street
        case .city: return $city
        case .state: return $state
        case .province: return $province
        case .postalCode: return $postalCode
        case .postcode: return $postcode
        case .governorate: return $governorate
        case .zip: return $zip
        case .region: return $region
        case .district: return $district
        case .department: return $department
        case .emirate: return $emirate
        case .pincode: return $pincode
        case .block: return $block
        case .county: return $county
        case .neighborhood: return $neighborhood
        case .complement: return $complement
        case .apartment: return $apartment
        case .additionalInfo: return .constant("") // Placeholder for future fields
        case .multilineAddress: return .constant("") // Placeholder for future fields
        }
    }
}

struct AddressFormView_Previews: PreviewProvider {
    static var previews: some View {
        AddressFormView()
    }
}
