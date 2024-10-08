//
//  GoogleSignInButton.swift
//  Seas_3
//
//  Created by Brian Romero on 10/3/24.
//

import Foundation
import SwiftUI
import GoogleSignIn

struct GoogleSignInButton: UIViewRepresentable {
    func makeUIView(context: Context) -> GIDSignInButton {
        let button = GIDSignInButton()
        return button
    }
    
    func updateUIView(_ uiView: GIDSignInButton, context: Context) {}
}

struct GoogleSignInButton_Previews: PreviewProvider {
    static var previews: some View {
        GoogleSignInButton()
            .previewLayout(.sizeThatFits)
            .padding()
    }
}
