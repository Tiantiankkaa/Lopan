//
//  OutOfStockDataVisualization.swift
//  Lopan
//
//  Created by Claude Code on 2025/8/22.
//  Advanced data visualization and animation components
//

import SwiftUI

// MARK: - Liquid Glass Card with Data Flow Animation

struct LiquidDataCard<Content: View>: View {
    let content: Content
    let priority: DataPriority
    let flowDirection: FlowDirection
    
    @State private var animationOffset: CGFloat = 0
    @State private var glowIntensity: Double = 0.3
    @State private var flowParticles: [FlowParticle] = []
    
    enum DataPriority {
        case low, normal, high, critical
        
        var gradientColors: [Color] {
            switch self {
            case .low: return [LopanColors.primary.opacity(0.1), LopanColors.primary.opacity(0.05)]
            case .normal: return [LopanColors.success.opacity(0.1), LopanColors.success.opacity(0.05)]
            case .high: return [Color.orange.opacity(0.1), Color.orange.opacity(0.05)]
            case .critical: return [LopanColors.error.opacity(0.1), LopanColors.error.opacity(0.05)]
            }
        }
        
        var accentColor: Color {
            switch self {
            case .low: return .blue
            case .normal: return .green
            case .high: return .orange
            case .critical: return .red
            }
        }
    }
    
    enum FlowDirection {
        case rightToLeft, leftToRight, topToBottom, bottomToTop
    }
    
    init(priority: DataPriority = .normal, flowDirection: FlowDirection = .rightToLeft, @ViewBuilder content: () -> Content) {
        self.content = content()
        self.priority = priority
        self.flowDirection = flowDirection
    }
    
    var body: some View {
        content
            .padding(20)
            .background(
                ZStack {
                    // Glass morphism background
                    RoundedRectangle(cornerRadius: 20)
                        .fill(
                            LinearGradient(
                                colors: priority.gradientColors,
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(
                                    LinearGradient(
                                        colors: [priority.accentColor.opacity(0.3), priority.accentColor.opacity(0.1)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                        .shadow(color: priority.accentColor.opacity(0.1), radius: 8, x: 0, y: 4)
                        .shadow(color: .black.opacity(0.05), radius: 16, x: 0, y: 8)
                    
                    // Animated glow effect
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(priority.accentColor.opacity(glowIntensity), lineWidth: 2)
                        .blur(radius: 4)
                    
                    // Data flow particles
                    ForEach(flowParticles, id: \.id) { particle in
                        Circle()
                            .fill(priority.accentColor.opacity(0.6))
                            .frame(width: particle.size, height: particle.size)
                            .offset(x: particle.x, y: particle.y)
                            .blur(radius: 1)
                    }
                }
            )
            .onAppear {
                startAnimations()
                generateFlowParticles()
            }
    }
    
    private func startAnimations() {
        // Glow pulse animation
        withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
            glowIntensity = 0.8
        }
        
        // Card breathing animation
        withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
            animationOffset = 2
        }
    }
    
    private func generateFlowParticles() {
        flowParticles = (0..<8).map { index in
            FlowParticle(
                x: CGFloat.random(in: -150...150),
                y: CGFloat.random(in: -100...100),
                size: CGFloat.random(in: 2...6),
                speed: Double.random(in: 0.5...2.0)
            )
        }
        
        animateFlowParticles()
    }
    
    private func animateFlowParticles() {
        for index in flowParticles.indices {
            withAnimation(.linear(duration: flowParticles[index].speed).repeatForever(autoreverses: false)) {
                switch flowDirection {
                case .rightToLeft:
                    flowParticles[index].x -= 300
                case .leftToRight:
                    flowParticles[index].x += 300
                case .topToBottom:
                    flowParticles[index].y += 200
                case .bottomToTop:
                    flowParticles[index].y -= 200
                }
            }
        }
        
        // Reset particles periodically
        Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
            generateFlowParticles()
        }
    }
}

// MARK: - Flow Particle Model

private struct FlowParticle: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    let size: CGFloat
    let speed: Double
}

// MARK: - Animated Statistics Chart

struct AnimatedStatsChart: View {
    let data: [OutOfStockDataPoint]
    let title: String
    let maxValue: Double
    
