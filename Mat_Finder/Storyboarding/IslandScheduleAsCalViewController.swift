/*

//
// IslandScheduleAsCalViewController.swift
// Mat_Finder
// Created by Brian Romero on 7/10/24.

import Foundation
import UIKit
import CoreData

class IslandScheduleAsCalViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {

    @IBOutlet weak var collectionView: UICollectionView!
    var appDayOfWeeks: [AppDayOfWeek] = []
    var repository: AppDayOfWeekRepository = .shared // Dependency Injection

    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupCollectionView()
        fetchAppDayOfWeeks()
    }

    private func setupCollectionView() {
        guard let collectionView = collectionView else {
            print("collectionView outlet is not connected.")
            return
        }
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(AppDayOfWeekCell.self, forCellWithReuseIdentifier: AppDayOfWeekCell.reuseIdentifier)
    }


    private func fetchAppDayOfWeeks() {
        appDayOfWeeks = repository.fetchAllAppDayOfWeeks()
        collectionView.reloadData()
    }

    // MARK: - UICollectionViewDataSource

    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 7 // One section for each day of the week
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return appDayOfWeeks.filter { $0.day == dayForSection(section) }.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: AppDayOfWeekCell.reuseIdentifier, for: indexPath) as? AppDayOfWeekCell else {
            fatalError("Unexpected cell type.")
        }
        let filteredDays = appDayOfWeeks.filter { $0.day == dayForSection(indexPath.section) }
        let appDayOfWeek = filteredDays[indexPath.item]
        cell.configure(with: appDayOfWeek)
        return cell
    }


    // MARK: - UICollectionViewDelegateFlowLayout

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let collectionViewWidth = collectionView.bounds.width
        let itemWidth = collectionViewWidth / 7 // Adjust the size for 7 columns
        return CGSize(width: itemWidth, height: 100) // Adjust the height as needed
    }

    // Helper method to map section index to day string
    private func dayForSection(_ section: Int) -> String {
        switch section {
        case 0: return "sunday"
        case 1: return "monday"
        case 2: return "tuesday"
        case 3: return "wednesday"
        case 4: return "thursday"
        case 5: return "friday"
        case 6: return "saturday"
        default: return ""
        }
    }
}
*/
