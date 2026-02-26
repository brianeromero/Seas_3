//
//  SwiftUIGIFView.swift
//  Mat_Finder
//
//  Created by Brian Romero on 2/26/26.
//

import Foundation
import SwiftUI
import ImageIO

struct SwiftUIGIFView: View {

    private let images: [UIImage]
    private let duration: Double

    @State private var index: Int = 0

    init(name: String) {

        guard
            let url = Bundle.main.url(forResource: name, withExtension: "gif"),
            let data = try? Data(contentsOf: url),
            let source = CGImageSourceCreateWithData(data as CFData, nil)
        else {
            self.images = []
            self.duration = 0
            return
        }

        let count = CGImageSourceGetCount(source)

        var frames: [UIImage] = []
        var totalDuration: Double = 0

        for i in 0..<count {

            if let cgImage = CGImageSourceCreateImageAtIndex(source, i, nil) {

                let frameDuration =
                    SwiftUIGIFView.frameDuration(at: i, source: source)

                totalDuration += frameDuration

                frames.append(UIImage(cgImage: cgImage))
            }
        }

        self.images = frames
        self.duration = totalDuration
    }

    var body: some View {

        if images.isEmpty {

            EmptyView()

        } else {

            Image(uiImage: images[index])
                .resizable()
                .scaledToFill()
                .onAppear {

                    Timer.scheduledTimer(withTimeInterval:
                        duration / Double(images.count),
                                         repeats: true) { _ in

                        index = (index + 1) % images.count
                    }
                }
        }
    }

    private static func frameDuration(
        at index: Int,
        source: CGImageSource
    ) -> Double {

        guard
            let properties =
                CGImageSourceCopyPropertiesAtIndex(
                    source,
                    index,
                    nil
                ) as? [CFString: Any],

            let gifInfo =
                properties[kCGImagePropertyGIFDictionary]
                as? [CFString: Any],

            let delay =
                gifInfo[kCGImagePropertyGIFDelayTime]
                as? Double
        else {
            return 0.1
        }

        return delay < 0.02 ? 0.1 : delay
    }
}
