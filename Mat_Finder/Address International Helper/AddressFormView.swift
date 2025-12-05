//
// AddressFormView.swift
// Mat_Finder
//
// Created by Brian Romero on 11/18/24.
//

import SwiftUI
import Foundation

struct AddressFormView: View {
    @State private var selectedCountry: String = "US"
    @State private var addressFields: [AddressFieldType: String] = [:]


    var requiredFields: [AddressFieldType] {
        do {
            return try getAddressFields(for: selectedCountry)
        } catch {
            print("Error getting address fields for country code 123 \(selectedCountry): \(error)")
            return [] // Return an empty array if there's an error
        }
    }

    let countryOptions = Array(addressFieldRequirements.keys).sorted()


    var body: some View {
        VStack {
            Picker("Select Country", selection: $selectedCountry) {
                ForEach(countryOptions, id: \.self) { country in
                    Text(country).tag(country)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()


            ForEach(requiredFields, id: \.rawValue) { field in
                AddressFieldView2(field: field, value: binding(for: field))
            }
        }
        .padding()
        .onAppear {
            requiredFields.forEach { addressFields[$0] = "" }
        }
    }
    
    
    func binding(for field: AddressFieldType) -> Binding<String> {
        return Binding<String>(get: {
            addressFields[field] ?? ""
        }, set: {
            addressFields[field] = $0
        })
    }
}


struct AddressFieldView2: View {
    let field: AddressFieldType
    @Binding var value: String


    var body: some View {
        VStack(alignment: .leading) {
            Text(field.rawValue.capitalized)
            TextField("", text: $value)
                .textFieldStyle(RoundedBorderTextFieldStyle())
        }
    }
}

struct AddressFormView_Previews: PreviewProvider {
    static var previews: some View {
        AddressFormView()
    }
}
