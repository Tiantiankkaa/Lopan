//
//  StatusNavigationBar.swift
//  Lopan
//
//  Created by Claude Code on 2025/9/2.
//  iOS 26 native-style status navigation with Liquid Glass and enhanced animations
//

import SwiftUI

// MARK: - Status Tab Definition

enum StatusTab: Int, CaseIterable, Identifiable {
    case all = 0
    case pending = 1
    case completed = 2
    case refunded = 3
    
    var id: Int { rawValue }
    
    var title: String {
        switch self {
        case .all: return "总计"
        case .pending: return "待处理"
        case .completed: return "已完成"
        case .refunded: return "已退货"
        }
    }
    
    var outOfStockStatus: OutOfStockStatus? {
        switch self {
        case .all: return nil
        case .pending: return .pending
        case .completed: return .completed
        case .refunded: return .refunded
        }
    }
    
    static func from(_ status: OutOfStockStatus?) -> StatusTab {
        guard let status = status else { return .all }
        switch status {
        case .pending: return .pending
        case .completed: return .completed
        case .refunded: return .refunded
        }
    }
}

// MARK: - Status Navigation Bar

struct StatusNavigationBar: View {
    @Binding var selection: OutOfStockStatus?
    let statusCounts: [OutOfStockStatus: Int]
    let totalCount: Int
    let isLocked: Bool
    let onSelectionChanged: (OutOfStockStatus?) -> Void
    
    @Namespace private var namespace
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var lastSelection: StatusTab = .all
    
    private var currentTab: StatusTab {
        StatusTab.from(selection)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            statusNavigationHeader
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
    
    // MARK: - Status Navigation Header
    
    private var statusNavigationHeader: some View {
        HStack(spacing: 4) {
            ForEach(StatusTab.allCases) { tab in
                statusButton(for: tab)
            }
        }
        .animation(
            reduceMotion ? .default : .snappy(duration: 0.28, extraBounce: 0.0),
            value: currentTab
        )
    }
    
    // MARK: - Status Button
    
    private func statusButton(for tab: StatusTab) -> some View {
        Button {
            guard !isLocked else {
                // Provide light haptic feedback when locked
                playTabFeedback(style: .light, intensity: 0.5)
                return
            }
            
            lastSelection = currentTab
            let newSelection = tab.outOfStockStatus
            
            // Only notify parent, let parent handle state updates
            onSelectionChanged(newSelection)
            
            // Soft haptic feedback for iOS 17+ native feel
            playTabFeedback(style: .soft, intensity: 0.7)
            
        } label: {
            VStack(spacing: 4) {
                Text(tab.title)
                    .font(.body.weight(.medium))
                    .foregroundColor(isLocked ? .secondary.opacity(0.6) : (currentTab == tab ? LopanColors.primary : .primary))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity)
                
                // Smooth numeric transition using iOS 17+ API
                Text("\(count(for: tab))")
                    .font(.footnote.weight(.medium))
                    .monospacedDigit()
                    .foregroundColor(isLocked ? .secondary.opacity(0.5) : (currentTab == tab ? LopanColors.primary : .secondary))
                    .contentTransition(.numericText(value: Double(count(for: tab))))
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 8)
            .frame(minHeight: 44) // HIG minimum touch target
            .frame(maxWidth: .infinity)
            .background {
                ZStack {
                    if currentTab == tab {
                        Group {
                            if #available(iOS 26.0, *) {
                                LiquidGlassMaterial(
                                    type: .button,
                                    cornerRadius: 12,
                                    isPressed: false
                                )
                                .overlay {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(LopanColors.primary.opacity(0.15))
                                        .blendMode(.overlay)
                                }
                                .matchedGeometryEffect(id: "statusPill", in: namespace)
                            } else {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(LopanColors.primary.opacity(0.12))
                                    .matchedGeometryEffect(id: "statusPill", in: namespace)
                            }
                        }
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(isLocked)
        .opacity(isLocked ? 0.7 : 1.0)
    }
    
    // MARK: - Helper Methods
    
    private func count(for tab: StatusTab) -> Int {
        switch tab {
        case .all:
            return totalCount
        case .pending:
            return statusCounts[.pending] ?? 0
        case .completed:
            return statusCounts[.completed] ?? 0
        case .refunded:
            return statusCounts[.refunded] ?? 0
        }
    }
}

private extension StatusNavigationBar {
    func playTabFeedback(style: UIImpactFeedbackGenerator.FeedbackStyle, intensity: CGFloat) {
        if #available(iOS 17.0, *) {
            let generator = UIImpactFeedbackGenerator(style: style)
            generator.prepare()
            generator.impactOccurred(intensity: intensity)
        } else {
            UIImpactFeedbackGenerator(style: style).impactOccurred()
        }
    }
}


// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        StatusNavigationBar(
            selection: .constant(.pending),
            statusCounts: [
                .pending: 63,
                .completed: 60,
                .refunded: 14
            ],
            totalCount: 137,
            isLocked: false,
            onSelectionChanged: { selection in
                print("Selection changed to: \(selection?.displayName ?? "All")")
            }
        )
        .background(LopanColors.backgroundSecondary)
        
        Text("Locked State:")
            .font(.headline)
        
        StatusNavigationBar(
            selection: .constant(nil),
            statusCounts: [
                .pending: 63,
                .completed: 60,
                .refunded: 14
            ],
            totalCount: 137,
            isLocked: true,
            onSelectionChanged: { _ in }
        )
        .background(LopanColors.backgroundSecondary)
    }
    .padding()
}
