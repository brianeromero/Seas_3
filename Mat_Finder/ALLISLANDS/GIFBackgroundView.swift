//
//  GIFBackgroundView.swift
//  Mat_Finder
//
//  Created by Brian Romero on 6/26/24.
//

import Foundation
import SwiftUI
import UIKit
import ImageIO

struct GIFBackgroundView: UIViewRepresentable {
    let gifName: String

    func makeUIView(context: Context) -> UIView {
        let containerView = UIView()

        DispatchQueue.main.async {
            let gifImageView = UIImageView()
            gifImageView.contentMode = .scaleAspectFill
            gifImageView.clipsToBounds = true

            if let gifURL = Bundle.main.url(forResource: gifName, withExtension: "gif"),
               let gifData = try? Data(contentsOf: gifURL),
               let source = CGImageSourceCreateWithData(gifData as CFData, nil) {
                let count = CGImageSourceGetCount(source)
                var images = [UIImage]()
                var totalDuration: TimeInterval = 0

                for i in 0..<count {
                    if let cgImage = CGImageSourceCreateImageAtIndex(source, i, nil) {
                        let image = UIImage(cgImage: cgImage)
                        images.append(image)

                        if let properties = CGImageSourceCopyPropertiesAtIndex(source, i, nil) as? [String: Any],
                           let gifInfo = properties[kCGImagePropertyGIFDictionary as String] as? [String: Any],
                           let frameDuration = gifInfo[kCGImagePropertyGIFDelayTime as String] as? TimeInterval {
                            totalDuration += frameDuration
                        }
                    }
                }

                gifImageView.animationImages = images
                gifImageView.animationDuration = totalDuration
                gifImageView.startAnimating()
            }

            containerView.addSubview(gifImageView)
            gifImageView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                gifImageView.topAnchor.constraint(equalTo: containerView.topAnchor),
                gifImageView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
                gifImageView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
                gifImageView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
            ])
        }

        return containerView
    }

    func updateUIView(_ uiView: UIView, context: Context) {
    }
}
