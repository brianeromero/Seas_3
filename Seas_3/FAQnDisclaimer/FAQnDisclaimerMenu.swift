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
    // MenuItem must conform to Identifiable and Hashable for use with NavigationStack and navigationDestination
    enum MenuItem: Identifiable, Hashable {
        case whoWeAre
        case disclaimer
        case faq

        // Conformance to Identifiable
        var id: Self { self }
    }
    
    // 1. Change selectedItem to NavigationPath
    @Published var selectedPath = NavigationPath() // Use NavigationPath
    
    // The contentView computed property is no longer needed
    // The navigationDestination(for:) modifier in the view handles presenting the correct view
}

struct FAQnDisclaimerMenuView: View {
    @ObservedObject var menu = FAQnDisclaimerMenu()
    
    // Define a single, consistent size for all icons
    let standardIconSize: CGFloat = 70 // Choose your desired size for all icons
    let iconTrailingSpacing: CGFloat = 10

    var body: some View {
        NavigationStack(path: $menu.selectedPath) {
            VStack(alignment: .leading) {
                List {
                    NavigationLink(value: FAQnDisclaimerMenu.MenuItem.whoWeAre) {
                        HStack(alignment: .center) {
                            Image("MF_little")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: standardIconSize, height: standardIconSize) // NEW: Standardized size
                                .padding(.trailing, iconTrailingSpacing) // Apply spacing directly to the icon
                            
                            Text("Who We Are")
                                .font(.body)
                        }
                        .frame(height: standardIconSize + (iconTrailingSpacing * 2)) // Adjust row height to accommodate icon + padding
                    }
                    
                    NavigationLink(value: FAQnDisclaimerMenu.MenuItem.disclaimer) {
                        HStack(alignment: .center) {
                            Image("disclaimer_logo")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: standardIconSize, height: standardIconSize) // NEW: Standardized size
                                .padding(.trailing, iconTrailingSpacing)
                            
                            Text("Disclaimer")
                                .font(.body)
                        }
                        .frame(height: standardIconSize + (iconTrailingSpacing * 2)) // Adjust row height
                    }
                    
                    NavigationLink(value: FAQnDisclaimerMenu.MenuItem.faq) {
                        HStack(alignment: .center) {
                            Image("faq")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: standardIconSize, height: standardIconSize) // NEW: Standardized size
                                .padding(.trailing, iconTrailingSpacing)
                            
                            Text("FAQ")
                                .font(.body)
                        }
                        .frame(height: standardIconSize + (iconTrailingSpacing * 2)) // Adjust row height
                    }
                }
                .listStyle(InsetGroupedListStyle())
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Spacer()
            }
            .padding(.horizontal)
            .navigationTitle("FAQ & Disclaimer")
            .navigationDestination(for: FAQnDisclaimerMenu.MenuItem.self) { item in
                switch item {
                case .whoWeAre:
                    WhoWeAreView()
                        .onAppear { os_log("WhoWeAreView Appeared", log: FAQnDisclaimerLogger) }
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

// Ensure your PreviewProvider is set up correctly
struct FAQnDisclaimerMenuView_Previews: PreviewProvider {
    static var previews: some View {
        FAQnDisclaimerMenuView()
    }
}
