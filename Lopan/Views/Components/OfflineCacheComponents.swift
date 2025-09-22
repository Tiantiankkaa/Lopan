//
//  OfflineCacheComponents.swift
//  Lopan
//
//  Created by Claude Code on 2025/8/16.
//

import SwiftUI
import Network
import Combine

// MARK: - Network Monitor
@MainActor
class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()
    
    @Published var isConnected = true
    @Published var connectionType: NWInterface.InterfaceType?
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    private init() {
        startMonitoring()
    }
    
    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = path.status == .satisfied
                self?.connectionType = path.availableInterfaces.first?.type
            }
        }
        monitor.start(queue: queue)
    }
    
    deinit {
        monitor.cancel()
    }
}

// MARK: - Cache Manager
@MainActor
class OfflineCacheManager: ObservableObject {
    static let shared = OfflineCacheManager()
    
    @Published var cacheStatus: CacheStatus = .idle
    @Published var lastSyncDate: Date?
    @Published var cachedItemsCount: Int = 0
    
    private let cacheDirectory: URL
    private let maxCacheSize: Int64 = 100 * 1024 * 1024 // 100MB
    private let maxCacheAge: TimeInterval = 7 * 24 * 60 * 60 // 7 days
    
    enum CacheStatus {
        case idle, syncing, cleaning, error(Error)
    }
    
    private init() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        cacheDirectory = documentsPath.appendingPathComponent("OfflineCache")
        
        createCacheDirectoryIfNeeded()
        loadCacheInfo()
    }
    
    private func createCacheDirectoryIfNeeded() {
        if !FileManager.default.fileExists(atPath: cacheDirectory.path) {
            try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        }
    }
    
    private func loadCacheInfo() {
        Task {
            do {
                let files = try FileManager.default.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.contentModificationDateKey])
                cachedItemsCount = files.count
                
                // Find last sync date
                let lastModified = files.compactMap { url in
                    try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
                }.max()
                
                lastSyncDate = lastModified
            } catch {
                print("Error loading cache info: \(error)")
            }
        }
    }
    
    // MARK: - Cache Operations
    
    func cacheData<T: Codable>(_ data: [T], forKey key: String) async throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        let encodedData = try encoder.encode(data)
        let fileURL = cacheDirectory.appendingPathComponent("\(key).json")
        
        try encodedData.write(to: fileURL)
        
        // Update cache info
        cachedItemsCount += 1
        lastSyncDate = Date()
    }
    
    func loadCachedData<T: Codable>(forKey key: String, type: T.Type) async throws -> [T]? {
        let fileURL = cacheDirectory.appendingPathComponent("\(key).json")
        
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }
        
        // Check if cache is expired
        let fileAttributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
        if let modificationDate = fileAttributes[.modificationDate] as? Date {
            if Date().timeIntervalSince(modificationDate) > maxCacheAge {
                try FileManager.default.removeItem(at: fileURL)
                return nil
            }
        }
        
        let data = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        return try decoder.decode([T].self, from: data)
    }
    
    func clearCache() async {
        cacheStatus = .cleaning
        
        do {
            let files = try FileManager.default.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil)
            for file in files {
                try FileManager.default.removeItem(at: file)
            }
            
            cachedItemsCount = 0
            lastSyncDate = nil
            cacheStatus = .idle
        } catch {
            cacheStatus = .error(error)
        }
    }
    
    func cleanExpiredCache() async {
        cacheStatus = .cleaning
        
        do {
            let files = try FileManager.default.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.contentModificationDateKey])
            
            for file in files {
                let resourceValues = try file.resourceValues(forKeys: [.contentModificationDateKey])
                if let modificationDate = resourceValues.contentModificationDate {
                    if Date().timeIntervalSince(modificationDate) > maxCacheAge {
                        try FileManager.default.removeItem(at: file)
                        cachedItemsCount -= 1
                    }
                }
            }
            
            cacheStatus = .idle
        } catch {
            cacheStatus = .error(error)
        }
    }
    
    func getCacheSize() -> Int64 {
        do {
            let files = try FileManager.default.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.fileSizeKey])
            
            return files.reduce(0) { total, file in
                do {
                    let resourceValues = try file.resourceValues(forKeys: [.fileSizeKey])
                    return total + Int64(resourceValues.fileSize ?? 0)
                } catch {
                    return total
                }
            }
        } catch {
            return 0
        }
    }
}

