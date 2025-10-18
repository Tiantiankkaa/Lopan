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
        print("🔧 [TabBarIntrospector] makeUIViewController called - creating TabBarInterceptorViewController")
        let controller = TabBarInterceptorViewController()
        controller.onTabTapped = onTabTapped
        return controller
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        print("🔧 [TabBarIntrospector] updateUIViewController called")
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
        print("🔧 [TabBarIntrospector] viewDidLoad called")
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        print("🔧 [TabBarIntrospector] viewDidAppear called")
        findAndInstrumentTabBar()

        // Retry after delay if not found immediately
        if searchAttempts == 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if self.searchAttempts == 0 {
                    print("🔧 [TabBarIntrospector] Retrying tab bar search after delay...")
                    self.findAndInstrumentTabBar()
                }
            }
        }
    }

    private func findAndInstrumentTabBar() {
        searchAttempts += 1
        print("🔧 [TabBarIntrospector] findAndInstrumentTabBar attempt #\(searchAttempts)")

        // Method 1: Search through responder chain
        print("🔍 [TabBarIntrospector] Method 1: Searching responder chain...")
        var responder: UIResponder? = self
        var depth = 0
        while responder != nil {
            depth += 1
            print("  └─ Responder[\(depth)]: \(type(of: responder!))")

            if let tabBarController = responder as? UITabBarController {
                print("✅ [TabBarIntrospector] Found UITabBarController in responder chain at depth \(depth)!")
                instrumentTabBar(tabBarController.tabBar, controller: tabBarController)
                return
            }
            responder = responder?.next
        }
        print("❌ [TabBarIntrospector] No UITabBarController in responder chain")

        // Method 2: Search through view hierarchy
        print("🔍 [TabBarIntrospector] Method 2: Searching view hierarchy...")
        if let window = view.window {
            print("  └─ Window: \(type(of: window))")
            print("  └─ RootViewController: \(type(of: window.rootViewController!))")

            if let tabBarController = window.rootViewController as? UITabBarController {
                print("✅ [TabBarIntrospector] Found UITabBarController as root!")
                instrumentTabBar(tabBarController.tabBar, controller: tabBarController)
                return
            }

            // Search children
            findTabBarInHierarchy(window.rootViewController)
        } else {
            print("❌ [TabBarIntrospector] No window available")
        }
    }

    private func findTabBarInHierarchy(_ viewController: UIViewController?) {
        guard let vc = viewController else { return }
        print("  └─ Checking: \(type(of: vc))")

        if let tabBarController = vc as? UITabBarController {
            print("✅ [TabBarIntrospector] Found UITabBarController in hierarchy!")
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
        print("🔧 [TabBarIntrospector] Found UITabBar, adding tap gesture recognizer")

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
                print("📍 [TabBarIntrospector] selectedIndex changed: \(oldIndex) → \(newIndex)")
                self?.onTabTapped?(newIndex)
            }
        }
    }

    @objc private func handleTabBarTap(_ gesture: UITapGestureRecognizer) {
        guard let tabBar = gesture.view as? UITabBar else { return }

        let location = gesture.location(in: tabBar)
        let currentSelectedIndex = tabBar.items?.firstIndex(of: tabBar.selectedItem ?? UITabBarItem()) ?? -1

        print("📍 [TabBarIntrospector] ========== TAP DETECTED ==========")
        print("📍 [TabBarIntrospector] Tap location: \(location)")
        print("📍 [TabBarIntrospector] TabBar bounds: \(tabBar.bounds)")
        print("📍 [TabBarIntrospector] TabBar frame: \(tabBar.frame)")
        print("📍 [TabBarIntrospector] Currently selected index: \(currentSelectedIndex)")
        print("📍 [TabBarIntrospector] Number of tab items: \(tabBar.items?.count ?? 0)")

        // Find which tab was tapped by checking frames
        var tappedIndex: Int?
        for (index, item) in (tabBar.items ?? []).enumerated() {
            if let view = item.value(forKey: "view") as? UIView {
                let frame = view.frame
                print("  └─ Tab[\(index)] frame: \(frame), contains tap: \(frame.contains(location))")

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
            print("⚠️ [TabBarIntrospector] Hit test found index \(hitIndex) but current is \(currentSelectedIndex)")
            print("⚠️ [TabBarIntrospector] Likely minimized tab bar - using current index instead")
            finalIndex = currentSelectedIndex
        } else if let hitIndex = tappedIndex {
            print("🎯 [TabBarIntrospector] Hit test found tab at index: \(hitIndex)")
            finalIndex = hitIndex
        } else {
            print("⚠️ [TabBarIntrospector] No tab frame matched tap location, using current: \(currentSelectedIndex)")
            finalIndex = currentSelectedIndex
        }

        // ALWAYS call the callback with the detected index
        // Let the handler in SalespersonWorkbenchTabView decide what to do
        print("📤 [TabBarIntrospector] Calling onTabTapped with index: \(finalIndex)")
        onTabTapped?(finalIndex)
        print("📍 [TabBarIntrospector] =====================================")
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
