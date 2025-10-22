/*
 //
//  MainLoginViewController.swift
//  Mat_Finder
//
//  Created by Brian Romero on 7/10/24.
//

import UIKit

class MainLoginViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .red
        
        // Add a button to the view controller
        let button = UIButton(type: .system)
        button.setTitle("Go to Schedule", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = .blue
        button.layer.cornerRadius = 10
        button.addTarget(self, action: #selector(didTapButton), for: .touchUpInside)
        
        // Add button to the view
        button.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(button)
        
        // Set button constraints
        NSLayoutConstraint.activate([
            button.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            button.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            button.widthAnchor.constraint(equalToConstant: 200),
            button.heightAnchor.constraint(equalToConstant: 50)
        ])
    }
    
    @objc func didTapButton() {
        let storyboard = UIStoryboard(name: "MainStoryboard", bundle: nil)
        guard let islandScheduleVC = storyboard.instantiateViewController(withIdentifier: "IslandScheduleAsCalViewController") as? IslandScheduleAsCalViewController else {
            fatalError("Unable to instantiate IslandScheduleAsCalViewController")
        }
        present(islandScheduleVC, animated: true)
    }
}
*/
