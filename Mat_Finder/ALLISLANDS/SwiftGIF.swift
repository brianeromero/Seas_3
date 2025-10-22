//
//  SwiftGIF.swift
//  Mat_Finder
//
//  Created by Brian Romero on 6/26/24.
//

import Foundation
import UIKit
import SwiftUI
import ImageIO

extension UIImage {
    public class func gifImageWithName(_ name: String) -> UIImage? {
        guard let bundleURL = Bundle.main.url(forResource: name, withExtension: "gif"),
              let imageData = try? Data(contentsOf: bundleURL),
              let source = CGImageSourceCreateWithData(imageData as CFData, nil) else {
            print("SwiftGif: This image named \"\(name)\" does not exist or cannot be loaded!")
            return nil
        }
        
        return gifImageWithSource(source)
    }

    class func delayForImageAtIndex(_ index: Int, source: CGImageSource!) -> Double {
        var delay = 0.1
        
        guard let cfProperties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as NSDictionary?,
              let gifProperties = cfProperties.value(forKey: kCGImagePropertyGIFDictionary as String) as? NSDictionary else {
            return delay
        }

        var delayObject: NSNumber? = gifProperties[kCGImagePropertyGIFUnclampedDelayTime as String] as? NSNumber

        if delayObject?.doubleValue == 0 {
            delayObject = gifProperties[kCGImagePropertyGIFDelayTime as String] as? NSNumber
        }

        delay = delayObject?.doubleValue ?? 0.1

        if delay < 0.1 {
            delay = 0.1
        }

        return delay
    }


    class func gcdForPair(_ a: Int?, _ b: Int?) -> Int {
        var a = a
        var b = b
        if b == nil || a == nil {
            if b != nil {
                return b!
            } else if a != nil {
                return a!
            } else {
                return 0
            }
        }

        if a! < b! {
            let c = a
            a = b
            b = c
        }

        var rest: Int
        while true {
            rest = a! % b!

            if rest == 0 {
                return b!
            } else {
                a = b
                b = rest
            }
        }
    }

    class func gcdForArray(_ array: Array<Int>) -> Int {
        if array.isEmpty {
            return 1
        }

        var gcd = array[0]

        for val in array {
            gcd = gcdForPair(val, gcd)
        }

        return gcd
    }

    class func gifImageWithSource(_ source: CGImageSource) -> UIImage? {
        let count = CGImageSourceGetCount(source)
        var images = [CGImage]()
        var delays = [Int]()

        for i in 0..<count {
            if let image = CGImageSourceCreateImageAtIndex(source, i, nil) {
                images.append(image)
            }

            let delaySeconds = delayForImageAtIndex(i, source: source)
            delays.append(Int(delaySeconds * 1000.0))
        }

        let duration: Int = {
            var sum = 0

            for val in delays {
                sum += val
            }

            return sum
        }()

        let gcd = gcdForArray(delays)
        var frames = [UIImage]()

        var frame: UIImage
        var frameCount: Int

        for i in 0..<count {
            frame = UIImage(cgImage: images[i])
            frameCount = Int(delays[i] / gcd)

            for _ in 0..<frameCount {
                frames.append(frame)
            }
        }

        let animation = UIImage.animatedImage(with: frames, duration: Double(duration) / 1000.0)

        return animation
    }
}

struct GIFView: UIViewRepresentable {
    private let name: String

    init(name: String) {
        self.name = name
    }

    func makeUIView(context: Context) -> UIImageView {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        
        DispatchQueue.main.async {
            if let gifImage = UIImage.gifImageWithName(name) {
                imageView.image = gifImage
            } else {
                // Handle error if gifImageWithName returns nil
                print("Failed to load GIF named: \(name)")
            }
        }

        return imageView
    }

    func updateUIView(_ uiView: UIImageView, context: Context) {}
}
