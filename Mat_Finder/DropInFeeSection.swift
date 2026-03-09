//
//  DropInFeeSection.swift
//  Mat_Finder
//
//  Created by Brian Romero on 3/6/26.
//

 

import SwiftUI

enum HasDropInFee: Int16 {
    case notConfirmed = 0
    case noDropInFee = 1
    case hasFee = 2
}

struct DropInFeeSection: View {

    @Binding var hasDropInFee: HasDropInFee
    @Binding var feeAmount: Double
    @Binding var feeNote: String

    @State private var feeType: String? = "Day Pass"

    private static let feeFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            Text("Drop-In Fee")
                .font(.headline)

            Picker("Drop-In Status", selection: $hasDropInFee) {

                Text("Needs Confirmation")
                    .tag(HasDropInFee.notConfirmed)

                Text("No Drop-In Fee")
                    .tag(HasDropInFee.noDropInFee)

                Text("Fee Required")
                    .tag(HasDropInFee.hasFee)

            }
            .pickerStyle(.segmented)
            .tint(.accentColor)

            // 🔹 Reset fee amount if user switches away from "Fee Required"
            .onChange(of: hasDropInFee) { _, newValue in
                if newValue != .hasFee {
                    feeAmount = 0
                    feeNote = ""
                    feeType = nil
                }
            }

            if hasDropInFee == .hasFee {

                VStack(alignment: .leading, spacing: 12) {

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Amount")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        HStack {
                            Text("$")
                                .foregroundColor(.secondary)

                            TextField(
                                "Amount",
                                value: $feeAmount,
                                formatter: Self.feeFormatter
                            )
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                        }
                        .textFieldStyle(.roundedBorder)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Fee Type")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Picker("Fee Type", selection: Binding(
                            get: { feeType ?? "Day Pass" },
                            set: { feeType = $0 }
                        )) {
                            Text("Per Class").tag("Per Class")
                            Text("Day Pass").tag("Day Pass")
                        }
                        .pickerStyle(.menu)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Additional Notes (Optional)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        TextField(
                            "E.g., First class free, Cash only, etc.",
                            text: $feeNote
                        )
                        .textFieldStyle(.roundedBorder)
                    }
                }
                .padding(.top, 4)
            }
        }
    }
}
