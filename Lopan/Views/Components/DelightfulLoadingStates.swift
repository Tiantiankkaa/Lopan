//
//  DelightfulLoadingStates.swift
//  Lopan
//
//  Created by Claude Code - Perfectionist UI/UX Design
//  令人愉悦的加载状态组件 - 每个像素都经过精心设计
//

import SwiftUI

// MARK: - 骨架加载系统
/// 智能骨架加载组件，完美匹配内容结构
struct SkeletonLoadingView: View {
    let loadingType: LoadingType
    let animationStyle: AnimationStyle
    let itemCount: Int
    
    @State private var animationPhase: CGFloat = 0
    
    enum LoadingType: Equatable {
        case customerCard
        case customerList
        case customerDetail
        case searchResults
        case statistics
        
        var itemHeight: CGFloat {
            switch self {
            case .customerCard: return 120
            case .customerList: return 80
            case .customerDetail: return 200
            case .searchResults: return 60
            case .statistics: return 100
            }
        }
    }
    
    enum AnimationStyle {
        case shimmer      // 闪烁效果
        case pulse        // 脉冲效果
        case wave         // 波浪效果
        case breathe      // 呼吸效果
        
        var animation: Animation {
            switch self {
            case .shimmer:
                return .linear(duration: 1.5).repeatForever(autoreverses: false)
            case .pulse:
                return .easeInOut(duration: 1.2).repeatForever(autoreverses: true)
            case .wave:
                return .easeInOut(duration: 2.0).repeatForever(autoreverses: true)
            case .breathe:
                return .easeInOut(duration: 1.8).repeatForever(autoreverses: true)
            }
        }
    }
    
    init(
        type: LoadingType,
        style: AnimationStyle = .shimmer,
        itemCount: Int = 5
    ) {
        self.loadingType = type
        self.animationStyle = style
        self.itemCount = itemCount
    }
    
