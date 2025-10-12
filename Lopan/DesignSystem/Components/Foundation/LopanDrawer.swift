//
//  LopanDrawer.swift
//  Lopan
//
//  Created by Factory on 2025/12/31.
//

import SwiftUI

/// Reusable drawer component for slide-in panels and overlays
/// Supports different edge positions, customizable width, and backdrop
public struct LopanDrawer<Content: View>: View {
    // MARK: - Properties
    @Binding var isPresented: Bool
    let edge: Edge
    let width: CGFloat?
    let showBackdrop: Bool
    let backdropOpacity: Double
    let content: Content
    
    // MARK: - Initializers
    public init(
        isPresented: Binding<Bool>,
        edge: Edge = .leading,
        width: CGFloat? = LopanSpacing.drawerWidth,
        showBackdrop: Bool = true,
        backdropOpacity: Double = 0.3,
        @ViewBuilder content: () -> Content
    ) {
        self._isPresented = isPresented
        self.edge = edge
        self.width = width
        self.showBackdrop = showBackdrop
        self.backdropOpacity = backdropOpacity
        self.content = content()
    }
    
    // MARK: - Body
    public var body: some View {
        ZStack {
            // Backdrop
            if isPresented && showBackdrop {
                Color.black.opacity(backdropOpacity)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            isPresented = false
                        }
                    }
                    .zIndex(30)
            }
            
            // Drawer Content
            if isPresented {
                drawerContent
                    .transition(.asymmetric(
                        insertion: .move(edge: edge),
                        removal: .move(edge: edge)
                    ))
                    .zIndex(40)
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isPresented)
    }
    
    private var drawerContent: some View {
        HStack {
            if edge == .trailing {
                Spacer()
            }
            
            VStack {
                content
            }
            .frame(width: width)
            .frame(maxHeight: .infinity)
            .background(LopanColors.filterDrawerBackground)
            .lopanShadow(LopanShadows.modal)
            
            if edge == .leading {
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Drawer Header Component

/// Standard header for drawer components
public struct LopanDrawerHeader: View {
    let title: String
    let onClose: () -> Void
    let showCloseButton: Bool
    
    public init(
        title: String,
        showCloseButton: Bool = true,
        onClose: @escaping () -> Void
    ) {
        self.title = title
        self.showCloseButton = showCloseButton
        self.onClose = onClose
    }
    
    public var body: some View {
        HStack {
            Text(title)
                .lopanHeadlineMedium()
                .foregroundColor(LopanColors.textPrimary)
            
            Spacer()
            
            if showCloseButton {
                Button(action: {
                    LopanHapticEngine.shared.light()
                    onClose()
                }) {
                    Image(systemName: "xmark")
                        .lopanBodyLarge()
                        .foregroundColor(LopanColors.textSecondary)
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
            }
        }
        .padding(LopanSpacing.drawerPadding)
    }
}

// MARK: - Drawer Action Buttons

/// Standard action buttons for drawer footers
public struct LopanDrawerActions: View {
    let primaryTitle: String
    let primaryAction: () -> Void
    let secondaryTitle: String?
    let secondaryAction: (() -> Void)?
    let isDestructive: Bool
    
    public init(
        primaryTitle: String,
        primaryAction: @escaping () -> Void,
        secondaryTitle: String? = nil,
        secondaryAction: (() -> Void)? = nil,
        isDestructive: Bool = false
    ) {
        self.primaryTitle = primaryTitle
        self.primaryAction = primaryAction
        self.secondaryTitle = secondaryTitle
        self.secondaryAction = secondaryAction
        self.isDestructive = isDestructive
    }
    
    public var body: some View {
        VStack(spacing: LopanSpacing.sm) {
            // Primary Button
            Button(action: {
                LopanHapticEngine.shared.medium()
                primaryAction()
            }) {
                Text(primaryTitle)
                    .lopanButtonMedium()
                    .foregroundColor(LopanColors.textOnPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, LopanSpacing.sm)
                    .background(isDestructive ? LopanColors.error : LopanColors.primary)
                    .clipShape(RoundedRectangle(cornerRadius: LopanCornerRadius.button))
            }
            
            // Secondary Button (Optional)
            if let secondaryTitle = secondaryTitle,
               let secondaryAction = secondaryAction {
                Button(action: {
                    LopanHapticEngine.shared.light()
                    secondaryAction()
                }) {
                    Text(secondaryTitle)
                        .lopanButtonMedium()
                        .foregroundColor(LopanColors.textPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, LopanSpacing.sm)
                        .overlay(
                            RoundedRectangle(cornerRadius: LopanCornerRadius.button)
                                .stroke(LopanColors.border, lineWidth: 1)
                        )
                }
            }
        }
        .padding(LopanSpacing.drawerPadding)
    }
}

// MARK: - View Extension

public extension View {
    /// Adds a drawer overlay to any view
    func lopanDrawer<Content: View>(
        isPresented: Binding<Bool>,
        edge: Edge = .leading,
        width: CGFloat? = LopanSpacing.drawerWidth,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        self.overlay(
            LopanDrawer(
                isPresented: isPresented,
                edge: edge,
                width: width,
                content: content
            )
        )
    }
}

// MARK: - Preview

#if DEBUG
struct LopanDrawer_Previews: PreviewProvider {
    struct PreviewContainer: View {
        @State private var showDrawer = true
        
        var body: some View {
            ZStack {
                // Main Content
                VStack {
                    Button("Show Drawer") {
                        showDrawer = true
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(LopanColors.backgroundSecondary)
                
                // Drawer
                LopanDrawer(isPresented: $showDrawer) {
                    VStack(spacing: 0) {
                        LopanDrawerHeader(
                            title: "Filters",
                            onClose: { showDrawer = false }
                        )
                        
                        ScrollView {
                            VStack(alignment: .leading, spacing: LopanSpacing.lg) {
                                // Sample filter content
                                VStack(alignment: .leading, spacing: LopanSpacing.sm) {
                                    Text("Status")
                                        .lopanLabelMedium()
                                        .foregroundColor(LopanColors.textSecondary)
                                    
                                    ForEach(["All", "Active", "Low Stock", "Inactive"], id: \.self) { status in
                                        HStack {
                                            Text(status)
                                                .lopanBodyMedium()
                                            Spacer()
                                            if status == "All" {
                                                Image(systemName: "checkmark")
                                                    .foregroundColor(LopanColors.primary)
                                            }
                                        }
                                        .padding(.vertical, LopanSpacing.xs)
                                    }
                                }
                                
                                Divider()
                                
                                VStack(alignment: .leading, spacing: LopanSpacing.sm) {
                                    Text("Price Range")
                                        .lopanLabelMedium()
                                        .foregroundColor(LopanColors.textSecondary)
                                    
                                    Slider(value: .constant(50), in: 0...100)
                                        .tint(LopanColors.primary)
                                }
                            }
                            .padding(.horizontal, LopanSpacing.drawerPadding)
                        }
                        
                        Spacer()
                        
                        LopanDrawerActions(
                            primaryTitle: "Apply Filters",
                            primaryAction: { showDrawer = false },
                            secondaryTitle: "Reset",
                            secondaryAction: { }
                        )
                    }
                }
            }
        }
    }
    
    static var previews: some View {
        PreviewContainer()
    }
}
#endif
