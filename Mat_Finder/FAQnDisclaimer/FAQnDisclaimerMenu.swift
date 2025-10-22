//
//  FAQnDisclaimerMenu.swift
//  Mat_Finder
//
//  Created by Brian Romero on 6/26/24.
//

import Foundation
import SwiftUI
import os


let FAQnDisclaimerLogger = OSLog(subsystem: "Mat_Finder.Subsystem", category: "FAQnDisclaimer")
// Add other loggers here as needed


class FAQnDisclaimerMenu: ObservableObject {
    enum MenuItem: Identifiable, Hashable {
        case aboutus
        case disclaimer
        case faq

        var id: Self { self } // Conformance to Identifiable
    }
    
    @Published var selectedPath = NavigationPath() // Use NavigationPath
}


struct FAQnDisclaimerMenuView: View {
    // You no longer need a separate NavigationStack here,
    // so you don't need a local navigation path or an ObservableObject.
    
    let standardIconSize: CGFloat = 70
    let iconTrailingSpacing: CGFloat = 10

    var body: some View {
        // REMOVE the NavigationStack from here.
        // It's already in your AppRootView.
        VStack(alignment: .leading) {
            List {
                // These NavigationLinks will now push values to the parent NavigationStack's path.
                NavigationLink(value: AppScreen.aboutus) {
                    MenuItemRow(
                        imageName: "MF_little",
                        text: "About Us",
                        standardIconSize: standardIconSize,
                        iconTrailingSpacing: iconTrailingSpacing
                    )
                }
                
                NavigationLink(value: AppScreen.disclaimer) {
                    MenuItemRow(
                        imageName: "disclaimer_logo",
                        text: "Disclaimer",
                        standardIconSize: standardIconSize,
                        iconTrailingSpacing: iconTrailingSpacing
                    )
                }
                
                NavigationLink(value: AppScreen.faq) {
                    MenuItemRow(
                        imageName: "faq",
                        text: "FAQ",
                        standardIconSize: standardIconSize,
                        iconTrailingSpacing: iconTrailingSpacing
                    )
                }
            }
            .listStyle(InsetGroupedListStyle())
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Spacer()
        }
        .padding(.horizontal)
        .navigationTitle("FAQ & Disclaimer")
        // REMOVE the .navigationDestination modifier.
        // It should only exist on your top-level NavigationStack.
    }
}

// MARK: - Helper View for MenuItem Row
struct MenuItemRow: View {
    let imageName: String
    let text: String
    let standardIconSize: CGFloat
    let iconTrailingSpacing: CGFloat
    
    var body: some View {
        HStack(alignment: .center) {
            Image(imageName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: standardIconSize, height: standardIconSize)
                .padding(.trailing, iconTrailingSpacing)
            
            Text(text)
                .font(.body)
        }
        .frame(height: standardIconSize + (iconTrailingSpacing * 2)) // Consistent row height
    }
}


struct FAQnDisclaimerMenuView_Previews: PreviewProvider {
    static var previews: some View {
        FAQnDisclaimerMenuView()
    }
}
