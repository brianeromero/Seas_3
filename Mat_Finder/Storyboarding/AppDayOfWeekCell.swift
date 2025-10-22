/*//
//  AppDayOfWeekCell.swift
//  Mat_Finder
//
//  Created by Brian Romero on 7/11/24.
//

import Foundation
import UIKit

class AppDayOfWeekCell: UICollectionViewCell {
    static let reuseIdentifier = "AppDayOfWeekCell"

    @IBOutlet weak var matTimeLabel: UILabel!
    @IBOutlet weak var nameLabel: UILabel!

    func configure(with appDayOfWeek: AppDayOfWeek) {
        // Access the matTimes relationship and display the corresponding MatTime objects
        if let matTimes = appDayOfWeek.matTimes {
            let matTimeArray = matTimes.compactMap { $0 as? MatTime }
            let matTimeStrings = matTimeArray.map { $0.time ?? "No time set" }
            matTimeLabel.text = matTimeStrings.joined(separator: ", ")
        } else {
            matTimeLabel.text = "No times set"
        }
        nameLabel.text = appDayOfWeek.name ?? "MISSING"
    }
}
*/
