//
//  StandardSheet.swift
//  Lopan
//
//  iOS 26 UI/UX compliant sheet wrapper component
//  Ensures consistent sheet presentation across the app
//

import SwiftUI

/// Standard sheet presentation configuration for iOS 26 compliance
public struct SheetConfiguration {
    public var showDragIndicator: Bool = true
    public var detents: Set<PresentationDetent> = [.large]
    public var backgroundMaterial: Material? = nil
    public var interactiveDismissDisabled: Bool = false
    public var cornerRadius: CGFloat = 20
    public var showNavigationBar: Bool = true
    public var title: String = ""
    public var dismissButtonText: String = "完成"
    public var leadingButton: SheetButton? = nil
    public var trailingButton: SheetButton? = nil

    public init(
        showDragIndicator: Bool = true,
        detents: Set<PresentationDetent> = [.large],
        backgroundMaterial: Material? = nil,
        interactiveDismissDisabled: Bool = false,
        cornerRadius: CGFloat = 20,
        showNavigationBar: Bool = true,
        title: String = "",
        dismissButtonText: String = "完成",
        leadingButton: SheetButton? = nil,
        trailingButton: SheetButton? = nil
    ) {
        self.showDragIndicator = showDragIndicator
        self.detents = detents
        self.backgroundMaterial = backgroundMaterial
        self.interactiveDismissDisabled = interactiveDismissDisabled
        self.cornerRadius = cornerRadius
        self.showNavigationBar = showNavigationBar
        self.title = title
        self.dismissButtonText = dismissButtonText
        self.leadingButton = leadingButton
        self.trailingButton = trailingButton
    }

    /// Default configuration for standard sheets
    public static let standard = SheetConfiguration()

    /// Configuration for form sheets
    public static let form = SheetConfiguration(
        detents: [.medium, .large],
        interactiveDismissDisabled: true,
        title: "表单",
        leadingButton: SheetButton(text: "取消", style: .cancel),
        trailingButton: SheetButton(text: "保存", style: .primary)
    )

    /// Configuration for filter panels
    public static let filter = SheetConfiguration(
        detents: [.medium, .large],
        title: "筛选",
        leadingButton: SheetButton(text: "重置", style: .destructive),
        trailingButton: SheetButton(text: "应用", style: .primary)
    )

    /// Configuration for detail view sheets
    public static let detail = SheetConfiguration(
        showDragIndicator: false,
        detents: [.large],
        title: "详情"
    )

    /// Configuration for confirmation dialogs
    public static let confirmation = SheetConfiguration(
        detents: [.height(280)],
        interactiveDismissDisabled: true,
        showNavigationBar: false
    )
}

/// Button configuration for sheets
public struct SheetButton {
    public let text: String
    public let style: ButtonStyle
    public let action: () -> Void

    public enum ButtonStyle {
        case primary
        case secondary
        case destructive
        case cancel

        var foregroundColor: Color {
            switch self {
            case .primary: return LopanColors.primary
            case .secondary: return LopanColors.textSecondary
            case .destructive: return LopanColors.error
            case .cancel: return LopanColors.textSecondary
            }
        }

        var fontWeight: Font.Weight {
            switch self {
            case .primary: return .semibold
            case .secondary, .cancel: return .regular
            case .destructive: return .medium
            }
        }
    }

    public init(text: String, style: ButtonStyle = .secondary, action: @escaping () -> Void = {}) {
        self.text = text
        self.style = style
        self.action = action
    }
}

