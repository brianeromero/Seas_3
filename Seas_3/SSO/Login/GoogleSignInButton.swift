//
//  GoogleSignInButton.swift
//  Seas_3
//
//  Created by Brian Romero on 10/3/24.
//

import Foundation
import GoogleSignInSwift
import SwiftUI


struct GoogleSignInButtonView: View {
    var body: some View {
        GoogleSignInButton(action: {
            print("Google Sign-In tapped")
        })
        .frame(height: 50)
        .padding()
    }
}

struct GoogleSignInButtonView_Previews: PreviewProvider {
    static var previews: some View {
        GoogleSignInButtonView()
            .previewLayout(.sizeThatFits)
            .padding()
    }
}