    var body: some View {
        VStack(spacing: 16) {
            ForEach(0..<itemCount, id: \.self) { index in
                skeletonItem(for: loadingType, index: index)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.8)),
                        removal: .opacity
                    ))
            }
        }
        .onAppear {
            withAnimation(animationStyle.animation) {
                animationPhase = 1
            }
        }
    }
    
    @ViewBuilder
    private func skeletonItem(for type: LoadingType, index: Int) -> some View {
        switch type {
        case .customerCard:
            customerCardSkeleton(index: index)
        case .customerList:
            customerListSkeleton(index: index)
        case .customerDetail:
            customerDetailSkeleton()
        case .searchResults:
            searchResultSkeleton(index: index)
        case .statistics:
            statisticsSkeleton(index: index)
        }
    }
    
    // MARK: - 客户卡片骨架
    private func customerCardSkeleton(index: Int) -> some View {
        HStack(spacing: 16) {
            // 头像骨架
            SkeletonShape.circle(size: 60)
                .skeleton(
                    with: animationStyle == .shimmer,
                    animationPhase: animationPhase,
                    delay: Double(index) * 0.1
                )
            
            VStack(alignment: .leading, spacing: 8) {
                // 姓名骨架
                SkeletonShape.capsule(width: 120, height: 20)
                    .skeleton(
                        with: animationStyle == .shimmer,
                        animationPhase: animationPhase,
                        delay: Double(index) * 0.1 + 0.05
                    )
                
                // 地址骨架
                SkeletonShape.capsule(width: 200, height: 16)
                    .skeleton(
                        with: animationStyle == .shimmer,
                        animationPhase: animationPhase,
                        delay: Double(index) * 0.1 + 0.1
                    )
                
                // 电话骨架
                SkeletonShape.capsule(width: 150, height: 16)
                    .skeleton(
                        with: animationStyle == .shimmer,
                        animationPhase: animationPhase,
                        delay: Double(index) * 0.1 + 0.15
                    )
            }
            
            Spacer()
            
            // 操作按钮骨架
            SkeletonShape.capsule(width: 24, height: 24)
                .skeleton(
                    with: animationStyle == .shimmer,
                    animationPhase: animationPhase,
                    delay: Double(index) * 0.1 + 0.2
                )
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        )
    }
    
    // MARK: - 客户列表骨架
    private func customerListSkeleton(index: Int) -> some View {
        HStack(spacing: 12) {
            // 小头像骨架
            SkeletonShape.circle(size: 44)
                .skeleton(
                    with: animationStyle == .shimmer,
                    animationPhase: animationPhase,
                    delay: Double(index) * 0.08
                )
            
            VStack(alignment: .leading, spacing: 6) {
                // 姓名骨架
                SkeletonShape.capsule(width: 100, height: 18)
                    .skeleton(
                        with: animationStyle == .shimmer,
                        animationPhase: animationPhase,
                        delay: Double(index) * 0.08 + 0.04
                    )
                
                // 信息骨架
                SkeletonShape.capsule(width: 160, height: 14)
                    .skeleton(
                        with: animationStyle == .shimmer,
                        animationPhase: animationPhase,
                        delay: Double(index) * 0.08 + 0.08
                    )
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
    }
    
    // MARK: - 客户详情骨架
    private func customerDetailSkeleton() -> some View {
        VStack(spacing: 20) {
            // 头部区域
            HStack(spacing: 16) {
                SkeletonShape.circle(size: 80)
                    .skeleton(with: animationStyle == .shimmer, animationPhase: animationPhase)
                
                VStack(alignment: .leading, spacing: 8) {
                    SkeletonShape.capsule(width: 140, height: 24)
                        .skeleton(with: animationStyle == .shimmer, animationPhase: animationPhase, delay: 0.1)
                    
                    SkeletonShape.capsule(width: 100, height: 16)
                        .skeleton(with: animationStyle == .shimmer, animationPhase: animationPhase, delay: 0.15)
                }
                
                Spacer()
            }
            
            // 操作按钮区域
            HStack(spacing: 12) {
                ForEach(0..<4, id: \.self) { index in
                    SkeletonShape.capsule(width: 60, height: 40)
                        .skeleton(
                            with: animationStyle == .shimmer,
                            animationPhase: animationPhase,
                            delay: 0.2 + Double(index) * 0.05
                        )
                }
            }
            
            // 信息卡片区域
            VStack(spacing: 12) {
                ForEach(0..<3, id: \.self) { index in
                    HStack {
                        SkeletonShape.capsule(width: 80, height: 16)
                            .skeleton(
                                with: animationStyle == .shimmer,
                                animationPhase: animationPhase,
                                delay: 0.4 + Double(index) * 0.08
                            )
                        
                        Spacer()
                        
                        SkeletonShape.capsule(width: 120, height: 16)
                            .skeleton(
                                with: animationStyle == .shimmer,
                                animationPhase: animationPhase,
                                delay: 0.45 + Double(index) * 0.08
                            )
                    }
                }
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 3)
        )
    }
    
    // MARK: - 搜索结果骨架
    private func searchResultSkeleton(index: Int) -> some View {
        HStack(spacing: 10) {
            SkeletonShape.circle(size: 36)
                .skeleton(
                    with: animationStyle == .shimmer,
                    animationPhase: animationPhase,
                    delay: Double(index) * 0.06
                )
            
            VStack(alignment: .leading, spacing: 4) {
                SkeletonShape.capsule(width: 80, height: 14)
                    .skeleton(
                        with: animationStyle == .shimmer,
                        animationPhase: animationPhase,
                        delay: Double(index) * 0.06 + 0.03
                    )
                
                SkeletonShape.capsule(width: 120, height: 12)
                    .skeleton(
                        with: animationStyle == .shimmer,
                        animationPhase: animationPhase,
                        delay: Double(index) * 0.06 + 0.06
                    )
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
    
    // MARK: - 统计数据骨架
    private func statisticsSkeleton(index: Int) -> some View {
        VStack(spacing: 12) {
            SkeletonShape.capsule(width: 40, height: 32)
                .skeleton(
                    with: animationStyle == .shimmer,
                    animationPhase: animationPhase,
                    delay: Double(index) * 0.1
                )
            
            SkeletonShape.capsule(width: 60, height: 14)
                .skeleton(
                    with: animationStyle == .shimmer,
                    animationPhase: animationPhase,
                    delay: Double(index) * 0.1 + 0.05
                )
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.03), radius: 2, x: 0, y: 1)
        )
    }
}

// MARK: - 骨架形状组件
enum SkeletonShape {
    static func capsule(width: CGFloat, height: CGFloat) -> some View {
        Capsule()
            .fill(Color(.systemGray5))
            .frame(width: width, height: height)
    }
    
    static func rectangle(width: CGFloat, height: CGFloat, cornerRadius: CGFloat = 8) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Color(.systemGray5))
            .frame(width: width, height: height)
    }
    
    static func circle(size: CGFloat) -> some View {
        Circle()
            .fill(Color(.systemGray5))
            .frame(width: size, height: size)
    }
}