// MARK: - Offline-First Service
@MainActor
class OfflineFirstService<T: Codable>: ObservableObject {
    @Published var items: [T] = []
    @Published var isLoading = false
    @Published var isOfflineMode = false
    @Published var lastSyncDate: Date?
    @Published var syncError: Error?
    
    private let cacheKey: String
    private let cacheManager = OfflineCacheManager.shared
    private let networkMonitor = NetworkMonitor.shared
    private var cancellables = Set<AnyCancellable>()
    
    init(cacheKey: String) {
        self.cacheKey = cacheKey
        setupNetworkMonitoring()
        loadFromCache()
    }
    
    private func setupNetworkMonitoring() {
        networkMonitor.$isConnected
            .sink { [weak self] isConnected in
                self?.isOfflineMode = !isConnected
                if isConnected && self?.items.isEmpty == true {
                    // Note: syncWithServer needs a fetchData function to be called manually
                }
            }
            .store(in: &cancellables)
    }
    
    private func loadFromCache() {
        Task {
            do {
                if let cachedItems = try await cacheManager.loadCachedData(forKey: cacheKey, type: T.self) {
                    items = cachedItems
                    lastSyncDate = cacheManager.lastSyncDate
                }
            } catch {
                print("Error loading from cache: \(error)")
            }
        }
    }
    
    func syncWithServer(fetchData: @escaping () async throws -> [T]) async {
        guard networkMonitor.isConnected else {
            isOfflineMode = true
            return
        }
        
        isLoading = true
        syncError = nil
        
        do {
            let serverData = try await fetchData()
            items = serverData
            
            // Cache the data
            try await cacheManager.cacheData(serverData, forKey: cacheKey)
            lastSyncDate = Date()
            isOfflineMode = false
        } catch {
            syncError = error
            // If we have cached data, use it
            if items.isEmpty {
                loadFromCache()
            }
        }
        
        isLoading = false
    }
    
    func addItem(_ item: T, syncToServer: @escaping (T) async throws -> Void) async {
        // Add to local items immediately
        items.append(item)
        
        // Cache updated items
        do {
            try await cacheManager.cacheData(items, forKey: cacheKey)
        } catch {
            print("Error caching item: \(error)")
        }
        
        // Sync to server if online
        if networkMonitor.isConnected {
            do {
                try await syncToServer(item)
            } catch {
                syncError = error
                // TODO: Add to pending sync queue
            }
        }
    }
    
    func removeItem(at index: Int, syncToServer: @escaping (T) async throws -> Void) async {
        guard index < items.count else { return }
        
        let item = items[index]
        items.remove(at: index)
        
        // Cache updated items
        do {
            try await cacheManager.cacheData(items, forKey: cacheKey)
        } catch {
            print("Error caching after removal: \(error)")
        }
        
        // Sync to server if online
        if networkMonitor.isConnected {
            do {
                try await syncToServer(item)
            } catch {
                syncError = error
                // TODO: Add to pending sync queue
            }
        }
    }
}

// MARK: - Offline Status View
struct OfflineStatusView: View {
    @ObservedObject private var networkMonitor = NetworkMonitor.shared
    @ObservedObject private var cacheManager = OfflineCacheManager.shared
    
