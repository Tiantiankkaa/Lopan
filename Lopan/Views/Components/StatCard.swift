//
//  StatCard.swift
//  Lopan
//
//  Created by Claude Code on 2025/7/31.
//

import SwiftUI

struct StatCard: View {
    let title: String
    let value: StatCardValue
    let color: Color
    
    enum StatCardValue {
        case count(Int)
        case text(String)
        
        var displayText: String {
            switch self {
            case .count(let count):
                return "\(count)"
            case .text(let text):
                return text
            }
        }
    }
    
    init(title: String, count: Int, color: Color) {
        self.title = title
        self.value = .count(count)
        self.color = color
    }
    
    init(title: String, value: String, color: Color) {
        self.title = title
        self.value = .text(value)
        self.color = color
    }
    
    var body: some View {
        VStack(spacing: 8) {
            Text(value.displayText)
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
}

#Preview {
    HStack {
        StatCard(title: "总数量", count: 42, color: .blue)
        StatCard(title: "利用率", value: "85.2%", color: .green)
    }
    .padding()
}