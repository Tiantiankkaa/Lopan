//
//  TabBarIntrospector.swift
//  Lopan
//
//  Created by Claude Code on 2025/10/18.
//

import SwiftUI
import UIKit

// MARK: - Tab Bar Tap Detection

/// Detects taps on the UITabBar, including taps on the currently selected tab
struct TabBarTapDetector: UIViewControllerRepresentable {
    let onTabTapped: (Int) -> Void

    func makeUIViewController(context: Context) -> UIViewController {
        let controller = TabBarInterceptorViewController()
        controller.onTabTapped = onTabTapped
        return controller
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        if let controller = uiViewController as? TabBarInterceptorViewController {
            controller.onTabTapped = onTabTapped
        }
    }
}

/// Helper view controller that introspects and monitors UITabBar
private class TabBarInterceptorViewController: UIViewController {
    var onTabTapped: ((Int) -> Void)?
    private var tabBarObservation: NSKeyValueObservation?
    private var searchAttempts = 0

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        findAndInstrumentTabBar()

        // Retry after delay if not found immediately
        if searchAttempts == 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if self.searchAttempts == 0 {
                    self.findAndInstrumentTabBar()
                }
            }
        }
    }

    private func findAndInstrumentTabBar() {
        searchAttempts += 1

        // Method 1: Search through responder chain
        var responder: UIResponder? = self
        while responder != nil {
            if let tabBarController = responder as? UITabBarController {
                instrumentTabBar(tabBarController.tabBar, controller: tabBarController)
                return
            }
            responder = responder?.next
        }

        // Method 2: Search through view hierarchy
        if let window = view.window {
            if let tabBarController = window.rootViewController as? UITabBarController {
                instrumentTabBar(tabBarController.tabBar, controller: tabBarController)
                return
            }

            // Search children
            findTabBarInHierarchy(window.rootViewController)
        }
    }

    private func findTabBarInHierarchy(_ viewController: UIViewController?) {
        guard let vc = viewController else { return }

        if let tabBarController = vc as? UITabBarController {
            instrumentTabBar(tabBarController.tabBar, controller: tabBarController)
            return
        }

        // Check children
        for child in vc.children {
            findTabBarInHierarchy(child)
        }

        // Check presented view controller
        if let presented = vc.presentedViewController {
            findTabBarInHierarchy(presented)
        }
    }

    private func instrumentTabBar(_ tabBar: UITabBar, controller: UITabBarController) {
        // Add custom tap gesture recognizer with higher priority
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTabBarTap(_:)))
        tapGesture.cancelsTouchesInView = false // Don't interfere with normal tap handling
        tapGesture.delegate = self
        tabBar.addGestureRecognizer(tapGesture)

        // Store reference to tab bar controller for selectedIndex monitoring
        // NOTE: KVO does NOT fire when tapping an already-selected tab
        // So we still need the gesture recognizer for detecting repeat taps
        tabBarObservation = controller.observe(\.selectedIndex, options: [.old, .new]) { [weak self] controller, change in
            if let newIndex = change.newValue, let oldIndex = change.oldValue, newIndex != oldIndex {
                self?.onTabTapped?(newIndex)
            }
        }
    }

    @objc private func handleTabBarTap(_ gesture: UITapGestureRecognizer) {
        guard let tabBar = gesture.view as? UITabBar else { return }

        let location = gesture.location(in: tabBar)
        let currentSelectedIndex = tabBar.items?.firstIndex(of: tabBar.selectedItem ?? UITabBarItem()) ?? -1

        // Find which tab was tapped by checking frames
        var tappedIndex: Int?
        for (index, item) in (tabBar.items ?? []).enumerated() {
            if let view = item.value(forKey: "view") as? UIView {
                let frame = view.frame
                if frame.contains(location) {
                    tappedIndex = index
                    break
                }
            }
        }

        // CRITICAL FIX for iOS 26 minimized tab bar:
        // When tab bar is minimized, frames don't update but visual layout does
        // If hit test finds a different tab than currently selected, it's likely wrong
        // In this case, trust the current selection instead
        let finalIndex: Int
        if let hitIndex = tappedIndex, hitIndex != currentSelectedIndex {
            finalIndex = currentSelectedIndex
        } else if let hitIndex = tappedIndex {
            finalIndex = hitIndex
        } else {
            finalIndex = currentSelectedIndex
        }

        // ALWAYS call the callback with the detected index
        // Let the handler in SalespersonWorkbenchTabView decide what to do
        onTabTapped?(finalIndex)
    }

    deinit {
        tabBarObservation?.invalidate()
    }
}

// MARK: - UIGestureRecognizerDelegate

extension TabBarInterceptorViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // Allow our gesture to work alongside the tab bar's native gesture
        return true
    }
}

// MARK: - SwiftUI View Extension

extension View {
    /// Detects taps on tab bar items, including taps on the currently selected tab
    func onTabBarTap(perform action: @escaping (Int) -> Void) -> some View {
        overlay(
            TabBarTapDetector(onTabTapped: action)
                .frame(width: 1, height: 1)
                .opacity(0.001)  // Nearly invisible but still in view hierarchy
                .allowsHitTesting(false)  // Don't intercept touches
        )
    }
}
