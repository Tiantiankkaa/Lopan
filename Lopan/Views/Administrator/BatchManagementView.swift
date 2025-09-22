//
//  BatchManagementView.swift
//  Lopan
//
//  Created by Claude Code on 2025/8/5.
//

import SwiftUI
import SwiftData

struct BatchManagementView: View {
    @StateObject private var batchService: ProductionBatchService
    // Machine service removed - not needed for batch management interface
    @ObservedObject private var authService: AuthenticationService
    
    @State private var selectedTab = 0
    @State private var selectedBatch: ProductionBatch?
    @State private var showingReviewSheet = false
    @State private var reviewAction: ReviewAction = .approve
    @State private var reviewNotes = ""
    @State private var selectedStatus: BatchStatus? = nil
    
    enum ReviewAction {
        case approve
        case reject
    }
    
    init(repositoryFactory: RepositoryFactory, authService: AuthenticationService, auditService: NewAuditingService) {
        self.authService = authService
        self._batchService = StateObject(wrappedValue: ProductionBatchService(
            productionBatchRepository: repositoryFactory.productionBatchRepository,
            machineRepository: repositoryFactory.machineRepository,
            colorRepository: repositoryFactory.colorRepository,
            auditService: auditService,
            authService: authService
        ))
        // MachineService initialization removed for performance optimization
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Pending Review Tab
            pendingReviewTab
                .tabItem {
                    Image(systemName: "checkmark.seal")
                    Text("batch_management_tab_pending".localized)
                }
                .tag(0)

            // History & Analytics Tab
            historyAnalyticsTab
                .tabItem {
                    Image(systemName: "clock.arrow.circlepath")
                    Text("batch_management_tab_history".localized)
                }
                .tag(1)
        }
        .navigationTitle("batch_management_title".localized)
        .navigationBarTitleDisplayMode(.large)
        .refreshable {
            await loadData()
        }
        .alert("batch_management_error_title".localized, isPresented: .constant(batchService.errorMessage != nil)) {
            Button("common_ok".localized) {
                batchService.clearError()
            }
        } message: {
            if let errorMessage = batchService.errorMessage {
                Text(errorMessage)
            }
        }
        .sheet(isPresented: $showingReviewSheet) {
            if let batch = selectedBatch {
                ReviewSheet(
                    batch: batch,
                    action: reviewAction,
                    notes: $reviewNotes,
                    batchService: batchService
                ) {
                    selectedBatch = nil
                    showingReviewSheet = false
                    reviewNotes = ""
                }
            }
        }
        .sheet(item: $selectedBatch, onDismiss: {
            selectedBatch = nil
        }) { batch in
            BatchDetailView(batch: batch, batchService: batchService)
        }
        .task {
            await loadData()
        }
    }
    
    // MARK: - Pending Review Tab
    private var pendingReviewTab: some View {
        VStack {
            if batchService.isLoading {
                ProgressView("batch_management_loading_pending".localized)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if batchService.pendingBatches.isEmpty {
                pendingEmptyStateView
            } else {
                pendingBatchesList
            }
        }
    }
    
    private var pendingEmptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.seal")
                .font(.system(size: 64))
                .foregroundColor(.gray)
            
            VStack(spacing: 8) {
                Text("batch_management_pending_empty_title".localized)
                    .font(.title2)
                    .fontWeight(.medium)
                
                Text("batch_management_pending_empty_subtitle".localized)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var pendingBatchesList: some View {
        List {
            ForEach(batchService.pendingBatches, id: \.id) { batch in
                PendingBatchRow(
                    batch: batch,
                    onApprove: {
                        selectedBatch = batch
                        reviewAction = .approve
                        showingReviewSheet = true
                    },
                    onReject: {
                        selectedBatch = batch
                        reviewAction = .reject
                        showingReviewSheet = true
                    }
                )
            }
        }
        .listStyle(.plain)
    }
    
    // MARK: - History & Analytics Tab
    private var historyAnalyticsTab: some View {
        VStack {
            if batchService.isLoading {
                ProgressView("batch_management_loading_history".localized)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                historyContent
            }
        }
    }
    
    private var historyContent: some View {
        VStack(spacing: 0) {
            // Status filter section
            statusFilterSection
            
            // Batch history list
            if filteredBatches.isEmpty {
                historyEmptyStateView
            } else {
                historyBatchesList
            }
        }
    }
    
    private var statusFilterSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // All batches
                StatusFilterChip(
                    title: "batch_management_filter_all".localized,
                    count: batchService.batches.count,
                    isSelected: selectedStatus == nil
                ) {
                    selectedStatus = nil
                }
                
                // Status-specific filters
                ForEach(BatchStatus.allCases, id: \.self) { status in
                    let count = batchService.batches.filter { $0.status == status }.count
                    if count > 0 {
                        StatusFilterChip(
                            title: status.displayName,
                            count: count,
                            isSelected: selectedStatus == status,
                            color: status.color
                        ) {
                            selectedStatus = status
                        }
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
        .background(Color(UIColor.systemBackground))
    }
    
    private var historyEmptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "tray")
                .font(.system(size: 64))
                .foregroundColor(.gray)
            
            VStack(spacing: 8) {
                Text("batch_management_history_empty_title".localized)
                    .font(.title2)
                    .fontWeight(.medium)
                
                Text("batch_management_history_empty_subtitle".localized)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var historyBatchesList: some View {
        List {
            ForEach(filteredBatches, id: \.id) { batch in
                BatchHistoryRow(batch: batch) {
                    selectedBatch = batch
                }
            }
        }
        .listStyle(.plain)
    }
    
    // MARK: - Computed Properties
    var filteredBatches: [ProductionBatch] {
        if let status = selectedStatus {
            return batchService.batches.filter { $0.status == status }
        }
        return batchService.batches
    }
    
    // MARK: - Helper Methods
    private func loadData() async {
        await batchService.loadPendingBatches()
        await batchService.loadBatches()
        // Machine loading removed - not needed for batch management
    }
}

// MARK: - UI Components

// MARK: - Pending Batch Row
struct PendingBatchRow: View {
    let batch: ProductionBatch
    let onApprove: () -> Void
    let onReject: () -> Void

    @State private var showingDetail = false
    
    private var batchSnapshot: BatchDetailInfo { BatchDetailInfo(from: batch) }

    var body: some View {
        let snapshot = batchSnapshot
        let submittedAtString = snapshot.submittedAt.formatted(.dateTime.month().day().hour().minute())
        VStack(spacing: 16) {
            // Main content - tappable for details
            Button {
                showingDetail = true
            } label: {
                VStack(spacing: 16) {
                    // Header
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(snapshot.batchNumber)
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                            
                            Text(String(format: "batch_management_pending_submitter".localized, snapshot.submittedByName))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Text(snapshot.mode.displayName)
                                .font(.caption)
                                .fontWeight(.medium)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(LopanColors.info.opacity(0.2))
                                .foregroundColor(LopanColors.info)
                                .cornerRadius(4)
                            
                            Text(submittedAtString)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Configuration summary
                    VStack(spacing: 8) {
                        HStack {
                            Label(String(format: "batch_management_pending_products_label".localized, snapshot.products.count), systemImage: "cube.box")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Label(String(format: "batch_management_pending_stations_label".localized, snapshot.totalStationsUsed, 12), systemImage: "grid")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        // Configuration validation
                        HStack {
                            Image(systemName: snapshot.isValidConfiguration ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(snapshot.isValidConfiguration ? LopanColors.success : LopanColors.error)
                            
                            Text(snapshot.isValidConfiguration ? "batch_management_pending_config_valid".localized : "batch_management_pending_config_invalid".localized)
                                .font(.caption)
                                .foregroundColor(snapshot.isValidConfiguration ? LopanColors.success : LopanColors.error)
                            
                            Spacer()
                        }
                    }
                    
                    // Products preview
                    if !snapshot.products.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(snapshot.products, id: \.id) { product in
                                    ProductPreviewCard(product: product)
                                }
                            }
                            .padding(.horizontal, 4)
                        }
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(format: "batch_management_pending_row_accessibility_label".localized, snapshot.batchNumber))
            .accessibilityHint("batch_management_pending_row_accessibility_hint".localized)
            
            // Action buttons - separate from main content
            HStack(spacing: 12) {
                Spacer()
                
                Button("batch_management_action_reject".localized) {
                    onReject()
                }
                .buttonStyle(.bordered)
                .foregroundColor(.red)
                .accessibilityHint("batch_management_action_reject_hint".localized)
                
                Button("batch_management_action_approve".localized) {
                    onApprove()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!snapshot.isValidConfiguration)
                .accessibilityHint("batch_management_action_approve_hint".localized)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
        .sheet(isPresented: $showingDetail, onDismiss: {
            showingDetail = false
        }) {
            // Use the proper BatchDetailView that already exists
            NavigationStack {
                ScrollView {
                    VStack(spacing: 20) {
                        // Basic info
                        batchInfoSection(batchSnapshot)

                        // Products
                        productsSection(batchSnapshot)
                    }
                    .padding()
                }
                .navigationTitle("batch_management_detail_title".localized)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("common_close".localized) {
                            showingDetail = false
                        }
                    }
                }
            }
        }
    }
    
    // Helper views for the detail sheet
    private func batchInfoSection(_ batch: BatchDetailInfo) -> some View {
        VStack(spacing: 12) {
            Text("batch_management_info_section_title".localized)
                .font(.headline)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 8) {
                BatchInfoRow(label: "batch_management_info_label_batch_number".localized, value: batch.batchNumber)
                BatchInfoRow(label: "batch_management_info_label_production_mode".localized, value: batch.mode.displayName)
                BatchInfoRow(label: "batch_management_info_label_machine_id".localized, value: batch.machineId)
                BatchInfoRow(label: "batch_management_info_label_status".localized, value: batch.status.displayName)
                BatchInfoRow(label: "batch_management_info_label_submitted_by".localized, value: batch.submittedByName)
                BatchInfoRow(label: "batch_management_info_label_submitted_at".localized, value: batch.submittedAt.formatted(.dateTime))
            }
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
        }
    }
    
    private func productsSection(_ batch: BatchDetailInfo) -> some View {
        VStack(spacing: 12) {
            Text("batch_management_products_section_title".localized)
                .font(.headline)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 8) {
                ForEach(batch.products, id: \.id) { product in
                    BatchProductDetailRow(product: product)
                }
            }
        }
    }
}

// MARK: - Product Preview Card
struct ProductPreviewCard: View {
    let product: BatchDetailInfo.ProductSnapshot
    
    var body: some View {
        VStack(spacing: 4) {
            Text(product.name)
                .font(.caption2)
                .fontWeight(.medium)
                .lineLimit(1)
            
            Text(String(format: "batch_management_product_card_stations".localized, product.occupiedStationsDisplay))
                .font(.caption2)
                .foregroundColor(.secondary)

            if product.isDualColor {
                Text("batch_management_product_card_dual_color".localized)
                    .font(.caption2)
                    .foregroundColor(LopanColors.info)
            }
        }
        .padding(8)
        .background(Color(UIColor.tertiarySystemBackground))
        .cornerRadius(6)
        .frame(width: 80)
    }
}

// MARK: - Status Filter Chip
struct StatusFilterChip: View {
    let title: String
    let count: Int
    let isSelected: Bool
    let color: Color
    let onTap: () -> Void
    
    init(title: String, count: Int, isSelected: Bool, color: Color = .blue, onTap: @escaping () -> Void) {
        self.title = title
        self.count = count
        self.isSelected = isSelected
        self.color = color
        self.onTap = onTap
    }
    
    var body: some View {
        Button {
            onTap()
        } label: {
            HStack(spacing: 6) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("\(count)")
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(isSelected ? Color.white.opacity(0.3) : color.opacity(0.2))
                    .foregroundColor(isSelected ? .white : color)
                    .cornerRadius(8)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? color : Color(UIColor.secondarySystemBackground))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(16)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Batch History Row
struct BatchHistoryRow: View {
    let batch: ProductionBatch
    let onTap: () -> Void
    
    private var batchSnapshot: BatchDetailInfo { BatchDetailInfo(from: batch) }
    
    var body: some View {
        let snapshot = batchSnapshot
        let submittedAtString = snapshot.submittedAt.formatted(.dateTime.month().day().hour().minute())
        Button {
            onTap()
        } label: {
            VStack(spacing: 12) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(snapshot.batchNumber)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        Text(String(format: "batch_management_history_submitted_at".localized, submittedAtString))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Text(snapshot.status.displayName)
                                .font(.caption)
                                .fontWeight(.medium)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(snapshot.status.color.opacity(0.2))
                                .foregroundColor(snapshot.status.color)
                                .cornerRadius(4)
                        
                        Text(snapshot.mode.displayName)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Content summary
                HStack {
                    Label(String(format: "batch_management_pending_products_label".localized, snapshot.products.count), systemImage: "cube.box")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Label(String(format: "batch_management_pending_stations_label".localized, snapshot.totalStationsUsed, 12), systemImage: "grid")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Review info (if applicable)
                if let reviewedAt = snapshot.reviewedAt, let reviewedByName = snapshot.reviewedByName {
                    let reviewedAtString = reviewedAt.formatted(.dateTime.month().day().hour().minute())
                    HStack {
                        Text(String(format: "batch_management_history_reviewed_by".localized, reviewedByName))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text(reviewedAtString)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Review Sheet
struct ReviewSheet: View {
    let batch: ProductionBatch
    let action: BatchManagementView.ReviewAction
    @Binding var notes: String
    @ObservedObject var batchService: ProductionBatchService
    let onDismiss: () -> Void

    @State private var isProcessing = false
    @State private var showingRejectConfirmation = false

    private var snapshot: BatchDetailInfo { BatchDetailInfo(from: batch) }
    
    var actionColor: Color {
        action == .approve ? .green : .red
    }

    var actionTitle: String {
        action == .approve ? "batch_management_review_action_approve".localized : "batch_management_review_action_reject".localized
    }
    
    var actionIcon: String {
        action == .approve ? "checkmark.seal.fill" : "xmark.seal.fill"
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Action header
                VStack(spacing: 16) {
                    Image(systemName: actionIcon)
                        .font(.system(size: 60))
                        .foregroundColor(actionColor)
                    
                    VStack(spacing: 8) {
                        Text(actionTitle)
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text(String(format: "batch_management_review_batch_label".localized, batch.batchNumber))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Batch summary
                batchSummarySection
                
                // Notes section
                notesSection
                
                Spacer()
                
                // Action buttons
                actionButtons
            }
            .padding()
            .navigationTitle("batch_management_review_nav_title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("common_cancel".localized) {
                        onDismiss()
                    }
                }
            }
        }
    }
    
    // MARK: - Batch Summary Section
    private var batchSummarySection: some View {
        let detail = snapshot
        return VStack(spacing: 12) {
            Text("batch_management_summary_title".localized)
                .font(.headline)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 8) {
                SummaryRow(label: "batch_management_info_label_submitted_by".localized, value: detail.submittedByName)
                SummaryRow(label: "batch_management_info_label_production_mode".localized, value: detail.mode.displayName)
                SummaryRow(label: "batch_management_summary_label_product_count".localized, value: String(format: "batch_management_summary_value_product_count".localized, detail.products.count))
                SummaryRow(label: "batch_management_summary_label_station_usage".localized, value: String(format: "batch_management_summary_value_station_usage".localized, detail.totalStationsUsed, 12))
                SummaryRow(label: "batch_management_info_label_submitted_at".localized, value: detail.submittedAt.formatted(.dateTime))
            }
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
        }
    }
    
    // MARK: - Notes Section
    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(action == .approve ? "batch_management_notes_optional".localized : "batch_management_notes_required".localized)
                .font(.headline)
                .fontWeight(.semibold)
            
            TextEditor(text: $notes)
                .frame(minHeight: 100)
                .padding(8)
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(8)
        }
    }
    
    // MARK: - Action Buttons
    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button(actionTitle) {
                if action == .reject {
                    showingRejectConfirmation = true
                } else {
                    performReviewAction()
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(actionColor)
            .disabled(isProcessing || (action == .reject && notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty))
            
            Button("common_cancel".localized) {
                onDismiss()
            }
            .buttonStyle(.bordered)
            .disabled(isProcessing)
        }
        .confirmationDialog(
            "batch_management_confirm_reject_title".localized,
            isPresented: $showingRejectConfirmation,
            titleVisibility: .visible,
            presenting: batch
        ) { _ in
            Button("batch_management_confirm_reject_confirm".localized, role: .destructive) {
                performReviewAction()
            }
            Button("common_cancel".localized, role: .cancel) {
                showingRejectConfirmation = false
            }
        } message: { _ in
            Text(String(format: "batch_management_confirm_reject_message".localized, batch.batchNumber))
        }
    }
    
    // MARK: - Helper Methods
    private func performReviewAction() {
        Task {
            isProcessing = true
            
            let success: Bool
            if action == .approve {
                success = await batchService.approveBatch(batch, notes: notes.isEmpty ? nil : notes)
            } else {
                success = await batchService.rejectBatch(batch, notes: notes)
            }
            
            isProcessing = false
            
            if success {
                onDismiss()
            }
        }
    }
}

// MARK: - Summary Row
struct SummaryRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
}

// MARK: - Batch Detail View
struct BatchDetailView: View {
    let batch: ProductionBatch
    @ObservedObject var batchService: ProductionBatchService
    @Environment(\.dismiss) private var dismiss
    
    private var snapshot: BatchDetailInfo { BatchDetailInfo(from: batch) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Basic info
                    batchInfoSection
                    
                    // Products
                    productsSection
                    
                    // Review info
                    if snapshot.reviewedAt != nil {
                        reviewInfoSection
                    }
                    
                    // Timeline
                    timelineSection
                }
                .padding()
            }
            .navigationTitle("batch_management_detail_title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("common_close".localized) {
                        dismiss()
                    }
                }
            }
        }
    }
    
    // MARK: - Batch Info Section
    private var batchInfoSection: some View {
        let detail = snapshot
        return VStack(spacing: 12) {
            Text("batch_management_info_section_title".localized)
                .font(.headline)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 8) {
                BatchInfoRow(label: "batch_management_info_label_batch_number".localized, value: detail.batchNumber)
                BatchInfoRow(label: "batch_management_info_label_production_mode".localized, value: detail.mode.displayName)
                BatchInfoRow(label: "batch_management_info_label_machine_id".localized, value: detail.machineId)
                BatchInfoRow(label: "batch_management_info_label_status".localized, value: detail.status.displayName)
                BatchInfoRow(label: "batch_management_info_label_submitted_by".localized, value: detail.submittedByName)
                BatchInfoRow(label: "batch_management_info_label_submitted_at".localized, value: detail.submittedAt.formatted(.dateTime))
            }
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
        }
    }
    
    // MARK: - Products Section
    private var productsSection: some View {
        let detail = snapshot
        return VStack(spacing: 12) {
            Text("batch_management_products_section_title".localized)
                .font(.headline)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 8) {
                ForEach(detail.products, id: \.id) { product in
                    BatchProductDetailRow(product: product)
                }
            }
        }
    }
    
    // MARK: - Review Info Section
    private var reviewInfoSection: some View {
        let detail = snapshot
        return VStack(spacing: 12) {
            Text("batch_management_review_info_title".localized)
                .font(.headline)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 8) {
                if let reviewedByName = detail.reviewedByName {
                    BatchInfoRow(label: "batch_management_review_info_reviewer".localized, value: reviewedByName)
                }
                
                if let reviewedAt = detail.reviewedAt {
                    BatchInfoRow(label: "batch_management_review_info_reviewed_at".localized, value: reviewedAt.formatted(.dateTime))
                }
                
                if let reviewNotes = detail.reviewNotes, !reviewNotes.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("batch_management_review_info_notes_title".localized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(reviewNotes)
                            .font(.body)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
        }
    }
    
    // MARK: - Timeline Section
    private var timelineSection: some View {
        let detail = snapshot
        return VStack(spacing: 12) {
            Text("batch_management_timeline_title".localized)
                .font(.headline)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 8) {
                TimelineRow(
                    title: "batch_management_timeline_created_title".localized,
                    subtitle: String(format: "batch_management_timeline_created_subtitle".localized, detail.submittedByName),
                    time: detail.createdAt,
                    isCompleted: true
                )
                
                TimelineRow(
                    title: "batch_management_timeline_submitted_title".localized,
                    subtitle: "batch_management_timeline_submitted_subtitle".localized,
                    time: detail.submittedAt,
                    isCompleted: true
                )

                if let reviewedAt = detail.reviewedAt {
                    TimelineRow(
                        title: detail.status == .approved ? "batch_management_timeline_review_approved_title".localized : "batch_management_timeline_review_rejected_title".localized,
                        subtitle: String(format: "batch_management_timeline_review_subtitle".localized, detail.reviewedByName ?? "batch_management_timeline_reviewer_placeholder".localized),
                        time: reviewedAt,
                        isCompleted: true
                    )
                }

                if let appliedAt = detail.appliedAt ?? detail.completedAt {
                    TimelineRow(
                        title: "batch_management_timeline_applied_title".localized,
                        subtitle: "batch_management_timeline_applied_subtitle".localized,
                        time: appliedAt,
                        isCompleted: true
                    )
                }
            }
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
        }
    }
}

