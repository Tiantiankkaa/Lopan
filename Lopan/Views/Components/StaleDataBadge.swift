//
//  StaleDataBadge.swift
//  Lopan
//
//  Created by Claude Code on 2025/10/8.
//  Indicator badge for stale cached data with background refresh status
//

import SwiftUI

// MARK: - Stale Data Badge

/// Displays when showing cached data while refreshing in background
/// Shows cache source and refresh status
struct StaleDataBadge: View {
    let cacheSource: CacheSource
    let isRefreshing: Bool

    @State private var pulseAnimation = false

    var body: some View {
        HStack(spacing: LopanSpacing.xs) {
            // Cache source icon
            Image(systemName: sourceIcon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(badgeColor)

            // Status text
            Text(statusText)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(badgeColor)

            // Refreshing indicator
            if isRefreshing {
                ProgressView()
                    .scaleEffect(0.6)
                    .tint(badgeColor)
            }
        }
        .padding(.horizontal, LopanSpacing.sm)
        .padding(.vertical, LopanSpacing.xs)
        .background(
            Capsule()
                .fill(backgroundColor)
                .opacity(pulseAnimation ? 0.9 : 0.7)
        )
        .overlay(
            Capsule()
                .strokeBorder(badgeColor.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
        .onAppear {
            if isRefreshing {
                withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                    pulseAnimation = true
                }
            }
        }
        .transition(.asymmetric(
            insertion: .scale(scale: 0.8).combined(with: .opacity),
            removal: .scale(scale: 0.8).combined(with: .opacity)
        ))
    }

    // MARK: - Computed Properties

    private var statusText: String {
        if isRefreshing {
            return "Updating..."
        } else {
            return "Cached"
        }
    }

    private var sourceIcon: String {
        switch cacheSource {
        case .memory:
            return "bolt.fill"
        case .disk:
            return "internaldrive.fill"
        case .network:
            return "wifi"
        case .prefetch:
            return "arrow.down.circle.fill"
        }
    }

    private var badgeColor: Color {
        switch cacheSource {
        case .memory:
            return .blue
        case .disk:
            return .orange
        case .network:
            return .green
        case .prefetch:
            return .purple
        }
    }

    private var backgroundColor: Color {
        badgeColor.opacity(0.15)
    }
}

// MARK: - Convenience Initializers

extension StaleDataBadge {
    /// Create badge for stale data being refreshed
    static func refreshing(from source: CacheSource) -> StaleDataBadge {
        StaleDataBadge(cacheSource: source, isRefreshing: true)
    }

    /// Create badge for cached data (no refresh)
    static func cached(from source: CacheSource) -> StaleDataBadge {
        StaleDataBadge(cacheSource: source, isRefreshing: false)
    }
}

// MARK: - Overlay Modifier

extension View {
    /// Add stale data badge overlay to top-trailing corner
    func staleDataBadge(
        isShowing: Bool,
        cacheSource: CacheSource?,
        isRefreshing: Bool
    ) -> some View {
        overlay(alignment: .topTrailing) {
            if isShowing, let source = cacheSource {
                StaleDataBadge(cacheSource: source, isRefreshing: isRefreshing)
                    .padding(LopanSpacing.md)
            }
        }
    }
}

// MARK: - Preview

#Preview("Refreshing from Memory") {
    VStack(spacing: 20) {
        StaleDataBadge.refreshing(from: .memory)
        StaleDataBadge.refreshing(from: .disk)
        StaleDataBadge.refreshing(from: .network)
        StaleDataBadge.refreshing(from: .prefetch)
    }
    .padding()
}

#Preview("Cached States") {
    VStack(spacing: 20) {
        StaleDataBadge.cached(from: .memory)
        StaleDataBadge.cached(from: .disk)
        StaleDataBadge.cached(from: .network)
        StaleDataBadge.cached(from: .prefetch)
    }
    .padding()
}

#Preview("On Card") {
    VStack(alignment: .leading, spacing: 12) {
        Text("Customer Name")
            .font(.headline)
        Text("Some content here")
            .font(.subheadline)
        Text("More details...")
            .font(.caption)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding()
    .background(
        RoundedRectangle(cornerRadius: 12)
            .fill(Color(uiColor: .secondarySystemBackground))
    )
    .staleDataBadge(
        isShowing: true,
        cacheSource: .disk,
        isRefreshing: true
    )
    .padding()
}

#Preview("Dark Mode") {
    VStack(spacing: 20) {
        StaleDataBadge.refreshing(from: .memory)
        StaleDataBadge.cached(from: .disk)
    }
    .padding()
    .preferredColorScheme(.dark)
}
