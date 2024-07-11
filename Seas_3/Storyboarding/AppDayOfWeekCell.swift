//
//  AppDayOfWeekCell.swift
//  Seas_3
//
//  Created by Brian Romero on 7/11/24.
//

import Foundation
import UIKit

class AppDayOfWeekCell: UICollectionViewCell {
    static let reuseIdentifier = "AppDayOfWeekCell"

    @IBOutlet weak var matTimeLabel: UILabel!
    @IBOutlet weak var nameLabel: UILabel!

    @IBOutlet weak var ContentView: UIView!
    func configure(with appDayOfWeek: AppDayOfWeek) {
        matTimeLabel.text = appDayOfWeek.matTime
        nameLabel.text = appDayOfWeek.name
    }
}
