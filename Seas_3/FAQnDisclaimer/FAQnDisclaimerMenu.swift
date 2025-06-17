//
//  FAQnDisclaimerMenu.swift
//  Seas_3
//
//  Created by Brian Romero on 6/26/24.
//

import Foundation
import SwiftUI
import os


let FAQnDisclaimerLogger = OSLog(subsystem: "Seas3.Subsystem", category: "FAQnDisclaimer")
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
    // @StateObject is generally preferred for owned objects within a view's lifecycle
    // Use @StateObject here to ensure the menu object is only created once for this view
    @StateObject var menu = FAQnDisclaimerMenu()
    
    let standardIconSize: CGFloat = 70
    let iconTrailingSpacing: CGFloat = 10

    var body: some View {
        NavigationStack(path: $menu.selectedPath) {
            VStack(alignment: .leading) {
                List {
                    // Refactored NavigationLink content for clarity and potential stability
                    // The label for NavigationLink should define its appearance,
                    // the 'value' handles the actual navigation.
                    NavigationLink(value: FAQnDisclaimerMenu.MenuItem.aboutus) {
                        MenuItemRow(
                            imageName: "MF_little",
                            text: "About Us",
                            standardIconSize: standardIconSize,
                            iconTrailingSpacing: iconTrailingSpacing
                        )
                    }
                    
                    NavigationLink(value: FAQnDisclaimerMenu.MenuItem.disclaimer) {
                        MenuItemRow(
                            imageName: "disclaimer_logo",
                            text: "Disclaimer",
                            standardIconSize: standardIconSize,
                            iconTrailingSpacing: iconTrailingSpacing
                        )
                    }
                    
                    NavigationLink(value: FAQnDisclaimerMenu.MenuItem.faq) {
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
            // Define navigation destinations using navigationDestination(for:)
            .navigationDestination(for: FAQnDisclaimerMenu.MenuItem.self) { item in
                switch item {
                case .aboutus:
                    AboutUsView()
                        .onAppear { os_log("AboutUsView Appeared", log: FAQnDisclaimerLogger) }
                case .disclaimer:
                    DisclaimerView()
                        .onAppear { os_log("DisclaimerView Appeared", log: FAQnDisclaimerLogger) }
                case .faq:
                    FAQView()
                        .onAppear { os_log("FAQView Appeared", log: FAQnDisclaimerLogger) }
                }
            }
        }
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
