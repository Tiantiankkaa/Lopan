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
                .foregroundColor(LopanColors.textPrimary)
                .scaleEffect(iconScale)
                .rotationEffect(.degrees(iconRotation))
            
            Text(actionText)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(LopanColors.textOnPrimary.opacity(0.9))
        }
        .padding(.horizontal, 16)
    }
    
    private var actionColor: Color {
        if isLeftSwipe {
            return LopanColors.error
        } else {
            return item.status == .pending ? LopanColors.success : LopanColors.info
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
        LopanHapticEngine.shared.heavy()
    }
}