    @State private var animationProgress: Double = 0
    @State private var selectedIndex: Int?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Chart title
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            // Chart area
            GeometryReader { geometry in
                let chartWidth = geometry.size.width
                let chartHeight = geometry.size.height
                let barWidth = chartWidth / CGFloat(data.count) * 0.7
                let spacing = chartWidth / CGFloat(data.count) * 0.3
                
                ZStack {
                    // Background grid
                    ForEach(0..<5) { index in
                        let y = chartHeight * CGFloat(index) / 4
                        Path { path in
                            path.move(to: CGPoint(x: 0, y: y))
                            path.addLine(to: CGPoint(x: chartWidth, y: y))
                        }
                        .stroke(Color.gray.opacity(0.2), lineWidth: 0.5)
                    }
                    
                    // Data bars
                    HStack(spacing: spacing / CGFloat(data.count)) {
                        ForEach(Array(data.enumerated()), id: \.offset) { index, dataPoint in
                            let isSelected = selectedIndex == index
                            let barHeight = chartHeight * (dataPoint.value / maxValue) * animationProgress
                            
                            VStack {
                                Spacer()
                                
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(
                                        LinearGradient(
                                            colors: [dataPoint.color, dataPoint.color.opacity(0.6)],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    .frame(width: barWidth, height: barHeight)
                                    .scaleEffect(isSelected ? 1.1 : 1.0)
                                    .shadow(color: dataPoint.color.opacity(0.3), radius: isSelected ? 8 : 4)
                                    .onTapGesture {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                            selectedIndex = selectedIndex == index ? nil : index
                                        }
                                    }
                                
                                // Value label
                                Text("\(Int(dataPoint.value))")
                                    .font(.caption2)
                                    .fontWeight(.medium)
                                    .foregroundColor(isSelected ? dataPoint.color : .secondary)
                                    .opacity(isSelected || animationProgress > 0.8 ? 1 : 0)
                                
                                // Category label
                                Text(dataPoint.category)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                    .padding(.horizontal, spacing / 2)
                }
            }
            .frame(height: 120)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.5)) {
                    animationProgress = 1.0
                }
            }
        }
    }
}

// MARK: - Chart Data Point Model

struct OutOfStockDataPoint {
    let category: String
    let value: Double
    let color: Color
}

// MARK: - Real-time Performance Indicator

struct PerformanceIndicator: View {
    let title: String
    let currentValue: Double
    let targetValue: Double
    let unit: String
    let type: IndicatorType
    
    @State private var progress: Double = 0
    @State private var pulseScale: CGFloat = 1.0
    
    enum IndicatorType {
        case performance, cache, memory, network
        
        var color: Color {
            switch self {
            case .performance: return .blue
            case .cache: return .green
            case .memory: return .orange
            case .network: return .purple
            }
        }
        
        var icon: String {
            switch self {
            case .performance: return "speedometer"
            case .cache: return "memorychip"
            case .memory: return "chart.pie"
            case .network: return "wifi"
            }
        }
    }
    
    private var normalizedValue: Double {
        return min(currentValue / targetValue, 1.0)
    }
    
    private var statusColor: Color {
        switch normalizedValue {
        case 0.9...:  return .green
        case 0.7..<0.9: return .yellow
        default: return .red
        }
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                Image(systemName: type.icon)
                    .font(.title2)
                    .foregroundColor(type.color)
                
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Spacer()
                
                // Status indicator
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                    .scaleEffect(pulseScale)
                    .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: pulseScale)
            }
            
            // Progress ring
            ZStack {
                // Background ring
                Circle()
                    .stroke(type.color.opacity(0.2), lineWidth: 8)
                    .frame(width: 60, height: 60)
                
                // Progress ring
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        AngularGradient(
                            colors: [type.color.opacity(0.5), type.color],
                            center: .center,
                            startAngle: .degrees(-90),
                            endAngle: .degrees(270)
                        ),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(-90))
                
                // Value text
                VStack(spacing: 2) {
                    Text("\(Int(currentValue))")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text(unit)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            // Target indication
            HStack {
                Text("目标: \(Int(targetValue))\(unit)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("\(Int(normalizedValue * 100))%")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(statusColor)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
        )
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5)) {
                progress = normalizedValue
            }
            
            pulseScale = 1.2
        }
    }
}

