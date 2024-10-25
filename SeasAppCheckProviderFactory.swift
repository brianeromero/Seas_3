//
//  SeasAppCheckProviderFactory.swift
//  Seas_3
//
//  Created by Brian Romero on 10/21/24.
//

import Foundation
import Firebase
import FirebaseAppCheck

// App Check Provider Factory
class SeasAppCheckProviderFactory: NSObject, AppCheckProviderFactory {
    func createProvider(with app: FirebaseApp) -> AppCheckProvider? {
        #if targetEnvironment(simulator)
          // App Attest is not available on simulators.
          // Use a debug provider.
          let provider = AppCheckDebugProvider(app: app)
          
          // Print only locally generated token to avoid a valid token leak on CI.
          print("Firebase App Check debug token: \(provider?.localDebugToken() ?? "" )")
          
          return provider
        #else
          // Use App Attest provider on real devices.
          guard let provider = AppAttestProvider(app: app) else {
              print("SeasAppCheckProviderFactory: Failed to create AppAttestProvider")
              return nil
          }
          print("SeasAppCheckProviderFactory: AppAttestProvider created successfully")
          return provider
        #endif
    }
}
