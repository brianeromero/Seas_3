//
//  CustomAnalytics.swift
//  Mat_Finder
//
//  Created by Brian Romero on 11/14/24.
//

import Foundation

class CustomAnalytics {
    
    func trackEvent(_ event: String) {
        guard IDFAHelper.getIdfa() != nil else { return }
        // Log event with IDFA
    }
}