// MARK: - 骨架修饰器
struct SkeletonModifier: ViewModifier {
    let isShimmering: Bool
    let animationPhase: CGFloat
    let delay: Double
    
    func body(content: Content) -> some View {
        content
            .opacity(isShimmering ? 0.6 + 0.4 * sin(animationPhase * Double.pi * 2) : 1.0)
            .overlay(
                isShimmering ? 
                LinearGradient(
                    colors: [
                        Color.white.opacity(0),
                        Color.white.opacity(0.6),
                        Color.white.opacity(0)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .scaleEffect(x: 3, y: 1)
                .offset(x: (animationPhase - 0.5) * 600)
                .mask(content)
                : nil
            )
            .animation(.linear(duration: 1.5).delay(delay).repeatForever(autoreverses: false), value: animationPhase)
    }
}

extension View {
    func skeleton(
        with isShimmering: Bool,
        animationPhase: CGFloat = 0,
        delay: Double = 0
    ) -> some View {
        self.modifier(SkeletonModifier(
            isShimmering: isShimmering,
            animationPhase: animationPhase,
            delay: delay
        ))
    }
}

// MARK: - 智能加载状态管理器
/// 根据内容类型和加载时间智能选择最佳加载体验
class LoadingStateManager: ObservableObject {
    @Published var currentState: LoadingState = .idle
    @Published var loadingProgress: Double = 0
    @Published var estimatedTimeRemaining: TimeInterval = 0
    
    private var loadingStartTime: Date?
    private var progressTimer: Timer?
    
    enum LoadingState: Equatable {
        case idle
        case loading(LoadingContext)
        case success
        case error(String)
        
        var isLoading: Bool {
            if case .loading = self { return true }
            return false
        }
    }
    
    struct LoadingContext: Equatable {
        let type: SkeletonLoadingView.LoadingType
        let estimatedDuration: TimeInterval
        let showProgress: Bool
        let message: String?
    }
    
    func startLoading(context: LoadingContext) {
        loadingStartTime = Date()
        currentState = .loading(context)
        loadingProgress = 0
        
        if context.showProgress {
            startProgressSimulation(duration: context.estimatedDuration)
        }
    }
    
    func completeLoading() {
        currentState = .success
        progressTimer?.invalidate()
        
        // 短暂延迟以显示成功状态
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.currentState = .idle
        }
    }
    
    func failLoading(error: String) {
        currentState = .error(error)
        progressTimer?.invalidate()
    }
    
    private func startProgressSimulation(duration: TimeInterval) {
        let interval = duration / 100 // 100步完成
        
        progressTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            if self.loadingProgress < 0.95 { // 不要达到100%，让实际完成来触发
                self.loadingProgress += 0.01
                
                if let startTime = self.loadingStartTime {
                    let elapsed = Date().timeIntervalSince(startTime)
                    let estimated = duration - elapsed
                    self.estimatedTimeRemaining = max(0, estimated)
                }
            }
        }
    }
}

