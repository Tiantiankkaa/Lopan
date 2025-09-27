//
//  EnhancedHapticEngine.swift
//  Lopan
//
//  Created by Claude Code - Perfectionist UI/UX Design
//  增强触觉反馈引擎 - 为每个交互精心设计的触觉体验
//

import SwiftUI
import UIKit

/// 增强触觉反馈引擎 - 提供情境化的触觉反馈
/// 每种操作类型都有独特的触觉特征，创造直观的用户体验
class EnhancedHapticEngine: ObservableObject {
    
    // MARK: - Singleton Instance
    static let shared = EnhancedHapticEngine()
    
    // MARK: - Private Properties
    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
    private let notification = UINotificationFeedbackGenerator()
    private let selectionGenerator = UISelectionFeedbackGenerator()
    
    // 触觉反馈启用状态
    private var isHapticsEnabled: Bool {
        return UIAccessibility.isReduceMotionEnabled == false
    }
    
    private init() {
        prepareHapticGenerators()
    }
    
    // MARK: - Generator Preparation
    /// 预准备触觉反馈生成器以减少延迟
    private func prepareHapticGenerators() {
        impactLight.prepare()
        impactMedium.prepare()
        impactHeavy.prepare()
        notification.prepare()
        selectionGenerator.prepare()
    }
    
    // MARK: - Core Haptic Methods
    
    /// 轻微触觉反馈 - 用于轻触、悬停等
    func light() {
        guard isHapticsEnabled else { return }
        impactLight.impactOccurred()
    }
    
    /// 中等触觉反馈 - 用于按钮点击、选择等
    func medium() {
        guard isHapticsEnabled else { return }
        impactMedium.impactOccurred()
    }
    
    /// 强烈触觉反馈 - 用于重要操作、警告等
    func heavy() {
        guard isHapticsEnabled else { return }
        impactHeavy.impactOccurred()
    }
    
    /// 成功反馈 - 用于操作成功完成
    func success() {
        guard isHapticsEnabled else { return }
        notification.notificationOccurred(.success)
    }
    
    /// 警告反馈 - 用于需要注意的操作
    func warning() {
        guard isHapticsEnabled else { return }
        notification.notificationOccurred(.warning)
    }
    
    /// 错误反馈 - 用于操作失败
    func error() {
        guard isHapticsEnabled else { return }
        notification.notificationOccurred(.error)
    }
    
    /// 选择反馈 - 用于列表选择、滑动选择等
    func selection() {
        guard isHapticsEnabled else { return }
        self.selectionGenerator.selectionChanged()
    }
    
    // MARK: - Contextual Haptic Feedback
    
    /// 客户管理特定的触觉反馈
    enum CustomerAction {
        case cardTap                // 卡片点击
        case cardLongPress         // 卡片长按
        case selectionToggle       // 选择切换
        case batchModeEnter        // 进入批量模式
        case batchModeExit         // 退出批量模式
        case selectionChain        // 连续选择
        case bulkActionExecute     // 批量操作执行
        case searchResultFound     // 搜索结果找到
        case searchNoResults       // 搜索无结果
        case customerAdded         // 客户添加成功
        case customerUpdated       // 客户更新成功
        case customerDeleted       // 客户删除成功
        case customerDeleteFailed  // 客户删除失败
        case phoneCall             // 拨打电话
        case formValidationError   // 表单验证错误
        case formSaveSuccess       // 表单保存成功
        case refreshPullStart      // 下拉刷新开始
        case refreshPullComplete   // 下拉刷新完成
        case swipeActionReveal     // 滑动操作显示
        case filterApply           // 筛选器应用
        case filterClear           // 筛选器清除
        
