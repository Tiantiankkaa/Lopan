# CLAUDE-PERFORMANCE.md — Performance Optimization Standards

> **Companion Document to CLAUDE.md**  
> Focus: System performance, caching architecture, and optimization strategies for iOS development

---

## Table of Contents

1. [System Performance Standards](#1-system-performance-standards)
2. [Code Organization for Performance](#2-code-organization-for-performance)
3. [Reusable Performance Components](#3-reusable-performance-components)
4. [Implementation Guidelines](#4-implementation-guidelines)
5. [Performance Monitoring](#5-performance-monitoring)

---

## 1. System Performance Standards

> **Reference**: Performance standards derived from Customer Out-of-Stock optimization experience and iOS 17+ best practices.

### 1.1 Three-Tier Caching Architecture

**Implementation Requirements:**
- **Hot Cache**: Frequently accessed data, 5-minute TTL, 5MB limit
- **Warm Cache**: Recently accessed data, 15-minute TTL, 15MB limit  
- **Predictive Cache**: Anticipated data based on patterns, 1-hour TTL, 30MB limit

**Memory Budget Allocation:**
- Total application memory: 150MB max
- Cache subsystem: 50MB (Hot: 5MB, Warm: 15MB, Predictive: 30MB)
- Business operations: 25MB
- UI rendering: 75MB

**Cache Promotion Rules:**
```swift
// Cache access triggers automatic promotion
if accessCount > 3 && age < 300 { // Hot cache criteria
    promoteToHotCache(key: key, data: data)
} else if accessCount > 1 && age < 900 { // Warm cache criteria
    promoteToWarmCache(key: key, data: data)
}
```

### 1.2 Performance Benchmarks

**Critical Operation Targets:**
- Repository fetch operations: P95 < 100ms
- Cache hit operations: P95 < 10ms
- State updates: P95 < 50ms
- Background sync: Complete within 30s
- Memory pressure response: Clear 50% cache within 100ms

**Response Time Requirements:**
- UI state changes: < 16ms (60 FPS target)
- Search operations: < 200ms (perceived instant)
- Data loading: < 1s initial, < 300ms subsequent
- Export operations: < 5s for typical datasets

### 1.3 Swift Concurrency Optimization

**Structured Concurrency Patterns:**
```swift
// Use TaskGroup for batch operations >10 items
func processBatchConcurrently<T>(_ items: [T], processor: @escaping (T) async throws -> Void) async throws {
    try await withThrowingTaskGroup(of: Void.self) { group in
        for item in items {
            group.addTask { try await processor(item) }
        }
        try await group.waitForAll()
    }
}

// Actor isolation for cache and state management
@MainActor
class PerformanceOptimizedCache<T: Codable> {
    private var hotCache: [String: CachedData<T>] = [:]
    private var warmCache: [String: CachedData<T>] = [:]
}
```

**Async/Await Best Practices:**
- Use `@MainActor` for UI state management classes
- Implement proper cancellation with `Task.checkCancellation()`
- Leverage `AsyncSequence` for data streams
- Apply structured concurrency patterns consistently

### 1.4 Background Processing

**BGTaskScheduler Integration:**
```swift
// Register background tasks for performance optimization
BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.lopan.cache-optimization", using: nil) { task in
    Task {
        defer { task.setTaskCompleted(success: true) }
        await optimizeCacheInBackground()
    }
}
```

**Background Task Types:**
- **Cache Warming**: Predictive cache population every 15 minutes
- **Data Synchronization**: Sync operations every 30 minutes
- **Cleanup Operations**: Memory optimization during low usage periods
- **Performance Analysis**: Metrics collection and optimization

### 1.5 Memory Management

**Pressure Handling Strategy:**
```swift
enum MemoryPressureLevel {
    case warning    // Clear predictive cache
    case critical   // Clear warm cache, reduce hot cache by 50%
    case urgent     // Keep only essential hot cache entries
}

func handleMemoryPressure(_ level: MemoryPressureLevel) async {
    switch level {
    case .warning:
        await clearPredictiveCache()
    case .critical:
        await clearWarmCache()
        await reduceHotCache(by: 0.5)
    case .urgent:
        await keepOnlyEssentialCache()
    }
}
```

**Memory Monitoring:**
- Continuous monitoring with `PerformanceMonitor`
- Automatic cache eviction based on system memory warnings
- Proactive cleanup before reaching system limits
- Recovery strategy with gradual cache rebuilding

### 1.6 Performance Validation Gates

**Mandatory Performance Checks:**
- [ ] **Memory Usage**: Peak usage < 150MB total application memory
- [ ] **Cache Efficiency**: Hit rate > 80% for frequently accessed data
- [ ] **Response Time**: P95 < 100ms for critical user operations
- [ ] **Background Tasks**: Complete within allocated time windows
- [ ] **Memory Pressure**: Recovery within 100ms of pressure detection

**Performance Regression Triggers:**
- Memory usage increase > 20% from baseline
- Cache hit rate drop > 10% from target
- Response time degradation > 50% from benchmark  
- Background task timeout > 2x expected duration

### 1.7 Monitoring and Observability

**Key Performance Indicators:**
```swift
struct PerformanceMetrics {
    let cacheHitRate: Double
    let averageResponseTime: TimeInterval
    let peakMemoryUsage: Int64
    let backgroundTaskCompletionRate: Double
}
```

**Monitoring Implementation:**
- Real-time performance metrics collection
- Automated alerting for performance degradation
- Historical performance trending
- Integration with development and production monitoring

---

## 2. Code Organization for Performance

> **Reference**: Performance-optimized directory structure integrating Core components from Customer Out-of-Stock optimization.

### 2.1 Core Directory Structure

**Mandatory Organization:**
```
Lopan/
├── Core/                          # System-wide reusable components
│   ├── Cache/                     # Caching infrastructure  
│   │   ├── SmartCacheManager.swift       # Three-tier intelligent cache
│   │   ├── LRUMemoryCache.swift          # Generic LRU implementation
│   │   └── CacheProtocols.swift          # Cache interfaces
│   ├── Performance/               # Performance optimization
│   │   ├── PerformanceMonitor.swift      # Metrics collection
│   │   ├── BatchProcessor.swift          # Concurrent processing
│   │   └── PerformanceGates.swift        # Validation checkpoints
│   ├── Concurrency/              # Swift Concurrency utilities
│   │   ├── ActorPatterns.swift           # Actor-based patterns
│   │   ├── TaskGroupHelpers.swift        # TaskGroup utilities
│   │   └── CancellationSupport.swift     # Cancellation handling
│   ├── Memory/                   # Memory management
│   │   ├── MemoryOptimizer.swift         # Memory pressure handling
│   │   ├── MemoryMonitor.swift           # Usage tracking
│   │   └── MemoryPressureHandler.swift   # System integration
│   └── Security/                 # Security & privacy
│       ├── SecureKeychain.swift          # Enhanced keychain wrapper
│       ├── DataRedaction.swift           # PII protection
│       └── SecurityValidator.swift       # Validation utilities
├── Features/                     # Feature-specific modules
│   └── CustomerOutOfStock/       # Example optimized feature
│       ├── Domain/               # Business models & rules
│       ├── Data/                 # Repository implementations
│       ├── Presentation/         # ViewModels & coordinators
│       └── UI/                   # Views (split by complexity)
├── Models/                       # Domain models (SwiftData/DTO)
├── Repository/                   # Data access protocols
├── Services/                     # Business orchestration
├── Views/                        # SwiftUI (by role, <800 lines each)
├── Utils/                        # Extensions, Logger, FeatureFlags
└── Tests/                        # Unit & UI tests
```

### 2.2 File Size Enforcement

**Hard Limits (CI-enforced):**
- **800 lines max per file** (excluding imports/comments)
- **10 files max per directory** (excluding subdirectories)
- **50 lines max per function**
- **5 levels max nesting depth**

**Violation Handling:**
```swift
// CI Script validation
if fileLines > 800 {
    print("❌ File size violation: \(fileName) has \(fileLines) lines (limit: 800)")
    exit(1)
}
```

### 2.3 Component Extraction Guidelines

**When to Extract to Core/:**
- Component used by >2 feature modules
- Performance-critical functionality (caching, concurrency)
- Cross-cutting concerns (security, monitoring, memory management)
- Foundation patterns for architecture (coordinators, repositories)

**When to Keep in Features/:**
- Feature-specific business logic
- UI components specific to one workflow
- Domain models unique to the feature

### 2.4 Migration Strategy

**Phase 1: Foundation (Week 1)**
- Create Core/ directory structure
- Extract SmartCacheManager from Customer Out-of-Stock
- Move security utilities to Core/Security/

**Phase 2: Performance Infrastructure (Week 2)**
- Extract performance monitoring components
- Implement batch processing utilities
- Add memory management patterns

**Phase 3: Feature Restructuring (Week 3)**
- Reorganize large feature modules
- Split oversized files (>800 lines)
- Apply consistent directory patterns

**Phase 4: Testing & Documentation (Week 4)**
- Add comprehensive tests for Core components
- Update documentation and examples
- Validate performance improvements

### 2.5 Dependency Rules

**Allowed Dependencies:**
- Core/ → Foundation, Swift Standard Library only
- Features/ → Core/, Models/, Repository/
- Views/ → Services/, Utils/, Core/ (NO direct Repository access)
- Services/ → Repository/, Core/, Models/

**Forbidden Dependencies:**
- Core/ → Features/ (circular dependency)
- Views/ → Repository/ (architecture violation)
- Repository/ → Services/ (layering violation)

---

## 3. Reusable Performance Components

### 3.1 SmartCacheManager Implementation

**Three-Tier Architecture:**
```swift
@MainActor
class SmartCacheManager<T: Codable>: ObservableObject {
    // Hot Cache: 5MB, 5-minute TTL, frequently accessed
    private var hotCache: [String: CachedData<T>] = [:]
    
    // Warm Cache: 15MB, 15-minute TTL, recently accessed
    private var warmCache: [String: CachedData<T>] = [:]
    
    // Predictive Cache: 30MB, 1-hour TTL, anticipated data
    private var predictiveCache: [String: CachedData<T>] = [:]
    
    func getCachedData(for key: String) -> [T]? {
        // Check hot cache first
        if let hotData = hotCache[key], !hotData.isExpired {
            updateAccessOrder(key: key, in: &hotAccessOrder)
            hotCache[key] = hotData.updated(accessCount: hotData.accessCount + 1)
            return hotData.records
        }
        
        // Check warm cache, promote if found
        if let warmData = warmCache[key], warmData.age < CacheStrategy.warmDataTTL {
            promoteToHotCache(key: key, data: warmData)
            return warmData.records
        }
        
        return nil
    }
}
```

### 3.2 PerformanceMonitor Usage

**Real-time Metrics Collection:**
```swift
@MainActor
class PerformanceMonitor: ObservableObject {
    func measureOperation<T>(_ name: String, 
                           operation: () async throws -> T) async throws -> T {
        let startTime = CFAbsoluteTimeGetCurrent()
        let startMemory = getCurrentMemoryUsage()
        
        defer {
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            recordMetrics(name: name, duration: duration)
        }
        
        return try await operation()
    }
}
```

### 3.3 BatchProcessor for Concurrency

**Optimized Batch Processing:**
```swift
func processBatchConcurrently<T>(_ items: [T], 
                               chunkSize: Int = 10,
                               processor: @escaping (T) async throws -> Void) async throws {
    let chunks = items.chunked(into: chunkSize)
    try await withThrowingTaskGroup(of: Void.self) { group in
        for chunk in chunks {
            group.addTask {
                for item in chunk {
                    try Task.checkCancellation()
                    try await processor(item)
                }
            }
        }
        try await group.waitForAll()
    }
}
```

---

## 4. Implementation Guidelines

### 4.1 iOS 17+ Modern Patterns

**Observable Framework:**
```swift
// BEFORE: iOS 16 pattern
class DashboardState: ObservableObject {
    @Published var items: [Item] = []
    @Published var isLoading = false
}

// AFTER: iOS 17+ pattern  
@Observable
final class DashboardState {
    var items: [Item] = []
    var isLoading = false
    // No @Published needed - automatic tracking
}
```

### 4.2 Memory Management Best Practices

**Memory Pressure Integration:**
```swift
NotificationCenter.default.addObserver(forName: UIApplication.didReceiveMemoryWarningNotification) { _ in
    await MemoryOptimizer.shared.handleMemoryPressure(.warning)
}
```

### 4.3 Background Task Registration

**System Integration:**
```swift
func applicationDidFinishLaunching() {
    BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.lopan.cache-optimization") { task in
        Task {
            defer { task.setTaskCompleted(success: true) }
            await SmartCacheManager.shared.optimizeInBackground()
        }
    }
}
```

---

## 5. Performance Monitoring

### 5.1 Key Performance Indicators

**System Health Metrics:**
- Cache hit ratio (target: >80%)
- Memory usage (target: <150MB)
- Response times (target: P95 <100ms)
- Background task success rate (target: >95%)

### 5.2 Monitoring Integration

**Real-time Dashboard:**
```swift
struct PerformanceDashboard: View {
    @StateObject private var monitor = PerformanceMonitor.shared
    
    var body: some View {
        VStack {
            MetricCard("Cache Hit Rate", value: monitor.cacheHitRate)
            MetricCard("Memory Usage", value: monitor.memoryUsage)
            MetricCard("Avg Response", value: monitor.avgResponseTime)
        }
    }
}
```

### 5.3 Automated Alerting

**Performance Regression Detection:**
```swift
func validatePerformanceGates() async -> Bool {
    let metrics = await PerformanceMonitor.shared.getCurrentMetrics()
    
    guard metrics.cacheHitRate > 0.8,
          metrics.peakMemoryUsage < 150_000_000,
          metrics.averageResponseTime < 0.1 else {
        await sendPerformanceAlert(metrics)
        return false
    }
    
    return true
}
```

---

**Related Documents:**
- [CLAUDE.md](./CLAUDE.md) - Core architecture guidelines
- [CLAUDE-EXAMPLES.md](./CLAUDE-EXAMPLES.md) - Implementation examples
- [CustomerOutOfStockOptimization_Implementation.md](./CustomerOutOfStockOptimization_Implementation.md) - Specific implementation plan

---

*Document Version: 1.0*  
*Last Updated: 2025-08-31*  
*Companion to: CLAUDE.md*