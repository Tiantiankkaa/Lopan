//
//  CustomerCardView.swift
//  Lopan
//
//  Created by Claude Code on 2025/10/02.
//

import SwiftUI

/// Enhanced customer card with contextual menu and modern design
struct CustomerCardView: View {
    let customer: Customer
    let onCall: (() -> Void)?
    let onMessage: (() -> Void)?
    let onEdit: (() -> Void)?
    let onToggleFavorite: (() -> Void)?
    let onDelete: (() -> Void)?

    init(
        customer: Customer,
        onCall: (() -> Void)? = nil,
        onMessage: (() -> Void)? = nil,
        onEdit: (() -> Void)? = nil,
        onToggleFavorite: (() -> Void)? = nil,
        onDelete: (() -> Void)? = nil
    ) {
        self.customer = customer
        self.onCall = onCall
        self.onMessage = onMessage
        self.onEdit = onEdit
        self.onToggleFavorite = onToggleFavorite
        self.onDelete = onDelete
    }

    var body: some View {
        HStack(spacing: LopanSpacing.md) {
            // Avatar - use customer object for photo/color support
            CustomerAvatarView(customer: customer, size: 48)

            // Customer Info
            VStack(alignment: .leading, spacing: LopanSpacing.xxs) {
                Text(customer.name)
                    .font(LopanTypography.bodyLarge)
                    .foregroundColor(LopanColors.textPrimary)

                // Line 2: Location (City, Region, Country)
                Text(customer.displaySubtitle)
                    .font(LopanTypography.bodySmall)
                    .foregroundColor(LopanColors.textSecondary)
                    .lineLimit(1)

                // Line 3: Formatted phone number
                if !customer.phone.isEmpty {
                    Text(customer.formattedPhone)
                        .font(LopanTypography.bodySmall)
                        .foregroundColor(LopanColors.textSecondary)
                }
            }

            Spacer()

            // Favorite star button
            Button(action: {
                onToggleFavorite?()
            }) {
                Image(systemName: customer.isFavorite ? "star.fill" : "star")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(customer.isFavorite ? LopanColors.warning : LopanColors.textTertiary)
            }
            .buttonStyle(.borderless)
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
            .accessibilityLabel(customer.isFavorite ? "取消收藏" : "添加收藏")
        }
        .lopanPaddingVertical(LopanSpacing.md)
        .lopanPaddingHorizontal(LopanSpacing.md)
        .background(LopanColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: LopanColors.shadow.opacity(0.8), radius: 8, x: 0, y: 4)
        .contextMenu {
            contextMenuContent
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("客户 \(customer.name)")
        .accessibilityHint("点击查看详情，长按查看更多操作")
    }

    @ViewBuilder
    private var contextMenuContent: some View {
        // Call option
        if !customer.phone.isEmpty, let onCall = onCall {
            Button(action: onCall) {
                Label("拨打电话", systemImage: "phone")
            }
        }

        // Message option
        if !customer.phone.isEmpty, let onMessage = onMessage {
            Button(action: onMessage) {
                Label("发送短信", systemImage: "message")
            }
        }

        Divider()

        // Edit option
        if let onEdit = onEdit {
            Button(action: onEdit) {
                Label("编辑客户", systemImage: "pencil")
            }
        }

        Divider()

        // Delete option
        if let onDelete = onDelete {
            Button(role: .destructive, action: onDelete) {
                Label("删除客户", systemImage: "trash")
            }
        }
    }
}

// MARK: - Previews

#Preview("Standard Customer Card") {
    CustomerCardView(
        customer: Customer(name: "张三", address: "北京市朝阳区望京街道", phone: "13800138000"),
        onCall: {},
        onMessage: {},
        onEdit: {},
        onToggleFavorite: {},
        onDelete: {}
    )
    .padding()
    .background(LopanColors.backgroundPrimary)
}

#Preview("Favorite Customer Card") {
    CustomerCardView(
        customer: {
            let customer = Customer(name: "李四", address: "上海市浦东新区陆家嘴", phone: "13900139000")
            customer.isFavorite = true
            return customer
        }(),
        onCall: {},
        onMessage: {},
        onEdit: {},
        onToggleFavorite: {},
        onDelete: {}
    )
    .padding()
    .background(LopanColors.backgroundPrimary)
}

#Preview("Customer Card List") {
    ScrollView {
        VStack(spacing: LopanSpacing.sm) {
            ForEach(0..<5) { index in
                CustomerCardView(
                    customer: Customer(
                        name: "客户 \(index + 1)",
                        address: "地址信息 \(index + 1)",
                        phone: "1380013800\(index)"
                    ),
                    onCall: {},
                    onMessage: {},
                    onEdit: {},
                    onToggleFavorite: {},
                    onDelete: {}
                )
            }
        }
        .lopanPaddingHorizontal()
    }
    .background(LopanColors.backgroundPrimary)
}
