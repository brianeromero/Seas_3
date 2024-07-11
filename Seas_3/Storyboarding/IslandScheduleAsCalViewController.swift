//
// IslandScheduleAsCalViewController.swift
// Seas_3
// Created by Brian Romero on 7/10/24.

import Foundation
import UIKit
import CoreData

class IslandScheduleAsCalViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    
    @IBOutlet weak var collectionView: UICollectionView?
    var appDayOfWeeks: [AppDayOfWeek] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupCollectionView()
        fetchAppDayOfWeeks()
    }
    
    private func setupCollectionView() {
        // Use optional binding to safely unwrap collectionView
        if let collectionView = collectionView {
            collectionView.dataSource = self
            collectionView.delegate = self
            collectionView.register(UINib(nibName: "AppDayOfWeekCell", bundle: nil), forCellWithReuseIdentifier: AppDayOfWeekCell.reuseIdentifier)
        } else {
            print("collectionView outlet is not connected.")
            // Handle gracefully if collectionView is not connected
        }
    }

    func fetchAppDayOfWeeks() {
        let fetchRequest: NSFetchRequest<AppDayOfWeek> = AppDayOfWeek.fetchRequest()

        do {
            let context = PersistenceController.shared.viewContext
            appDayOfWeeks = try context.fetch(fetchRequest)
            collectionView?.reloadData() // Use optional chaining
        } catch {
            print("Failed to fetch AppDayOfWeek: \(error)")
        }
    }

    // MARK: - UICollectionViewDataSource
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 7 // One section for each day of the week
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return appDayOfWeeks.filter { $0.day == dayForSection(section) }.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: AppDayOfWeekCell.reuseIdentifier, for: indexPath) as! AppDayOfWeekCell
        let filteredDays = appDayOfWeeks.filter { $0.day == dayForSection(indexPath.section) }
        let appDayOfWeek = filteredDays[indexPath.item]
        cell.configure(with: appDayOfWeek)
        return cell
    }

    // MARK: - UICollectionViewDelegateFlowLayout
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: self.view.bounds.width / 7, height: 100) // Adjust the size as needed
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
