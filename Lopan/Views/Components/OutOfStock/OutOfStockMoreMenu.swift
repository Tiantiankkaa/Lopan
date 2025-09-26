//
//  OutOfStockMoreMenu.swift
//  Lopan
//
//  Created by Claude Code on 2025/8/22.
//

import SwiftUI

struct OutOfStockMoreMenu: View {
    @Binding var isPresented: Bool
    let onExport: () -> Void
    let onRefresh: () -> Void
    let onSettings: () -> Void
    
    var body: some View {
        Menu {
            Button(action: {
                onRefresh()
                isPresented = false
            }) {
                Label("刷新数据", systemImage: "arrow.clockwise")
            }
            
            Button(action: {
                onExport()
                isPresented = false
            }) {
                Label("导出数据", systemImage: "square.and.arrow.up")
            }
            
            Divider()
            
            Button(action: {
                onSettings()
                isPresented = false
            }) {
                Label("设置", systemImage: "gear")
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(LopanColors.info)
                .frame(width: 32, height: 32)
                .background(Circle().fill(LopanColors.primary.opacity(0.1)))
        }
    }
}

#Preview {
    OutOfStockMoreMenu(
        isPresented: .constant(false),
        onExport: {},
        onRefresh: {},
        onSettings: {}
    )
}