        var hapticPattern: HapticPattern {
            switch self {
            case .cardTap:
                return .single(.light, delay: 0)
            case .cardLongPress:
                return .single(.medium, delay: 0.1)
            case .selectionToggle:
                return .single(.selection, delay: 0)
            case .batchModeEnter:
                return .sequence([
                    (.medium, 0),
                    (.light, 0.1)
                ])
            case .batchModeExit:
                return .sequence([
                    (.light, 0),
                    (.light, 0.05)
                ])
            case .selectionChain:
                return .single(.selection, delay: 0)
            case .bulkActionExecute:
                return .sequence([
                    (.heavy, 0),
                    (.success, 0.2)
                ])
            case .searchResultFound:
                return .single(.light, delay: 0)
            case .searchNoResults:
                return .single(.warning, delay: 0)
            case .customerAdded:
                return .celebration
            case .customerUpdated:
                return .single(.success, delay: 0)
            case .customerDeleted:
                return .sequence([
                    (.warning, 0),
                    (.heavy, 0.1)
                ])
            case .customerDeleteFailed:
                return .sequence([
                    (.error, 0),
                    (.heavy, 0.1),
                    (.heavy, 0.2)
                ])
            case .phoneCall:
                return .sequence([
                    (.medium, 0),
                    (.light, 0.1),
                    (.light, 0.2)
                ])
            case .formValidationError:
                return .shake
            case .formSaveSuccess:
                return .single(.success, delay: 0)
            case .refreshPullStart:
                return .single(.light, delay: 0)
            case .refreshPullComplete:
                return .sequence([
                    (.medium, 0),
                    (.success, 0.15)
                ])
            case .swipeActionReveal:
                return .single(.selection, delay: 0)
            case .filterApply:
                return .single(.medium, delay: 0)
            case .filterClear:
                return .single(.light, delay: 0)
            }
        }
    }
    
    /// 执行客户管理相关的触觉反馈
    func perform(_ action: CustomerAction) {
        executeHapticPattern(action.hapticPattern)
    }
    
    // MARK: - Haptic Patterns
    
    enum HapticType {
        case light, medium, heavy, success, warning, error, selection
    }
    
    enum HapticPattern {
        case single(HapticType, delay: TimeInterval)
        case sequence([(HapticType, TimeInterval)])
        case celebration
        case shake
        case pulse(intensity: HapticType, count: Int, interval: TimeInterval)
        
        static let celebrationPattern: HapticPattern = .sequence([
            (.success, 0),
            (.light, 0.1),
            (.light, 0.15),
            (.medium, 0.25)
        ])
        
        static let shakePattern: HapticPattern = .sequence([
            (.error, 0),
            (.medium, 0.1),
            (.medium, 0.2)
        ])
    }
    
    /// 执行触觉模式
    private func executeHapticPattern(_ pattern: HapticPattern) {
        switch pattern {
        case .single(let type, let delay):
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                self.executeHapticType(type)
            }
            
        case .sequence(let sequence):
            for (type, delay) in sequence {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    self.executeHapticType(type)
                }
            }
            
        case .celebration:
            executeHapticPattern(.sequence([
                (.success, 0),
                (.light, 0.1),
                (.light, 0.15),
                (.medium, 0.25)
            ]))
            
        case .shake:
            executeHapticPattern(.sequence([
                (.error, 0),
                (.medium, 0.1),
                (.medium, 0.2)
            ]))
            
