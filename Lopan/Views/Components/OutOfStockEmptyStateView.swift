//
//  OutOfStockEmptyStateView.swift
//  Lopan
//
//  Created by Claude Code on 2025/8/22.
//

import SwiftUI

struct OutOfStockEmptyStateView: View {
    let hasActiveFilters: Bool
    let onClearFilters: () -> Void
    let onAddNew: () -> Void
    
    @State private var animationOffset: CGFloat = 50
    @State private var animationOpacity: Double = 0
    @State private var pulseScale: CGFloat = 1.0
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Animated illustration
            illustration
            
            // Title and description
            textContent
            
            // Action buttons
            actionButtons
            
            Spacer()
        }
        .padding(.horizontal, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(
                colors: [
                    Color(.systemBackground),
                    Color(.systemGray6).opacity(0.3)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .offset(y: animationOffset)
        .opacity(animationOpacity)
        .onAppear {
            animateEntrance()
        }
    }
    
    // MARK: - Illustration
    
    private var illustration: some View {
        ZStack {
            // Background circle with pulse animation
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.accentColor.opacity(0.1),
                            Color.accentColor.opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 120, height: 120)
                .scaleEffect(pulseScale)
                .animation(
                    .easeInOut(duration: 2.0)
                    .repeatForever(autoreverses: true),
                    value: pulseScale
                )
                .accessibilityHidden(true) // Decorative background
            
            // Main icon
            VStack(spacing: 8) {
                if hasActiveFilters {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .font(.system(size: 40, weight: .light))
                        .foregroundColor(.accentColor)
                        .accessibilityLabel("筛选结果为空")
                } else {
                    Image(systemName: "cube.box")
                        .font(.system(size: 40, weight: .light))
                        .foregroundColor(.accentColor)
                        .accessibilityLabel("暂无数据")
                }
                
                // Decorative dots - hidden from accessibility
                HStack(spacing: 4) {
                    ForEach(0..<3) { index in
                        Circle()
                            .fill(Color.accentColor.opacity(0.6))
                            .frame(width: 6, height: 6)
                            .scaleEffect(pulseScale)
                            .animation(
                                .easeInOut(duration: 1.5)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.2),
                                value: pulseScale
                            )
                            .accessibilityHidden(true)
                    }
                }
                .accessibilityHidden(true) // Decorative animation
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(hasActiveFilters ? "筛选结果为空状态" : "暂无数据状态")
    }
    
    // MARK: - Text Content
    
    private var textContent: some View {
        VStack(spacing: 16) {
            Text(titleText)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
                .accessibilityHeading(.h2)
            
            Text(descriptionText)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .accessibilityLabel(accessibleDescriptionText)
        }
    }
    
    private var accessibleDescriptionText: String {
        // Remove line breaks for screen reader
        return descriptionText.replacingOccurrences(of: "\n", with: ". ")
    }
    
    private var titleText: String {
        if hasActiveFilters {
            return "没有找到匹配的记录"
        } else {
            return "暂无缺货记录"
        }
    }
    
    private var descriptionText: String {
        if hasActiveFilters {
            return "当前筛选条件下没有找到相关的缺货记录\n尝试调整筛选条件或清除筛选"
        } else {
            return "当前日期没有缺货记录\n您可以添加新的缺货记录或选择其他日期"
        }
    }
    
    // MARK: - Action Buttons
    
    private var actionButtons: some View {
        VStack(spacing: 12) {
            if hasActiveFilters {
                // Clear filters button
                Button(action: onClearFilters) {
                    HStack(spacing: 8) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16, weight: .medium))
                            .accessibilityHidden(true) // Decorative icon
                        
                        Text("清除筛选条件")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 48) // Ensure minimum touch target
                    .background(
                        LinearGradient(
                            colors: [Color.orange, Color.orange.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
                }
                .buttonStyle(ScaleButtonStyle())
                .accessibilityLabel("清除筛选条件")
                .accessibilityHint("移除所有筛选条件，显示全部记录")
                .accessibilityAddTraits(.isButton)
                
                // Add new button (secondary)
                Button(action: onAddNew) {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 16, weight: .medium))
                            .accessibilityHidden(true) // Decorative icon
                        
                        Text("添加新记录")
                            .font(.system(size: 16, weight: .medium))
                    }
                    .foregroundColor(.accentColor)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 44) // Ensure minimum touch target
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.accentColor, lineWidth: 1.5)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.accentColor.opacity(0.05))
                            )
                    )
                }
                .buttonStyle(ScaleButtonStyle())
                .accessibilityLabel("添加新记录")
                .accessibilityHint("创建新的缺货记录")
                .accessibilityAddTraits(.isButton)
                
            } else {
                // Add new button (primary)
                Button(action: onAddNew) {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 16, weight: .medium))
                            .accessibilityHidden(true) // Decorative icon
                        
                        Text("添加缺货记录")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 48) // Ensure minimum touch target
                    .background(
                        LinearGradient(
                            colors: [Color.accentColor, Color.accentColor.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
                }
                .buttonStyle(ScaleButtonStyle())
                .accessibilityLabel("添加缺货记录")
                .accessibilityHint("创建新的客户缺货记录")
                .accessibilityAddTraits(.isButton)
                
                // Tips section
                tipsSection
            }
        }
    }
    
    // MARK: - Tips Section
    
    private var tipsSection: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .font(.caption)
                    .foregroundColor(.yellow)
                    .accessibilityHidden(true) // Decorative icon
                
                Text("使用提示")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityHeading(.h3)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 8) {
                tipRow(icon: "calendar", text: "切换日期查看其他日期的缺货记录")
                tipRow(icon: "line.3.horizontal.decrease", text: "使用筛选功能快速找到特定记录")
                tipRow(icon: "magnifyingglass", text: "搜索客户名称、产品或备注信息")
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6).opacity(0.5))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("使用提示")
        .accessibilityValue("切换日期查看其他日期的缺货记录. 使用筛选功能快速找到特定记录. 搜索客户名称、产品或备注信息")
    }
    
    private func tipRow(icon: String, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.accentColor)
                .frame(width: 16)
                .accessibilityHidden(true) // Decorative icon
            
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(nil)
            
            Spacer()
        }
        .accessibilityElement(children: .combine)
    }
    
    // MARK: - Animation Methods
    
    private func animateEntrance() {
        // Staggered entrance animation
        withAnimation(.easeOut(duration: 0.6)) {
            animationOffset = 0
            animationOpacity = 1.0
        }
        
        // Start pulse animation after entrance
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            pulseScale = 1.1
        }
    }
}

// MARK: - Floating Action Hint

struct FloatingActionHint: View {
    let text: String
    @State private var isVisible = false
    
    var body: some View {
        Text(text)
            .font(.caption)
            .fontWeight(.medium)
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.black.opacity(0.8))
            )
            .opacity(isVisible ? 1.0 : 0.0)
            .scaleEffect(isVisible ? 1.0 : 0.8)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isVisible)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    isVisible = true
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    isVisible = false
                }
            }
    }
}

#Preview {
    VStack(spacing: 40) {
        OutOfStockEmptyStateView(
            hasActiveFilters: false,
            onClearFilters: {},
            onAddNew: {}
        )
        .frame(height: 300)
        
        OutOfStockEmptyStateView(
            hasActiveFilters: true,
            onClearFilters: {},
            onAddNew: {}
        )
        .frame(height: 300)
    }
}