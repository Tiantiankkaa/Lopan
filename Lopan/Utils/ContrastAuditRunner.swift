//
//  ContrastAuditRunner.swift
//  Lopan
//
//  Test runner for WCAG contrast audit - iOS 26 Phase 1 compliance
//

import SwiftUI

/// Test runner for contrast audit - use in preview or test target
struct ContrastAuditRunner: View {
    @State private var auditResult: ContrastAuditResult?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Button("Run WCAG Contrast Audit") {
                auditResult = WCAGContrastChecker.auditLopanColors()
                auditResult?.printDetailed()
            }
            .padding()
            .background(LopanColors.primary)
            .foregroundColor(.white)
            .cornerRadius(8)

            if let result = auditResult {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(result.summary)
                            .font(.headline)
                            .padding()
                            .background(LopanColors.backgroundSecondary)
                            .cornerRadius(8)

                        if !result.failedCombinations.isEmpty {
                            Text("Failed Combinations (Need Fixing):")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(LopanColors.error)

                            ForEach(Array(result.failedCombinations.enumerated()), id: \.offset) { index, combo in
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text("\(combo.foregroundName) on \(combo.backgroundName)")
                                            .font(.body)
                                        Text("Ratio: \(String(format: "%.2f", combo.ratio)):1")
                                            .font(.caption)
                                            .foregroundColor(LopanColors.textSecondary)
                                    }
                                    Spacer()
                                    Text(combo.status)
                                        .font(.caption)
                                        .fontWeight(.medium)
                                }
                                .padding(.vertical, 4)
                                .padding(.horizontal, 8)
                                .background(LopanColors.backgroundTertiary)
                                .cornerRadius(4)
                            }
                        }
                    }
                }
            }
        }
        .padding()
    }
}

#Preview {
    ContrastAuditRunner()
}