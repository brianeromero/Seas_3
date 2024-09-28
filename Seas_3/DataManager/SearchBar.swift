//
//  SearchBar.swift
//  Seas_3
//
//  Created by Brian Romero on 9/28/24.
//

import Foundation
import SwiftUI

struct SearchBar: View {
    @Binding var text: String

    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            GrayPlaceholderTextField("Search...", text: $text)
        }
    }
}

struct GrayPlaceholderTextField: View {
    private let placeholder: String
    @Binding private var text: String

    init(_ placeholder: String, text: Binding<String>) {
        self.placeholder = placeholder
        self._text = text
    }

    var body: some View {
        ZStack(alignment: .leading) {
            if text.isEmpty {
                Text(placeholder)
                    .foregroundColor(.gray)
            }
            TextField("", text: $text)
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(Color(.systemGray6))
                .cornerRadius(8.0)
                .textFieldStyle(PlainTextFieldStyle())
        }
    }
}

struct SearchBar_Previews: PreviewProvider {
    static var previews: some View {
        SearchBar(text: .constant("Search..."))
            .previewLayout(.sizeThatFits)
            .padding()
        
        SearchBar(text: .constant(""))
            .previewLayout(.sizeThatFits)
            .padding()
    }
}
