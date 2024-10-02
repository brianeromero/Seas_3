import Foundation
import SwiftUI

struct InfoTooltip: View {
    let text: String
    let tooltipMessage: String
    @State private var showTooltip = false

    var body: some View {
        HStack {
            Text(text)
            
            // Info button to show/hide the tooltip
            Button(action: {
                print("Tooltip message: \(tooltipMessage)")
                showTooltip.toggle()
            }) {
                Image(systemName: "info.circle")
            }
        }
        .overlay(
            ZStack {
                if showTooltip {
                    Tooltip(text: tooltipMessage)
                        .offset(x: 50, y: 60)
                        .frame(width: 200, height: 100)
                        .background(Color.clear)    
                }
                Rectangle() // Background rectangle
                    .fill(Color.clear) // Transparent background
                    .contentShape(Rectangle()) // Enable tap gesture
                    .onTapGesture {
                        showTooltip.toggle()
                    }
            }
        )
    }
}

struct Tooltip: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 12)) // Specify a system font
            .foregroundColor(.white) // Set text color explicitly
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .background(Color.black.opacity(0.75)) // Use a dark background for better contrast
            .cornerRadius(8)
    }
}


struct InfoTooltip_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            // Add multiple samples to test different messages
            InfoTooltip(text: "Restrictions", tooltipMessage: "e.g., white gis only, competition class, mat fees")
                .padding()
            
            InfoTooltip(text: "Class Type", tooltipMessage: "Indicates if it's a Gi, No-Gi, or Open Mat class.")
                .padding()

            InfoTooltip(text: "Membership", tooltipMessage: "Includes details on membership fees and restrictions.")
                .padding()
        }
        .previewLayout(.sizeThatFits) // Ensures a compact view in the preview
    }
}
