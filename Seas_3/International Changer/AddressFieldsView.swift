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
        case .county:
            TextField("County", text: $islandDetails.county)
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
        case .parish:
            TextField("Parish", text: $islandDetails.region) // Assuming 'region' can represent parish
                .textFieldStyle(RoundedBorderTextFieldStyle())
        case .entity:
            TextField("Entity", text: $islandDetails.region) // Assuming 'region' can represent entity
                .textFieldStyle(RoundedBorderTextFieldStyle())
        case .municipality:
            TextField("Municipality", text: $islandDetails.region) // Assuming 'region' can represent municipality
                .textFieldStyle(RoundedBorderTextFieldStyle())
        case .division:
            TextField("Division", text: $islandDetails.region) // Assuming 'region' can represent division
                .textFieldStyle(RoundedBorderTextFieldStyle())
        case .zone:
            TextField("Zone", text: $islandDetails.region) // Assuming 'region' can represent zone
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
        case .island:
            TextField("Island", text: $islandDetails.island)
                .textFieldStyle(RoundedBorderTextFieldStyle())
        case .block:
            TextField("Block", text: $islandDetails.block)
                .textFieldStyle(RoundedBorderTextFieldStyle())
        case .multilineAddress:
            // You may want to use a TextEditor instead of a TextField for multiline addresses
            TextEditor(text: $islandDetails.multilineAddress)
                .frame(height: 100)
                .border(Color.gray)
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
