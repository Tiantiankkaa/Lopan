//
//  SwipeActionOverlay.swift
//  Lopan
//
//  Created by Claude Code on 2025/8/22.
//

import SwiftUI

struct SwipeActionOverlay: View {
    let offset: CGFloat
    let isLeftSwipe: Bool
    let item: CustomerOutOfStock
    
    @State private var iconScale: CGFloat = 1.0
    @State private var iconRotation: Double = 0
    
    private var progress: CGFloat {
        min(abs(offset) / 100, 1.0)
    }
    
    private var shouldShowOverlay: Bool {
        abs(offset) > 20
    }
    
    var body: some View {
        if shouldShowOverlay {
            HStack {
                if !isLeftSwipe {
                    Spacer()
                }
                
                actionIcon
                
                if isLeftSwipe {
                    Spacer()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(actionColor.opacity(0.8 * progress))
            )
            .onAppear {
                animateIcon()
            }
            .onChange(of: offset) { _, newOffset in
                if abs(newOffset) > 80 {
                    triggerHapticFeedback()
                }
            }
        }
    }
    
    private var actionIcon: some View {
        VStack(spacing: 4) {
            Image(systemName: actionIconName)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .scaleEffect(iconScale)
                .rotationEffect(.degrees(iconRotation))
            
            Text(actionText)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.white.opacity(0.9))
        }
        .padding(.horizontal, 16)
    }
    
    private var actionColor: Color {
        if isLeftSwipe {
            return .red
        } else {
            return item.status == .pending ? .green : .blue
        }
    }
    
    private var actionIconName: String {
        if isLeftSwipe {
            return "trash.fill"
        } else {
            return item.status == .pending ? "checkmark.circle.fill" : "pencil.circle.fill"
        }
    }
    
    private var actionText: String {
        if isLeftSwipe {
            return "删除"
        } else {
            return item.status == .pending ? "完成" : "编辑"
        }
    }
    
    private func animateIcon() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            iconScale = 1.2
        }
        
        withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
            iconRotation = isLeftSwipe ? -10 : 10
        }
    }
    
    private func triggerHapticFeedback() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
        impactFeedback.impactOccurred()
    }
}

// MARK: - Enhanced Card View with Swipe Actions

struct EnhancedOutOfStockCardView: View {
    let item: CustomerOutOfStock
    let isSelected: Bool
    let isInSelectionMode: Bool
    let onTap: () -> Void
    let onLongPress: () -> Void
    let onSwipeAction: (SwipeAction) -> Void
    
    @State private var cardOffset: CGFloat = 0
    @State private var cardScale: CGFloat = 1.0
    @State private var isDragging = false
    @State private var rotationAngle: Double = 0
    @State private var showingActionOverlay = false
    
    private let swipeThreshold: CGFloat = 100
    private let hapticFeedback = UIImpactFeedbackGenerator(style: .light)
    
    enum SwipeAction {
        case delete
        case complete
        case edit
    }
    
    var body: some View {
        ZStack {
            // Background action overlay
            if showingActionOverlay {
                SwipeActionOverlay(
                    offset: cardOffset,
                    isLeftSwipe: cardOffset < 0,
                    item: item
                )
            }
            
            // Main card content
            OutOfStockCardView(
                item: item,
                isSelected: isSelected,
                isInSelectionMode: isInSelectionMode,
                onTap: onTap,
                onLongPress: onLongPress
            )
            .offset(x: cardOffset)
            .scaleEffect(cardScale)
            .rotationEffect(.degrees(rotationAngle))
        }
        .gesture(
            DragGesture()
                .onChanged(handleDragChanged)
                .onEnded(handleDragEnded)
        )
    }
    
    private func handleDragChanged(_ value: DragGesture.Value) {
        if isInSelectionMode { return }
        
        isDragging = true
        showingActionOverlay = true
        
        // Apply resistance for over-swipe
        let translation = value.translation.width
        if abs(translation) > swipeThreshold {
            let excess = abs(translation) - swipeThreshold
            let resistance = swipeThreshold + (excess * 0.3)
            cardOffset = CGFloat(translation > 0 ? resistance : -resistance)
        } else {
            cardOffset = translation
        }
        
        // Add rotation and scale effects
        rotationAngle = Double(cardOffset) * 0.02
        cardScale = 1.0 - abs(cardOffset) * 0.0005
        
        // Trigger haptic feedback at threshold
        if abs(translation) > swipeThreshold && abs(translation) < swipeThreshold + 10 {
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
        }
    }
    
    private func handleDragEnded(_ value: DragGesture.Value) {
        if isInSelectionMode { return }
        
        isDragging = false
        let translation = value.translation.width
        
        if abs(translation) > swipeThreshold {
            // Execute swipe action
            if translation > 0 {
                // Right swipe
                if item.status == .pending {
                    onSwipeAction(.complete)
                } else {
                    onSwipeAction(.edit)
                }
            } else {
                // Left swipe
                onSwipeAction(.delete)
            }
        }
        
        // Reset card position with animation
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            cardOffset = 0
            cardScale = 1.0
            rotationAngle = 0
            showingActionOverlay = false
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        EnhancedOutOfStockCardView(
            item: OutOfStockCardView_Previews.sampleItem,
            isSelected: false,
            isInSelectionMode: false,
            onTap: {},
            onLongPress: {},
            onSwipeAction: { action in
                print("Swipe action: \(action)")
            }
        )
    }
    .padding()
    .background(Color(.systemGray6))
}