    var body: some View {
        if !networkMonitor.isConnected {
            HStack(spacing: 12) {
                Image(systemName: "wifi.slash")
                    .foregroundColor(.orange)
                    .accessibilityHidden(true)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("离线模式")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.orange)
                    
                    Text("显示缓存数据")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if let lastSync = cacheManager.lastSyncDate {
                    Text("上次同步: \(formatSyncDate(lastSync))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.orange.opacity(0.1))
            .accessibilityElement(children: .combine)
            .accessibilityLabel("离线模式，显示缓存数据")
            .accessibilityValue(cacheManager.lastSyncDate != nil ? "上次同步时间 \(formatSyncDate(cacheManager.lastSyncDate!))" : "无同步记录")
        }
    }
    
    private func formatSyncDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - Cache Management View
struct CacheManagementView: View {
    @ObservedObject private var cacheManager = OfflineCacheManager.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingClearAlert = false
    
    var body: some View {
        NavigationStack {
            List {
                Section("缓存状态") {
                    HStack {
                        Text("缓存文件数量")
                        Spacer()
                        Text("\(cacheManager.cachedItemsCount)")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("缓存大小")
                        Spacer()
                        Text(formatBytes(cacheManager.getCacheSize()))
                            .foregroundColor(.secondary)
                    }
                    
                    if let lastSync = cacheManager.lastSyncDate {
                        HStack {
                            Text("上次同步")
                            Spacer()
                            Text(formatDate(lastSync))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Section("操作") {
                    Button("清理过期缓存") {
                        Task {
                            await cacheManager.cleanExpiredCache()
                        }
                    }
                    .foregroundColor(.blue)
                    
                    Button("清空所有缓存") {
                        showingClearAlert = true
                    }
                    .foregroundColor(.red)
                }
                
                Section("缓存状态") {
                    switch cacheManager.cacheStatus {
                    case .idle:
                        Label("正常", systemImage: "checkmark.circle")
                            .foregroundColor(.green)
                    case .syncing:
                        Label("同步中", systemImage: "arrow.triangle.2.circlepath")
                            .foregroundColor(.blue)
                    case .cleaning:
                        Label("清理中", systemImage: "trash")
                            .foregroundColor(.orange)
                    case .error(let error):
                        Label("错误: \(error.localizedDescription)", systemImage: "exclamationmark.triangle")
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("缓存管理")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
            .alert("清空缓存", isPresented: $showingClearAlert) {
                Button("取消", role: .cancel) { }
                Button("清空", role: .destructive) {
                    Task {
                        await cacheManager.clearCache()
                    }
                }
            } message: {
                Text("确定要清空所有缓存数据吗？这将删除所有离线数据。")
            }
        }
        .adaptiveBackground()
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useKB, .useBytes]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Sync Button
struct SyncButton: View {
    let onSync: () async -> Void
    
    @ObservedObject private var networkMonitor = NetworkMonitor.shared
    @State private var isSyncing = false
    
    var body: some View {
        Button(action: {
            guard !isSyncing && networkMonitor.isConnected else { return }
            
            Task {
                isSyncing = true
                await onSync()
                isSyncing = false
            }
        }) {
            HStack(spacing: 8) {
                if isSyncing {
                    ProgressView()
                        .scaleEffect(0.8)
                        .accessibilityLabel("正在同步")
                } else {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .accessibilityHidden(true)
                }
                
                Text(isSyncing ? "同步中" : "同步")
                    .font(.subheadline)
            }
        }
        .disabled(!networkMonitor.isConnected || isSyncing)
        .foregroundColor(networkMonitor.isConnected ? .blue : .gray)
        .accessibilityLabel(isSyncing ? "正在同步数据" : "同步数据")
        .accessibilityHint(networkMonitor.isConnected ? "轻点同步最新数据" : "无网络连接，无法同步")
    }
}

// MARK: - View Extensions for Offline Support
extension View {
    func withOfflineSupport() -> some View {
        VStack(spacing: 0) {
            OfflineStatusView()
            self
        }
    }
    
    func offlineAware<T: Codable>(
        service: OfflineFirstService<T>,
        onRefresh: @escaping () async -> Void
    ) -> some View {
        self
            .refreshable {
                await onRefresh()
            }
            .overlay(alignment: .bottom) {
                if service.isLoading {
                    LoadingStateView("同步数据中...")
                }
            }
    }
}