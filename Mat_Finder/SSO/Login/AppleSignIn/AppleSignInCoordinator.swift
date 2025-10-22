//
//  AppleSignInCoordinator.swift
//  Mat_Finder
//
//  Created by Brian Romero on 10/22/25.
//


import Foundation
import AuthenticationServices
import CryptoKit
import FirebaseAuth
import UIKit


final class AppleSignInCoordinator: NSObject {
    private var currentNonce: String?

    func startSignInWithAppleFlow(completion: @escaping (Result<AuthDataResult, Error>) -> Void) {
        let nonce = randomNonceString()
        currentNonce = nonce

        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        objc_setAssociatedObject(controller, &AssociatedKeys.completion, completion, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        controller.performRequests()
    }
}

extension AppleSignInCoordinator: ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.windows.first(where: \.isKeyWindow) }
            .first ?? UIWindow()
    }

    func authorizationController(controller: ASAuthorizationController,
                                 didCompleteWithAuthorization authorization: ASAuthorization) {
        guard
            let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
            let rawNonce = currentNonce,
            let appleIDToken = appleIDCredential.identityToken,
            let idTokenString = String(data: appleIDToken, encoding: .utf8)
        else {
            complete(controller, .failure(NSError(domain: "apple.signin", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unable to fetch Apple ID token."])))
            return
        }

        let credential = OAuthProvider.appleCredential(
            withIDToken: idTokenString,
            rawNonce: rawNonce,
            fullName: appleIDCredential.fullName
        )

        Auth.auth().signIn(with: credential) { [weak self] authResult, error in
            if let error = error {
                self?.complete(controller, .failure(error))
            } else if let result = authResult {
                self?.complete(controller, .success(result))
            }
        }
    }


    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        complete(controller, .failure(error))
    }

    private func complete(_ controller: ASAuthorizationController, _ result: Result<AuthDataResult, Error>) {
        if let completion = objc_getAssociatedObject(controller, &AssociatedKeys.completion) as? (Result<AuthDataResult, Error>) -> Void {
            completion(result)
        }
        objc_setAssociatedObject(controller, &AssociatedKeys.completion, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

    private enum AssociatedKeys {
        static var completion: UInt8 = 0
    }

}

// Utilities
private func sha256(_ input: String) -> String {
    let data = Data(input.utf8)
    let hashed = SHA256.hash(data: data)
    return hashed.compactMap { String(format: "%02x", $0) }.joined()
}

private func randomNonceString(length: Int = 32) -> String {
    let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
    var result = ""
    var remaining = length
    while remaining > 0 {
        var randoms = [UInt8](repeating: 0, count: 16)
        _ = SecRandomCopyBytes(kSecRandomDefault, randoms.count, &randoms)
        randoms.forEach { random in
            if remaining == 0 { return }
            if random < charset.count {
                result.append(charset[Int(random)])
                remaining -= 1
            }
        }
    }
    return result
}
