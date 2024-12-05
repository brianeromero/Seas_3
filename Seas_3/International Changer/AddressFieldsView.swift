//
//  AddressFieldsView.swift
//  Seas_3
//
//  Created by Brian Romero on 11/22/24.
//

import Foundation
import SwiftUI

struct AddressFieldsView: View {
    let requiredFields: [AddressFieldType]
    @Binding var islandDetails: IslandDetails

    var body: some View {
        VStack {
            ForEach(requiredFields, id: \.self) { field in
                getTextField(for: field)
            }
        }
    }

    @ViewBuilder
    private func getTextField(for field: AddressFieldType) -> some View {
        switch field {
        case .street:
            TextField("Street", text: $islandDetails.street)
                .textFieldStyle(RoundedBorderTextFieldStyle())
        case .city:
            TextField("City", text: $islandDetails.city)
                .textFieldStyle(RoundedBorderTextFieldStyle())
        case .state:
            TextField("State", text: $islandDetails.state)
                .textFieldStyle(RoundedBorderTextFieldStyle())
        case .province:
            TextField("Province", text: $islandDetails.province)
                .textFieldStyle(RoundedBorderTextFieldStyle())
        case .postalCode:
            TextField("Postal Code", text: $islandDetails.postalCode)
                .textFieldStyle(RoundedBorderTextFieldStyle())
        case .region:
            TextField("Region", text: $islandDetails.region)
                .textFieldStyle(RoundedBorderTextFieldStyle())
        case .district:
            TextField("District", text: $islandDetails.district)
                .textFieldStyle(RoundedBorderTextFieldStyle())
        case .department:
            TextField("Department", text: $islandDetails.department)
                .textFieldStyle(RoundedBorderTextFieldStyle())
        case .governorate:
            TextField("Governorate", text: $islandDetails.governorate)
                .textFieldStyle(RoundedBorderTextFieldStyle())
        case .emirate:
            TextField("Emirate", text: $islandDetails.emirate)
                .textFieldStyle(RoundedBorderTextFieldStyle())
        case .neighborhood:
            TextField("Neighborhood", text: $islandDetails.neighborhood)
                .textFieldStyle(RoundedBorderTextFieldStyle())
        case .complement:
            TextField("Complement", text: $islandDetails.complement)
                .textFieldStyle(RoundedBorderTextFieldStyle())
        case .apartment:
            TextField("Apartment", text: $islandDetails.apartment)
                .textFieldStyle(RoundedBorderTextFieldStyle())
        case .additionalInfo:
            TextField("Additional Info", text: $islandDetails.additionalInfo)
                .textFieldStyle(RoundedBorderTextFieldStyle())
        default:
            EmptyView() // Handle unimplemented cases like .multilineAddress or .block
        }
    }
}

struct AddressFieldsView_Previews: PreviewProvider {
    static var previews: some View {
        AddressFieldsView(
            requiredFields: [.street, .city, .state, .postalCode],
            islandDetails: .constant(IslandDetails())
        )
        .previewLayout(.sizeThatFits)
    }
}
