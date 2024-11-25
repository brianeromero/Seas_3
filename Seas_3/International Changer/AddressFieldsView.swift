//
//  AddressFieldsView.swift
//  Seas_3
//
//  Created by Brian Romero on 11/22/24.
//

import Foundation
import SwiftUI

struct AddressFieldsView: View {
    @Binding var selectedCountry: Country?
    @Binding var street: String
    @Binding var city: String
    @Binding var state: String
    @Binding var zip: String
    @Binding var neighborhood: String
    @Binding var complement: String
    @Binding var apartment: String
    @Binding var additionalInfo: String

    var body: some View {
        ForEach(getAddressFields(for: selectedCountry?.name.common ?? "US"), id: \.self) { field in
            VStack(alignment: .leading, spacing: 8) {
                Text(getFieldName(for: field))
                TextField("Enter \(getFieldName(for: field))", text: getBinding(for: field))
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
        }
    }

    private func getFieldName(for field: AddressFieldType) -> String {
        switch field {
        case .street:
            return "Street"
        case .city:
            return "City"
        case .state:
            return "State"
        case .postalCode:
            return "Postal Code"
        case .neighborhood:
            return "Neighborhood"
        case .complement:
            return "Complement"
        case .apartment:
            return "Apartment"
        case .additionalInfo:
            return "Additional Info"
        default:
            return ""
        }
    }

    private func getBinding(for field: AddressFieldType) -> Binding<String> {
        switch field {
        case .street:
            return $street
        case .city:
            return $city
        case .state:
            return $state
        case .postalCode:
            return $zip
        case .neighborhood:
            return $neighborhood
        case .complement:
            return $complement
        case .apartment:
            return $apartment
        case .additionalInfo:
            return $additionalInfo
        default:
            return .constant("")
        }
    }

    private func getAddressFields(for country: String) -> [AddressFieldType] {
        let fields = addressFieldRequirements[country] ?? defaultAddressFieldRequirements
        return fields
    }
}


struct AddressFieldsView_Previews: PreviewProvider {
    static var previews: some View {
        AddressFieldsView(
            selectedCountry: .constant(Country(name: Country.Name(common: "United States"), cca2: "US")),
            street: .constant(""),
            city: .constant(""),
            state: .constant(""),
            zip: .constant(""),
            neighborhood: .constant(""),
            complement: .constant(""),
            apartment: .constant(""),
            additionalInfo: .constant("")
        )
        .previewLayout(.sizeThatFits)
    }
}