/// Standard sheet wrapper view for consistent presentation
public struct StandardSheet<Content: View>: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorScheme) private var colorScheme

    private let configuration: SheetConfiguration
    private let content: Content

    public init(
        configuration: SheetConfiguration = .standard,
        @ViewBuilder content: () -> Content
    ) {
        self.configuration = configuration
        self.content = content()
    }

    public var body: some View {
        mainContent
            .presentationDetents(configuration.detents)
            .presentationDragIndicator(configuration.showDragIndicator ? .visible : .hidden)
            .interactiveDismissDisabled(configuration.interactiveDismissDisabled)
            .presentationCornerRadius(configuration.cornerRadius)
            .presentationBackground(Material.regular)
            .accessibilityAddTraits(.isModal)
            .environment(\.colorScheme, colorScheme)
    }

    @ViewBuilder
    private var mainContent: some View {
        if configuration.showNavigationBar {
            navigationContent
        } else {
            sheetContent
        }
    }

    private var navigationContent: some View {
        NavigationStack {
            sheetContent
                .navigationTitle(configuration.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    leadingToolbarItem
                    trailingToolbarItem
                }
        }
    }

    @ToolbarContentBuilder
    private var leadingToolbarItem: some ToolbarContent {
        if let leadingButton = configuration.leadingButton {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    leadingButton.action()
                    if leadingButton.style == .cancel {
                        dismiss()
                    }
                }) {
                    Text(leadingButton.text)
                        .foregroundColor(leadingButton.style.foregroundColor)
                        .fontWeight(leadingButton.style.fontWeight)
                }
            }
        }
    }

    @ToolbarContentBuilder
    private var trailingToolbarItem: some ToolbarContent {
        if let trailingButton = configuration.trailingButton {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    trailingButton.action()
                    if trailingButton.style == .primary {
                        dismiss()
                    }
                }) {
                    Text(trailingButton.text)
                        .foregroundColor(trailingButton.style.foregroundColor)
                        .fontWeight(trailingButton.style.fontWeight)
                }
            }
        } else if configuration.leadingButton == nil {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(configuration.dismissButtonText) {
                    dismiss()
                }
                .fontWeight(.semibold)
                .foregroundColor(LopanColors.primary)
            }
        }
    }

    private var sheetContent: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(backgroundColor)
    }

    private var backgroundColor: Color {
        if #available(iOS 17.0, *) {
            return Color(.systemBackground)
        } else {
            return colorScheme == .dark ? Color(.systemGray6) : .white
        }
    }

    @ViewBuilder
    private var backgroundMaterial: some View {
        if let material = configuration.backgroundMaterial {
            Rectangle().fill(material)
        } else {
            if #available(iOS 17.0, *) {
                Rectangle().fill(Material.regular)
            } else {
                Color(.systemBackground)
            }
        }
    }
}

/// View modifier for applying standard sheet configuration
public struct StandardSheetModifier<SheetContent: View>: ViewModifier {
    @Binding var isPresented: Bool
    let configuration: SheetConfiguration
    let sheetContent: () -> SheetContent

    public func body(content: Content) -> some View {
        content
            .sheet(isPresented: $isPresented) {
                StandardSheet(configuration: configuration) {
                    sheetContent()
                }
            }
    }
}

public extension View {
    /// Presents a standardized sheet with iOS 26 compliance
    func standardSheet<Content: View>(
        isPresented: Binding<Bool>,
        configuration: SheetConfiguration = .standard,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        modifier(StandardSheetModifier(
            isPresented: isPresented,
            configuration: configuration,
            sheetContent: content
        ))
    }
}

// MARK: - Previews

#Preview("Standard Sheet") {
    Button("Show Standard Sheet") {}
        .standardSheet(isPresented: .constant(true)) {
            VStack(spacing: 20) {
                Image(systemName: "doc.fill")
                    .font(.largeTitle)
                    .foregroundColor(LopanColors.primary)

                Text("Standard Sheet Content")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("This is a standardized sheet presentation following iOS 26 guidelines.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
            }
            .padding()
        }
}

#Preview("Form Sheet") {
    Button("Show Form Sheet") {}
        .standardSheet(
            isPresented: .constant(true),
            configuration: .form
        ) {
            Form {
                Section("基本信息") {
                    TextField("名称", text: .constant(""))
                    TextField("描述", text: .constant(""))
                }

                Section("设置") {
                    Toggle("启用通知", isOn: .constant(true))
                    Toggle("自动保存", isOn: .constant(false))
                }
            }
        }
}

#Preview("Filter Sheet") {
    Button("Show Filter Sheet") {}
        .standardSheet(
            isPresented: .constant(true),
            configuration: .filter
        ) {
            VStack(alignment: .leading, spacing: 20) {
                Text("筛选条件")
                    .font(.headline)
                    .padding(.horizontal)

                VStack(spacing: 12) {
                    FilterRow(title: "状态", value: "全部")
                    FilterRow(title: "日期", value: "本周")
                    FilterRow(title: "客户", value: "未选择")
                    FilterRow(title: "产品", value: "未选择")
                }
                .padding(.horizontal)

                Spacer()
            }
            .padding(.top)
        }
}

// Helper view for filter preview
private struct FilterRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .foregroundColor(.primary)
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

#Preview("Confirmation Sheet") {
    Button("Show Confirmation") {}
        .standardSheet(
            isPresented: .constant(true),
            configuration: .confirmation
        ) {
            VStack(spacing: 20) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.largeTitle)
                    .foregroundColor(LopanColors.warning)

                Text("确认删除")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("此操作不可撤销，是否继续？")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)

                HStack(spacing: 16) {
                    Button("取消") {}
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 30)
                        .padding(.vertical, 12)
                        .background(Color(.systemGray5))
                        .cornerRadius(10)

                    Button("删除") {}
                        .foregroundColor(.white)
                        .padding(.horizontal, 30)
                        .padding(.vertical, 12)
                        .background(LopanColors.error)
                        .cornerRadius(10)
                }
            }
            .padding()
        }
}