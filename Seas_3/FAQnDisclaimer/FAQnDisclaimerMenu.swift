//
//  FAQnDisclaimerMenu.swift
//  Seas_3
//
//  Created by Brian Romero on 6/26/24.
//

import Foundation
import SwiftUI

class FAQnDisclaimerMenu: ObservableObject {
    enum MenuItem {
        case whoWeAre
        case disclaimer
        case faq
    }
    
    @Published var selectedItem: MenuItem? = nil
    
    var contentView: some View {
        switch selectedItem {
        case .whoWeAre:
            return AnyView(WhoWeAreView())
        case .disclaimer:
            return AnyView(DisclaimerView())
        case .faq:
            return AnyView(FAQView())
        case .none:
            return AnyView(EmptyView())
        }
    }
}

struct FAQnDisclaimerMenuView: View {
    @ObservedObject var menu = FAQnDisclaimerMenu()
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading) {
                List {
                    NavigationLink(
                        destination: WhoWeAreView(),
                        tag: .whoWeAre,
                        selection: $menu.selectedItem
                    ) {
                        HStack {
                            Image("MF_little")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 30, height: 30)
                                .padding(.trailing, 10) // Adjust padding as needed
                            
                            Text("Who We Are")
                                .padding(.leading, 10) // Adjust padding as needed
                        }
                    }
                    
                    NavigationLink(
                        destination: DisclaimerView(),
                        tag: .disclaimer,
                        selection: $menu.selectedItem
                    ) {
                        HStack {
                            Image("disclaimer_logo")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 30, height: 30)
                                .padding(.trailing, 10) // Adjust padding as needed
                            
                            Text("Disclaimer")
                                .padding(.leading, 10) // Adjust padding as needed
                        }
                    }
                    
                    NavigationLink(
                        destination: FAQView(),
                        tag: .faq,
                        selection: $menu.selectedItem
                    ) {
                        HStack {
                            Image("faq")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 30, height: 30)
                                .padding(.trailing, 10) // Adjust padding as needed
                            
                            Text("FAQ")
                                .padding(.leading, 10) // Adjust padding as needed
                        }
                    }
                }
                .listStyle(InsetGroupedListStyle())
                .frame(maxWidth: .infinity, alignment: .leading) // Ensure list fills width
                
                Spacer()
                
                menu.contentView
                    .padding(.horizontal)
            }
            .padding(.horizontal) // Add horizontal padding to VStack
            .navigationTitle("FAQ & Disclaimer")
        }
    }
}


struct FAQnDisclaimerMenuView_Previews: PreviewProvider {
    static var previews: some View {
        FAQnDisclaimerMenuView()
    }
}
