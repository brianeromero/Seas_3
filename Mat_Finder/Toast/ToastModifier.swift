//
//  ToastModifier.swift
//  Mat_Finder
//
//  Created by Brian Romero on 7/3/25.
//

import Foundation
import SwiftUI

// MARK: - Record Name Mapping
struct ToastRecordNames {
    static let displayNames: [String: String] = [
        "pirateIslands": "Gym",
        "AppDayOfWeek": "Daily Schedule",
        "MatTime": "Mat Schedule",
        "reviews": "Review"
    ]
    
    static func displayName(for key: String) -> String {
        displayNames[key] ?? key.capitalized
    }
}

// MARK: - ToastModifier
struct ToastModifier: ViewModifier {
    @Binding var isPresenting: Bool
    @State private var currentMessage: String = ""
    @State private var currentType: ToastView.ToastType = .custom
    @State private var isPersistent: Bool = false

    let duration: TimeInterval
    let alignment: Alignment
    let verticalOffset: CGFloat

    func body(content: Content) -> some View {
        ZStack(alignment: alignment) {
            content

            if isPresenting {
                ToastView(message: currentMessage, type: currentType)
                    .transition(.asymmetric(
                        insertion: .scale.combined(with: .opacity)
                            .animation(.spring(response: 0.35, dampingFraction: 0.8)),
                        removal: .opacity.animation(.easeOut(duration: 0.4))
                    ))
                    .offset(y: verticalOffset)
                    .zIndex(10)
                    .onAppear {
                        print("🍞 [ToastModifier] Appeared — persistent: \(isPersistent)")

                        guard !isPersistent else { return }
                        // ✅ Ensure minimum readable display time
                        let minDisplayTime: TimeInterval = 2.5
                        let displayTime = max(duration, minDisplayTime)

                        DispatchQueue.main.asyncAfter(deadline: .now() + displayTime) {
                            withAnimation(.easeInOut(duration: 0.4)) {
                                isPresenting = false
                            }
                            print("💨 [ToastModifier] Auto-dismissed after \(displayTime)s")
                        }
                    }
            }
        }

        // MARK: - Show Listener
        .onReceive(NotificationCenter.default.publisher(for: .showToast)) { notification in
            guard let info = notification.userInfo,
                  let msg = info["message"] as? String,
                  let typeRaw = info["type"] as? String,
                  let toastType = ToastView.ToastType(rawValue: typeRaw),
                  let persistent = info["isPersistent"] as? Bool else { return }

            print("""
            🔔 [ToastModifier] Received .showToast →
            - message: "\(msg)"
            - type: \(toastType)
            - persistent: \(persistent)
            """)

            withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
                currentMessage = msg
                currentType = toastType
                isPersistent = persistent
                isPresenting = true
            }
        }

        // MARK: - Hide Listener
        .onReceive(NotificationCenter.default.publisher(for: .hideToast)) { _ in
            if isPresenting {
                print("🟢 [ToastModifier] Received .hideToast — dismissing")
                withAnimation(.easeInOut(duration: 0.3)) {
                    isPresenting = false
                }
            }
        }
    }
}

// MARK: - Toast Throttler
final class ToastThrottler {
    static let shared = ToastThrottler()
    private var lastShown: [String: Date] = [:]
    private let throttleInterval: TimeInterval = 3.0
    private let queue = ToastQueue()

    private init() {}

    func postToast(
        for recordKey: String,
        action: String = "updated",
        type: ToastView.ToastType = .success,
        isPersistent: Bool = false
    ) {
        let displayName = ToastRecordNames.displayName(for: recordKey)
        let formattedAction = action.prefix(1).capitalized + action.dropFirst()
        let message = "\(displayName): \(formattedAction)"

        let key = "\(recordKey)_\(action)_\(type.rawValue)"
        let now = Date()
        if let last = lastShown[key], now.timeIntervalSince(last) < throttleInterval {
            print("⏸️ [ToastThrottler] Skipping duplicate toast: \(message)")
            return
        }

        lastShown[key] = now
        queue.enqueue(message: message, type: type, isPersistent: isPersistent)
    }
}

// MARK: - Toast Queue
final class ToastQueue {
    static let shared = ToastQueue()
    private var queue: [(String, ToastView.ToastType, Bool)] = []
    private var isDisplaying = false

    func enqueue(message: String, type: ToastView.ToastType, isPersistent: Bool = false) {
        queue.append((message, type, isPersistent))
        processNext()
    }

    private func processNext() {
        guard !isDisplaying, !queue.isEmpty else { return }

        let (msg, type, persistent) = queue.removeFirst()
        isDisplaying = true

        NotificationCenter.default.post(name: .showToast, object: nil, userInfo: [
            "message": msg,
            "type": type.rawValue,
            "isPersistent": persistent
        ])

        // ✅ Enforce minimum readable duration before showing next
        let duration = persistent ? 5.0 : 3.0
        let fadeBuffer: TimeInterval = 0.4

        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            NotificationCenter.default.post(name: .hideToast, object: nil)
            self.isDisplaying = false
            DispatchQueue.main.asyncAfter(deadline: .now() + fadeBuffer) {
                self.processNext()
            }
        }
    }
}

// MARK: - View Extension
extension View {
    func showToast(
        isPresenting: Binding<Bool>,
        duration: TimeInterval = 3.0,
        alignment: Alignment = .top,
        verticalOffset: CGFloat = 60
    ) -> some View {
        modifier(
            ToastModifier(
                isPresenting: isPresenting,
                duration: duration,
                alignment: alignment,
                verticalOffset: verticalOffset
            )
        )
    }
}