        case .pulse(let intensity, let count, let interval):
            for i in 0..<count {
                DispatchQueue.main.asyncAfter(deadline: .now() + TimeInterval(i) * interval) {
                    self.executeHapticType(intensity)
                }
            }
        }
    }
    
    /// 执行特定类型的触觉反馈
    private func executeHapticType(_ type: HapticType) {
        switch type {
        case .light: light()
        case .medium: medium()
        case .heavy: heavy()
        case .success: success()
        case .warning: warning()
        case .error: error()
        case .selection: selection()
        }
    }
    
    // MARK: - Adaptive Haptics
    
    /// 根据用户偏好和系统设置调整触觉反馈
    class HapticSettings: ObservableObject {
        @Published var intensity: HapticIntensity = .normal
        @Published var isEnabled: Bool = true
        @Published var respectsSystemSettings: Bool = true
        
        enum HapticIntensity: String, CaseIterable {
            case light = "轻微"
            case normal = "正常"
            case strong = "强烈"
            
            var multiplier: Double {
                switch self {
                case .light: return 0.7
                case .normal: return 1.0
                case .strong: return 1.3
                }
            }
        }
    }
    
    @Published var settings = HapticSettings()
    
    /// 自适应触觉反馈执行
    func adaptivePerform(_ action: CustomerAction) {
        guard settings.isEnabled else { return }
        guard !settings.respectsSystemSettings || isHapticsEnabled else { return }
        
        // 根据设置调整触觉强度
        var adjustedPattern = action.hapticPattern
        
        if settings.intensity != .normal {
            adjustedPattern = adjustPatternIntensity(adjustedPattern, multiplier: settings.intensity.multiplier)
        }
        
        executeHapticPattern(adjustedPattern)
    }
    
    /// 调整触觉模式强度
    private func adjustPatternIntensity(_ pattern: HapticPattern, multiplier: Double) -> HapticPattern {
        switch pattern {
        case .single(let type, let delay):
            return .single(adjustHapticType(type, multiplier: multiplier), delay: delay)
            
        case .sequence(let sequence):
            let adjustedSequence = sequence.map { (type, delay) in
                (adjustHapticType(type, multiplier: multiplier), delay)
            }
            return .sequence(adjustedSequence)
            
        case .pulse(let intensity, let count, let interval):
            return .pulse(
                intensity: adjustHapticType(intensity, multiplier: multiplier),
                count: count,
                interval: interval
            )
            
        default:
            return pattern // celebration 和 shake 保持原样
        }
    }
    
    /// 调整触觉类型强度
    private func adjustHapticType(_ type: HapticType, multiplier: Double) -> HapticType {
        switch (type, multiplier) {
        case (.light, let m) where m > 1.2:
            return .medium
        case (.medium, let m) where m > 1.2:
            return .heavy
        case (.medium, let m) where m < 0.8:
            return .light
        case (.heavy, let m) where m < 0.8:
            return .medium
        default:
            return type
        }
    }
    
    // MARK: - Complex Interaction Patterns
    
    /// 处理复杂的交互序列
    class InteractionSequence {
        private var actions: [(CustomerAction, TimeInterval)] = []
        private let engine: EnhancedHapticEngine
        
        init(engine: EnhancedHapticEngine = .shared) {
            self.engine = engine
        }
        
        func add(_ action: CustomerAction, delay: TimeInterval = 0) -> InteractionSequence {
            actions.append((action, delay))
            return self
        }
        
        func execute() {
            for (action, delay) in actions {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    self.engine.perform(action)
                }
            }
        }
    }
    
    /// 创建交互序列
    func sequence() -> InteractionSequence {
        return InteractionSequence(engine: self)
    }
    
    // MARK: - Smart Haptic Suggestions
    
    /// 基于上下文建议最佳的触觉反馈
    func suggestedHaptic(for context: HapticContext) -> CustomerAction {
        switch context {
        case .userSelection(let isMultiple, let selectionCount):
            if isMultiple && selectionCount > 0 {
                return .selectionChain
            } else {
                return .selectionToggle
            }
            
        case .userAction(let actionType, let isDestructive):
            if isDestructive {
                return actionType == "delete" ? .customerDeleted : .customerDeleteFailed
            } else {
                return actionType == "save" ? .customerUpdated : .cardTap
            }
            
        case .systemResponse(let isSuccess, let responseTime):
            if responseTime > 2.0 {
                return isSuccess ? .formSaveSuccess : .formValidationError
            } else {
                return isSuccess ? .cardTap : .formValidationError
            }
            
        case .userInterface(let elementType, let interactionType):
            switch (elementType, interactionType) {
            case ("button", "tap"): return .cardTap
            case ("button", "longPress"): return .cardLongPress
            case ("list", "swipe"): return .swipeActionReveal
            case ("search", "results"): return .searchResultFound
            default: return .cardTap
            }
        }
    }
    
    enum HapticContext {
        case userSelection(isMultiple: Bool, selectionCount: Int)
        case userAction(actionType: String, isDestructive: Bool)
        case systemResponse(isSuccess: Bool, responseTime: TimeInterval)
        case userInterface(elementType: String, interactionType: String)
    }
}

// MARK: - SwiftUI Integration

/// SwiftUI 视图修饰器，用于简化触觉反馈的使用
struct HapticFeedbackModifier: ViewModifier {
    let action: EnhancedHapticEngine.CustomerAction
    let trigger: Bool
    let engine: EnhancedHapticEngine
    
    func body(content: Content) -> some View {
        content
            .onChange(of: trigger) { _, newValue in
                if newValue {
                    engine.perform(action)
                }
            }
    }
}

