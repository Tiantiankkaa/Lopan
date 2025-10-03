//
//  AlphabeticalSectionIndexView.swift
//  Lopan
//
//  Created by Claude Code on 2025/10/02.
//

import SwiftUI

/// Alphabetical section index view for quick navigation
/// Displays A-Z letters on the right side of a scrollable list
struct AlphabeticalSectionIndexView: View {
    let availableLetters: Set<String>
    let onLetterTap: (String) -> Void

    // All letters A-Z
    private let allLetters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
        .map { String($0) }

    @State private var highlightedLetter: String?

    var body: some View {
        VStack(spacing: 2) {
            ForEach(allLetters, id: \.self) { letter in
                letterButton(letter)
            }
        }
        .padding(.vertical, LopanSpacing.xs)
        .padding(.horizontal, LopanSpacing.xxs)
        .background {
            RoundedRectangle(cornerRadius: LopanSpacing.lg)
                .fill(.ultraThinMaterial)
                .shadow(color: LopanColors.shadow.opacity(0.3), radius: 2, x: 0, y: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("字母索引")
    }

    @ViewBuilder
    private func letterButton(_ letter: String) -> some View {
        let isAvailable = availableLetters.contains(letter)

        Button(action: {
            if isAvailable {
                highlightedLetter = letter
                onLetterTap(letter)

                // Clear highlight after animation
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    highlightedLetter = nil
                }
            }
        }) {
            Text(letter)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundColor(
                    isAvailable
                        ? (highlightedLetter == letter ? LopanColors.textOnPrimary : LopanColors.primary)
                        : LopanColors.textTertiary.opacity(0.3)
                )
                .frame(width: 16, height: 16)
                .background(
                    highlightedLetter == letter
                        ? Circle().fill(LopanColors.primary)
                        : Circle().fill(Color.clear)
                )
                .scaleEffect(highlightedLetter == letter ? 1.2 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: highlightedLetter)
        }
        .disabled(!isAvailable)
        .accessibilityLabel("字母 \(letter)")
        .accessibilityHint(isAvailable ? "点击跳转到 \(letter) 开头的客户" : "暂无 \(letter) 开头的客户")
        .accessibilityAddTraits(isAvailable ? .isButton : [])
    }
}

// MARK: - Previews

#Preview("Full Index") {
    AlphabeticalSectionIndexView(
        availableLetters: Set(["A", "E", "I", "L", "N", "O"]),
        onLetterTap: { letter in
            print("Tapped letter: \(letter)")
        }
    )
    .padding()
    .background(LopanColors.backgroundPrimary)
}

#Preview("With ScrollView") {
    ZStack(alignment: .trailing) {
        ScrollView {
            VStack(alignment: .leading, spacing: LopanSpacing.md) {
                ForEach(["A", "E", "I", "L", "N", "O"], id: \.self) { letter in
                    VStack(alignment: .leading, spacing: LopanSpacing.sm) {
                        Text(letter)
                            .font(LopanTypography.headlineSmall)
                            .foregroundColor(LopanColors.textPrimary)
                            .padding(.horizontal)

                        ForEach(0..<3, id: \.self) { index in
                            Text("\(letter) Customer \(index + 1)")
                                .font(LopanTypography.bodyMedium)
                                .foregroundColor(LopanColors.textSecondary)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(LopanColors.surface)
                                .cornerRadius(LopanSpacing.sm)
                                .padding(.horizontal)
                        }
                    }
                }
            }
            .padding(.vertical)
        }

        AlphabeticalSectionIndexView(
            availableLetters: Set(["A", "E", "I", "L", "N", "O"]),
            onLetterTap: { letter in
                print("Tapped letter: \(letter)")
            }
        )
        .padding(.trailing, 4)
    }
    .background(LopanColors.backgroundPrimary)
}

#Preview("All Letters Available") {
    AlphabeticalSectionIndexView(
        availableLetters: Set("ABCDEFGHIJKLMNOPQRSTUVWXYZ".map { String($0) }),
        onLetterTap: { letter in
            print("Tapped letter: \(letter)")
        }
    )
    .padding()
    .background(LopanColors.backgroundPrimary)
}