// MARK: - 智能加载视图
struct SmartLoadingView: View {
    @StateObject private var loadingManager = LoadingStateManager()
    let context: LoadingStateManager.LoadingContext
    
    var body: some View {
        Group {
            switch loadingManager.currentState {
            case .idle:
                EmptyView()
                
            case .loading(let context):
                loadingContent(for: context)
                
            case .success:
                successContent
                
            case .error(let message):
                errorContent(message: message)
            }
        }
        .onAppear {
            loadingManager.startLoading(context: context)
        }
    }
    
    @ViewBuilder
    private func loadingContent(for context: LoadingStateManager.LoadingContext) -> some View {
        VStack(spacing: 20) {
            SkeletonLoadingView(
                type: context.type,
                style: .shimmer,
                itemCount: skeletonItemCount(for: context.type)
            )
            
            if context.showProgress {
                progressView(context: context)
            }
            
            if let message = context.message {
                loadingMessage(message)
            }
        }
    }
    
    private func progressView(context: LoadingStateManager.LoadingContext) -> some View {
        VStack(spacing: 8) {
            ProgressView(value: loadingManager.loadingProgress)
                .progressViewStyle(CustomProgressViewStyle())
            
            if loadingManager.estimatedTimeRemaining > 0 {
                Text("预计剩余时间: \(Int(loadingManager.estimatedTimeRemaining))秒")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 20)
    }
    
    private func loadingMessage(_ message: String) -> some View {
        Text(message)
            .font(.subheadline)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 20)
    }
    
    private var successContent: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.title)
                .foregroundColor(.green)
                .scaleEffect(1.2)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: loadingManager.currentState)
            
            Text("加载完成")
                .font(.subheadline)
                .foregroundColor(.primary)
        }
        .transition(.scale.combined(with: .opacity))
    }
    
    private func errorContent(message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.title)
                .foregroundColor(.red)
            
            Text("加载失败")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 4)
        )
    }
    
    private func skeletonItemCount(for type: SkeletonLoadingView.LoadingType) -> Int {
        switch type {
        case .customerCard: return 3
        case .customerList: return 8
        case .customerDetail: return 1
        case .searchResults: return 5
        case .statistics: return 4
        }
    }
}

// MARK: - 自定义进度条样式
struct CustomProgressViewStyle: ProgressViewStyle {
    func makeBody(configuration: Configuration) -> some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.systemGray5))
                    .frame(height: 8)
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(
                        LinearGradient(
                            colors: [LopanColors.primary, LopanColors.primary.opacity(0.7)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(
                        width: geometry.size.width * CGFloat(configuration.fractionCompleted ?? 0),
                        height: 8
                    )
                    .animation(.easeInOut(duration: 0.3), value: configuration.fractionCompleted)
            }
        }
        .frame(height: 8)
    }
}

// MARK: - 使用示例视图
struct LoadingStatesShowcase: View {
    @State private var showingCustomerCards = false
    @State private var showingCustomerDetail = false
    @State private var showingSearchResults = false
    
    var body: some View {
        NavigationView {
            List {
                Section("骨架加载示例") {
                    Button("客户卡片加载") {
                        showingCustomerCards.toggle()
                    }
                    
                    Button("客户详情加载") {
                        showingCustomerDetail.toggle()
                    }
                    
                    Button("搜索结果加载") {
                        showingSearchResults.toggle()
                    }
                }
            }
            .navigationTitle("加载状态展示")
            .sheet(isPresented: $showingCustomerCards) {
                SkeletonLoadingView(type: .customerCard, style: .shimmer, itemCount: 4)
                    .padding()
            }
            .sheet(isPresented: $showingCustomerDetail) {
                SkeletonLoadingView(type: .customerDetail, style: .pulse, itemCount: 1)
                    .padding()
            }
            .sheet(isPresented: $showingSearchResults) {
                SkeletonLoadingView(type: .searchResults, style: .wave, itemCount: 6)
                    .padding()
            }
        }
    }
}

#Preview {
    LoadingStatesShowcase()
}