// MARK: - Trend Analysis View

struct TrendAnalysisView: View {
    let dataPoints: [TrendDataPoint]
    let title: String
    
    @State private var animationProgress: CGFloat = 0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
            
            GeometryReader { geometry in
                let width = geometry.size.width
                let height = geometry.size.height
                
                ZStack {
                    // Trend line
                    Path { path in
                        guard !dataPoints.isEmpty else { return }
                        
                        let stepX = width / CGFloat(max(dataPoints.count - 1, 1))
                        
                        for (index, point) in dataPoints.enumerated() {
                            let x = CGFloat(index) * stepX
                            let y = height - (height * CGFloat(point.normalizedValue))
                            
                            if index == 0 {
                                path.move(to: CGPoint(x: x, y: y))
                            } else {
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                        }
                    }
                    .trim(from: 0, to: animationProgress)
                    .stroke(
                        LinearGradient(
                            colors: [LopanColors.primary, LopanColors.success],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    
                    // Gradient fill
                    Path { path in
                        guard !dataPoints.isEmpty else { return }
                        
                        let stepX = width / CGFloat(max(dataPoints.count - 1, 1))
                        
                        path.move(to: CGPoint(x: 0, y: height))
                        
                        for (index, point) in dataPoints.enumerated() {
                            let x = CGFloat(index) * stepX
                            let y = height - (height * CGFloat(point.normalizedValue))
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                        
                        path.addLine(to: CGPoint(x: width, y: height))
                        path.closeSubpath()
                    }
                    .trim(from: 0, to: animationProgress)
                    .fill(
                        LinearGradient(
                            colors: [LopanColors.primary.opacity(0.3), LopanColors.primary.opacity(0.0)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    
                    // Data points
                    ForEach(Array(dataPoints.enumerated()), id: \.offset) { index, point in
                        let stepX = width / CGFloat(max(dataPoints.count - 1, 1))
                        let x = CGFloat(index) * stepX
                        let y = height - (height * CGFloat(point.normalizedValue))
                        
                        Circle()
                            .fill(point.trend.color)
                            .frame(width: 8, height: 8)
                            .position(x: x, y: y)
                            .scaleEffect(animationProgress > CGFloat(index) / CGFloat(dataPoints.count) ? 1 : 0)
                    }
                }
            }
            .frame(height: 80)
            .onAppear {
                withAnimation(.easeInOut(duration: 2.0)) {
                    animationProgress = 1.0
                }
            }
        }
    }
}

// MARK: - Trend Data Point Model

struct TrendDataPoint {
    let value: Double
    let normalizedValue: Double // 0-1 range
    let date: Date
    let trend: Trend
    
    enum Trend {
        case up, down, stable
        
        var color: Color {
            switch self {
            case .up: return .green
            case .down: return .red
            case .stable: return .blue
            }
        }
    }
}

// MARK: - Data Flow Animation

struct DataFlowAnimation: View {
    let isActive: Bool
    
    @State private var particles: [DataParticle] = []
    @State private var animationTimer: Timer?
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(particles, id: \.id) { particle in
                    Circle()
                        .fill(particle.color.opacity(0.8))
                        .frame(width: particle.size, height: particle.size)
                        .position(x: particle.position.x, y: particle.position.y)
                        .blur(radius: particle.blur)
                        .scaleEffect(particle.scale)
                }
            }
        }
        .onChange(of: isActive) { active in
            if active {
                startAnimation()
            } else {
                stopAnimation()
            }
        }
        .onDisappear {
            stopAnimation()
        }
    }
    
    private func startAnimation() {
        generateParticles()
        
        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            updateParticles()
        }
    }
    
    private func stopAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil
        particles.removeAll()
    }
    
