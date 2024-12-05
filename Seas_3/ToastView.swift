//
//  ToastView.swift
//  Seas_3
//
//  Created by Brian Romero on 7/3/24.
//

import SwiftUI

struct ToastView: View {
    @Binding var showToast: Bool
    var message: String
    
    var body: some View {
        ZStack {
            if showToast {
                Color.clear
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(
                        Color.black.opacity(0.7)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .edgesIgnoringSafeArea(.all)
                    )
                    .overlay(
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                Text(message)
                                    .padding()
                                    .background(Color.black.opacity(0.7))
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                                    .padding()
                            }
                        }
                    )
            } else {
                EmptyView()
            }
        }
        .onAppear {
            print("ToastView appeared with message: \(message)")
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation {
                    showToast = false
                    print("ToastView dismissed")
                }
            }
        }

    }
}
