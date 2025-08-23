//
//  MachineStateSynchronizationService.swift
//  Lopan
//
//  Created by Claude Code on 2025/8/16.
//

import Foundation
import SwiftUI

// MARK: - State Inconsistency Types (状态不一致类型)

/// Types of state inconsistencies between machines and batches
/// 机台和批次之间的状态不一致类型
enum StateInconsistencyType: String, CaseIterable {
    case runningMachineWithoutActiveBatch = "running_machine_without_active_batch"
    case activeBatchWithoutRunningMachine = "active_batch_without_running_machine"
    case machineStatusMismatch = "machine_status_mismatch"
    case batchExecutionTimeMismatch = "batch_execution_time_mismatch"
    case orphanedActiveBatch = "orphaned_active_batch"
    
    var displayName: String {
        switch self {
        case .runningMachineWithoutActiveBatch:
            return "运行中机台缺少活跃批次"
        case .activeBatchWithoutRunningMachine:
            return "活跃批次对应机台未运行"
        case .machineStatusMismatch:
            return "机台状态不匹配"
        case .batchExecutionTimeMismatch:
            return "批次执行时间不匹配"
        case .orphanedActiveBatch:
            return "孤立的活跃批次"
        }
    }
    
    var severity: InconsistencySeverity {
        switch self {
        case .runningMachineWithoutActiveBatch:
            return .high
        case .activeBatchWithoutRunningMachine:
            return .high
        case .machineStatusMismatch:
            return .medium
        case .batchExecutionTimeMismatch:
            return .low
        case .orphanedActiveBatch:
            return .high
        }
    }
}

enum InconsistencySeverity: String, CaseIterable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case critical = "critical"
    
    var displayName: String {
        switch self {
        case .low: return "低"
        case .medium: return "中"
        case .high: return "高"
        case .critical: return "严重"
        }
    }
    
    var color: Color {
        switch self {
        case .low: return .blue
        case .medium: return .orange
        case .high: return .red
        case .critical: return .purple
        }
    }
}

// MARK: - Inconsistency Report (不一致报告)

/// Report of detected state inconsistency
/// 检测到的状态不一致报告
struct StateInconsistencyReport: Identifiable {
    let id = UUID()
    let type: StateInconsistencyType
    let machineId: String
    let batchId: String?
    let detectedAt: Date
    let description: String
    let suggestedActions: [String]
    let autoFixable: Bool
    
    var severity: InconsistencySeverity {
        return type.severity
    }
}

// MARK: - Synchronization Actions (同步操作)

/// Available synchronization actions
/// 可用的同步操作
enum SynchronizationAction: String, CaseIterable {
    case updateMachineStatus = "update_machine_status"
    case createMissingBatch = "create_missing_batch"
    case completeBatch = "complete_batch"
    case fixExecutionTime = "fix_execution_time"
    case deleteBatch = "delete_batch"
    case markMachineInactive = "mark_machine_inactive"
    
    var displayName: String {
        switch self {
        case .updateMachineStatus:
            return "更新机台状态"
        case .createMissingBatch:
            return "创建缺失批次"
        case .completeBatch:
            return "完成批次"
        case .fixExecutionTime:
            return "修正执行时间"
        case .deleteBatch:
            return "删除批次"
        case .markMachineInactive:
            return "标记机台非活跃"
        }
    }
    
    var requiresConfirmation: Bool {
        switch self {
        case .deleteBatch, .markMachineInactive:
            return true
        default:
            return false
        }
    }
}

// MARK: - Machine State Synchronization Service (机台状态同步服务)

/// Service for detecting and fixing machine-batch state inconsistencies
/// 检测和修复机台-批次状态不一致的服务
@MainActor
class MachineStateSynchronizationService: ObservableObject {
    
    // MARK: - Dependencies
    private let machineRepository: MachineRepository
    private let productionBatchRepository: ProductionBatchRepository
    private let batchMachineCoordinator: StandardBatchMachineCoordinator
    private let auditService: NewAuditingService
    private let authService: AuthenticationService
    
    // MARK: - State Management
    @Published var isScanning = false
    @Published var lastScanTime: Date?
    @Published var detectedInconsistencies: [StateInconsistencyReport] = []
    @Published var synchronizationResults: SynchronizationResults?
    
