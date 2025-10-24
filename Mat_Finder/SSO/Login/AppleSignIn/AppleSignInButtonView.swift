//
//  AppleSignInButtonView.swift
//  Mat_Finder
//
//  Created by Brian Romero on 10/22/25.
//

import AuthenticationServices
import FirebaseAuth
import SwiftUI
import CryptoKit

struct AppleSignInButtonView: View {
    var onCompletion: (Result<AuthDataResult, Error>) -> Void
    @State private var coordinator = AppleSignInCoordinator()

    var body: some View {
        Button {
            coordinator.startSignInWithAppleFlow { result in
                onCompletion(result)
            }
        } label: {
            Image(systemName: "apple.logo")
                .resizable()
                .scaledToFit()
                .foregroundColor(.black)
                .frame(width: 24, height: 24)
        }
        .frame(width: 50, height: 50)
        .background(Color.white)
        .cornerRadius(8)
    }
}