// MARK: - Info Row
struct BatchInfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.body)
                .fontWeight(.medium)
        }
    }
}

// MARK: - Batch Product Detail Row
struct BatchProductDetailRow: View {
    let product: BatchDetailInfo.ProductSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(product.name)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text(String(format: "batch_management_product_detail_stations".localized, product.occupiedStationsDisplay))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(String(format: "batch_management_product_detail_color".localized, product.primaryColorId))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if let stationCount = product.stationCount {
                    Text(String(format: "batch_management_product_detail_station_count".localized, stationCount))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if product.isDualColor {
                    Text("batch_management_product_detail_dual_color".localized)
                        .font(.caption)
                        .foregroundColor(LopanColors.info)
                }
            }
        }
        .padding()
        .background(Color(UIColor.tertiarySystemBackground))
        .cornerRadius(8)
    }
}

// MARK: - Timeline Row
struct TimelineRow: View {
    let title: String
    let subtitle: String
    let time: Date
    let isCompleted: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // Timeline indicator
            VStack {
                Circle()
                    .fill(isCompleted ? LopanColors.success : LopanColors.secondary)
                    .frame(width: 12, height: 12)
                
                if isCompleted {
                    Rectangle()
                        .fill(LopanColors.success)
                        .frame(width: 2, height: 20)
                }
            }
            
            // Content
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(time.formatted(.dateTime.month().day().hour().minute()))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

// MARK: - Preview
struct BatchManagementView_Previews: PreviewProvider {
    static var previews: some View {
        let schema = Schema([
            WorkshopMachine.self, WorkshopStation.self, WorkshopGun.self,
            ColorCard.self, ProductionBatch.self, ProductConfig.self,
            User.self, AuditLog.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: [modelConfiguration])
        let repositoryFactory = LocalRepositoryFactory(modelContext: container.mainContext)
        let authService = AuthenticationService(repositoryFactory: repositoryFactory)
        let auditService = NewAuditingService(repositoryFactory: repositoryFactory)
        
        BatchManagementView(
            repositoryFactory: repositoryFactory,
            authService: authService,
            auditService: auditService
        )
    }
}
