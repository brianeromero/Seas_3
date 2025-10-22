//
//  AppleSignInButtonView.swift
//  Mat_Finder
//
//  Created by Brian Romero on 10/22/25.
//

import Foundation
import SwiftUI
import AuthenticationServices

struct AppleSignInButtonView: View {
    var onRequest: () -> Void
    var onCompletion: (Result<ASAuthorization, Error>) -> Void

    var body: some View {
        SignInWithAppleButton(.signIn) { _ in
            onRequest()
        } onCompletion: { result in
            switch result {
            case .success(let authorization):
                onCompletion(.success(authorization))
            case .failure(let error):
                onCompletion(.failure(error))
            }
        }
        .signInWithAppleButtonStyle(.black)
        .frame(height: 50)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal)
    }
}