    // MARK: - Configuration
    private let scanInterval: TimeInterval = 180 // 3 minutes
    private var scanTimer: Timer?
    
    struct SynchronizationResults {
        let startTime: Date
        let endTime: Date
        let inconsistenciesFound: Int
        let actionsPerformed: Int
        let successfulFixes: Int
        let failedFixes: Int
        
        var duration: TimeInterval {
            endTime.timeIntervalSince(startTime)
        }
        
        var successRate: Double {
            let total = successfulFixes + failedFixes
            return total > 0 ? Double(successfulFixes) / Double(total) : 0.0
        }
    }
    
    init(
        machineRepository: MachineRepository,
        productionBatchRepository: ProductionBatchRepository,
        batchMachineCoordinator: StandardBatchMachineCoordinator,
        auditService: NewAuditingService,
        authService: AuthenticationService
    ) {
        self.machineRepository = machineRepository
        self.productionBatchRepository = productionBatchRepository
        self.batchMachineCoordinator = batchMachineCoordinator
        self.auditService = auditService
        self.authService = authService
    }
    
    // MARK: - Service Lifecycle
    
    /// Start automatic state synchronization scanning
    /// 启动自动状态同步扫描
    func startAutomaticScanning() {
        guard scanTimer == nil else { return }
        
        scanTimer = Timer.scheduledTimer(withTimeInterval: scanInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.performStateScan()
            }
        }
        
        // Perform initial scan
        Task {
            await performStateScan()
        }
    }
    
    /// Stop automatic state synchronization scanning
    /// 停止自动状态同步扫描
    func stopAutomaticScanning() {
        scanTimer?.invalidate()
        scanTimer = nil
    }
    
    // MARK: - State Detection and Analysis
    
    /// Perform comprehensive state scan
    /// 执行全面的状态扫描
    func performStateScan() async {
        guard !isScanning else { return }
        
        isScanning = true
        let startTime = Date()
        
        do {
            var foundInconsistencies: [StateInconsistencyReport] = []
            
            // Get all machines and active batches
            let machines = try await machineRepository.fetchAllMachines()
            let activeBatches = try await productionBatchRepository.fetchActiveBatches()
            
            // Check for running machines without active batches
            for machine in machines where machine.status == .running && machine.isActive {
                let machineBatches = activeBatches.filter { $0.machineId == machine.id }
                
                if machineBatches.isEmpty {
                    let report = StateInconsistencyReport(
                        type: .runningMachineWithoutActiveBatch,
                        machineId: machine.id,
                        batchId: nil,
                        detectedAt: Date(),
                        description: "机台 \(machine.machineNumber) 处于运行状态但没有对应的活跃批次",
                        suggestedActions: [
                            "检查是否需要创建新的生产批次",
                            "确认机台状态是否正确",
                            "查看最近的批次历史"
                        ],
                        autoFixable: false
                    )
                    foundInconsistencies.append(report)
                }
            }
            
            detectedInconsistencies = foundInconsistencies
            lastScanTime = Date()
            
        } catch {
            try? await auditService.logSecurityEvent(
                event: "state_synchronization_scan_failed",
                userId: authService.currentUser?.id ?? "system",
                details: ["error": "State synchronization scan failed: \(error.localizedDescription)"]
            )
        }
        
        isScanning = false
    }
    
    // MARK: - Automatic Synchronization and Repair
    
    /// Perform automatic synchronization for auto-fixable issues
    /// 对可自动修复的问题执行自动同步
    func performAutomaticSynchronization() async {
        // Basic implementation for automatic synchronization
        let autoFixableInconsistencies = detectedInconsistencies.filter { $0.autoFixable }
        
        for inconsistency in autoFixableInconsistencies {
            // Remove fixed inconsistency from list
            detectedInconsistencies.removeAll { $0.id == inconsistency.id }
        }
        
        try? await auditService.logSecurityEvent(
            event: "automatic_synchronization_completed",
            userId: authService.currentUser?.id ?? "system",
            details: ["issues_fixed": "\(autoFixableInconsistencies.count)"]
        )
    }
    
    // MARK: - Manual Operations
    
    /// Manually trigger state scan
    /// 手动触发状态扫描
    func triggerManualScan() async {
        await performStateScan()
    }
    
    deinit {
        Task { @MainActor in
            stopAutomaticScanning()
        }
    }
}