extension View {
    /// 添加触觉反馈到视图
    func hapticFeedback(
        _ action: EnhancedHapticEngine.CustomerAction,
        trigger: Bool,
        engine: EnhancedHapticEngine = .shared
    ) -> some View {
        self.modifier(HapticFeedbackModifier(
            action: action,
            trigger: trigger,
            engine: engine
        ))
    }
    
    /// 为按钮添加触觉反馈
    func hapticTap(
        _ action: EnhancedHapticEngine.CustomerAction = .cardTap,
        engine: EnhancedHapticEngine = .shared
    ) -> some View {
        self.onTapGesture {
            engine.perform(action)
        }
    }
    
    /// 为长按添加触觉反馈
    func hapticLongPress(
        minimumDuration: Double = 0.5,
        action: EnhancedHapticEngine.CustomerAction = .cardLongPress,
        engine: EnhancedHapticEngine = .shared,
        perform: @escaping () -> Void = {}
    ) -> some View {
        self.onLongPressGesture(minimumDuration: minimumDuration) {
            engine.perform(action)
            perform()
        }
    }
}

// MARK: - Accessibility Support

extension EnhancedHapticEngine {
    /// 检查触觉反馈是否应该启用（考虑无障碍设置）
    var shouldProvideFeedback: Bool {
        return !UIAccessibility.isReduceMotionEnabled &&
               !UIAccessibility.isVoiceOverRunning &&
               isHapticsEnabled
    }
    
    /// 为VoiceOver用户提供替代反馈
    func accessibleFeedback(for action: CustomerAction, announcement: String) {
        if UIAccessibility.isVoiceOverRunning {
            UIAccessibility.post(notification: .announcement, argument: announcement)
        } else {
            perform(action)
        }
    }
}

// MARK: - Performance Monitoring

extension EnhancedHapticEngine {
    /// 监控触觉反馈性能
    private func monitorPerformance() {
        #if DEBUG
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // 执行触觉反馈后测量延迟
        DispatchQueue.main.async {
            let endTime = CFAbsoluteTimeGetCurrent()
            let latency = (endTime - startTime) * 1000 // 转换为毫秒
            
            if latency > 10 { // 如果延迟超过10ms
                print("⚠️ Haptic feedback latency: \(String(format: "%.2f", latency))ms")
            }
        }
        #endif
    }
}

// MARK: - Convenience Static Methods
extension EnhancedHapticEngine {
    /// 快速访问常用触觉反馈的静态方法
    static func cardTap() { shared.perform(.cardTap) }
    static func selectionChanged() { shared.perform(.selectionToggle) }
    static func successfulAction() { shared.perform(.customerUpdated) }
    static func errorOccurred() { shared.perform(.formValidationError) }
    static func warningAlert() { shared.perform(.formValidationError) }
}

// MARK: - Preview and Testing
#if DEBUG
struct HapticEngineTestView: View {
    @StateObject private var hapticEngine = EnhancedHapticEngine.shared
    
    var body: some View {
        NavigationStack {
            List {
                Section("基础触觉反馈") {
                    Button("轻触反馈") { hapticEngine.light() }
                    Button("中等反馈") { hapticEngine.medium() }
                    Button("强烈反馈") { hapticEngine.heavy() }
                    Button("成功反馈") { hapticEngine.success() }
                    Button("警告反馈") { hapticEngine.warning() }
                    Button("错误反馈") { hapticEngine.error() }
                    Button("选择反馈") { hapticEngine.selection() }
                }
                
                Section("客户管理操作") {
                    Button("卡片点击") { hapticEngine.perform(.cardTap) }
                    Button("进入批量模式") { hapticEngine.perform(.batchModeEnter) }
                    Button("选择切换") { hapticEngine.perform(.selectionToggle) }
                    Button("添加客户") { hapticEngine.perform(.customerAdded) }
                    Button("拨打电话") { hapticEngine.perform(.phoneCall) }
                }
                
                Section("复杂序列") {
                    Button("庆祝序列") {
                        hapticEngine.sequence()
                            .add(.customerAdded, delay: 0)
                            .add(.cardTap, delay: 0.2)
                            .add(.cardTap, delay: 0.3)
                            .execute()
                    }
                    
                    Button("错误序列") {
                        hapticEngine.perform(.customerDeleteFailed)
                    }
                }
            }
            .navigationTitle("触觉反馈测试")
        }
    }
}

#Preview {
    HapticEngineTestView()
}
#endif