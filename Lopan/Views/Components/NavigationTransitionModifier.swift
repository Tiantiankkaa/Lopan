//
//  NavigationTransitionModifier.swift
//  Lopan
//
//  Navigation transition coordinator for smooth tab bar animations
//

import SwiftUI

// MARK: - Navigation Transition Environment Key

struct NavigationTransitionKey: EnvironmentKey {
    @MainActor
    static let defaultValue: NavigationTransitionState = NavigationTransitionState()
}

extension EnvironmentValues {
    var navigationTransition: NavigationTransitionState {
        get { self[NavigationTransitionKey.self] }
        set { self[NavigationTransitionKey.self] = newValue }
    }
}

// MARK: - Navigation Transition State

@MainActor
class NavigationTransitionState: ObservableObject {
    @Published var isTabBarVisible: Bool = true
    @Published var transitionProgress: CGFloat = 0
    @Published var isTransitioning: Bool = false
    
    func hideTabBar(animated: Bool = true) {
        if animated {
            withAnimation(.interactiveSpring(response: 0.35, dampingFraction: 0.86, blendDuration: 0.25)) {
                isTabBarVisible = false
                isTransitioning = true
            }
        } else {
            isTabBarVisible = false
            isTransitioning = true
        }
    }
    
    func showTabBar(animated: Bool = true) {
        if animated {
            // Slightly delayed to coordinate with navigation pop animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                withAnimation(.interactiveSpring(response: 0.35, dampingFraction: 0.86, blendDuration: 0.25)) {
                    self.isTabBarVisible = true
                    self.isTransitioning = false
                }
            }
        } else {
            isTabBarVisible = true
            isTransitioning = false
        }
    }
    
    func updateTransitionProgress(_ progress: CGFloat) {
        transitionProgress = progress
        // Show tab bar when swiping back past 50%
        if progress > 0.5 && !isTabBarVisible {
            showTabBar()
        } else if progress < 0.3 && isTabBarVisible && isTransitioning {
            hideTabBar()
        }
    }
}

// MARK: - Navigation Transition Modifier

struct NavigationTransitionModifier: ViewModifier {
    @StateObject private var transitionState = NavigationTransitionState()
    @State private var dragProgress: CGFloat = 0
    @State private var isDragging: Bool = false
    @State private var screenWidth: CGFloat = 390 // Default iPhone width
    
    func body(content: Content) -> some View {
        GeometryReader { geometry in
            content
                .environment(\.navigationTransition, transitionState)
                .onAppear {
                    screenWidth = geometry.size.width
                }
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            if !isDragging {
                                isDragging = true
                            }
                            // Calculate swipe-back progress
                            let progress = min(max(value.translation.width / screenWidth, 0), 1)
                            dragProgress = progress
                            transitionState.updateTransitionProgress(progress)
                        }
                        .onEnded { value in
                            isDragging = false
                            // Determine if navigation will complete or cancel
                            let velocity = value.predictedEndTranslation.width - value.translation.width
                            let shouldComplete = value.translation.width > screenWidth * 0.5 || velocity > 300
                        
                            if shouldComplete {
                                transitionState.showTabBar()
                            } else {
                                transitionState.hideTabBar()
                            }
                            dragProgress = 0
                        }
                )
        }
    }
}

// MARK: - Tab Bar Transition View

struct TabBarTransition: View {
    @Environment(\.navigationTransition) private var transitionState
    let tabBar: AnyView
    
    var body: some View {
        tabBar
            .offset(y: transitionState.isTabBarVisible ? 0 : 100)
            .opacity(transitionState.isTabBarVisible ? 1 : 0)
            .animation(
                .interactiveSpring(response: 0.35, dampingFraction: 0.86, blendDuration: 0.25),
                value: transitionState.isTabBarVisible
            )
    }
}

// MARK: - Hide Tab Bar On Push Modifier

struct HideTabBarOnPush: ViewModifier {
    @Environment(\.navigationTransition) private var transitionState
    
    func body(content: Content) -> some View {
        content
            .onAppear {
                transitionState.hideTabBar()
            }
            .onDisappear {
                transitionState.showTabBar()
            }
    }
}

// MARK: - Extensions

extension View {
    func navigationTransitionCoordinator() -> some View {
        self.modifier(NavigationTransitionModifier())
    }
    
    func hidesTabBarOnPush() -> some View {
        self.modifier(HideTabBarOnPush())
    }
    
    func tabBarTransition<TabBar: View>(@ViewBuilder tabBar: () -> TabBar) -> some View {
        self.overlay(alignment: .bottom) {
            TabBarTransition(tabBar: AnyView(tabBar()))
        }
    }
}