    private func generateParticles() {
        particles = (0..<20).map { _ in
            DataParticle(
                position: CGPoint(
                    x: CGFloat.random(in: 0...300),
                    y: CGFloat.random(in: 0...200)
                ),
                velocity: CGPoint(
                    x: CGFloat.random(in: -2...2),
                    y: CGFloat.random(in: -2...2)
                ),
                size: CGFloat.random(in: 2...8),
                color: [LopanColors.primary, LopanColors.success, Color.purple, Color.orange].randomElement()!,
                lifespan: Double.random(in: 2...5),
                scale: CGFloat.random(in: 0.5...1.5),
                blur: CGFloat.random(in: 0...2)
            )
        }
    }
    
    private func updateParticles() {
        for index in particles.indices {
            particles[index].position.x += particles[index].velocity.x
            particles[index].position.y += particles[index].velocity.y
            particles[index].lifespan -= 0.1
            
            // Fade out over time
            particles[index].scale *= 0.99
            particles[index].blur += 0.01
            
            // Remove dead particles
            if particles[index].lifespan <= 0 {
                particles[index] = DataParticle(
                    position: CGPoint(x: 0, y: CGFloat.random(in: 0...200)),
                    velocity: CGPoint(x: CGFloat.random(in: 1...3), y: CGFloat.random(in: -1...1)),
                    size: CGFloat.random(in: 2...8),
                    color: [LopanColors.primary, LopanColors.success, Color.purple, Color.orange].randomElement()!,
                    lifespan: Double.random(in: 2...5),
                    scale: 1.0,
                    blur: 0
                )
            }
        }
    }
}

// MARK: - Data Particle Model

private struct DataParticle: Identifiable {
    let id = UUID()
    var position: CGPoint
    var velocity: CGPoint
    let size: CGFloat
    let color: Color
    var lifespan: Double
    var scale: CGFloat
    var blur: CGFloat
}

// MARK: - Preview Examples

#Preview {
    ScrollView {
        VStack(spacing: 24) {
            // Liquid Data Card Example
            LiquidDataCard(priority: .high, flowDirection: .rightToLeft) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("紧急缺货")
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                    
                    Text("今日新增 23 条紧急缺货记录")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Text("处理率")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text("87%")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.orange)
                    }
                }
            }
            
            // Animated Stats Chart Example
            AnimatedStatsChart(
                data: [
                    OutOfStockDataPoint(category: "待处理", value: 45, color: .orange),
                    OutOfStockDataPoint(category: "已完成", value: 123, color: .green),
                    OutOfStockDataPoint(category: "已退货", value: 12, color: .red)
                ],
                title: "状态分布",
                maxValue: 150
            )
            
            // Performance Indicators
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                PerformanceIndicator(
                    title: "查询性能",
                    currentValue: 85,
                    targetValue: 100,
                    unit: "ms",
                    type: .performance
                )
                
                PerformanceIndicator(
                    title: "缓存命中率",
                    currentValue: 92,
                    targetValue: 95,
                    unit: "%",
                    type: .cache
                )
            }
            
            // Trend Analysis
            TrendAnalysisView(
                dataPoints: [
                    TrendDataPoint(value: 100, normalizedValue: 0.5, date: Date(), trend: .up),
                    TrendDataPoint(value: 120, normalizedValue: 0.6, date: Date(), trend: .up),
                    TrendDataPoint(value: 90, normalizedValue: 0.45, date: Date(), trend: .down),
                    TrendDataPoint(value: 150, normalizedValue: 0.75, date: Date(), trend: .up),
                    TrendDataPoint(value: 180, normalizedValue: 0.9, date: Date(), trend: .up)
                ],
                title: "7天缺货趋势"
            )
            
            // Data Flow Animation
            DataFlowAnimation(isActive: true)
                .frame(height: 100)
                .background(Color.black.opacity(0.05))
                .cornerRadius(12)
        }
        .padding(20)
    }
    .background(Color(.systemGroupedBackground))
}