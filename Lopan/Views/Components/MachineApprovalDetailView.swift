//
//  MachineApprovalDetailView.swift
//  Lopan
//
//  Created by Claude Code on 2025/8/15.
//

import SwiftUI

struct MachineApprovalDetailView: View {
    let machineId: String
    let batches: [ProductionBatch]
    let onBatchTapped: (ProductionBatch) -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(batches, id: \.id) { batch in
                        ApprovalBatchCompactRow(
                            batch: batch,
                            onTap: { 
                                // Close this sheet first, then trigger the parent's batch tap handler
                                dismiss()
                                // Use a small delay to ensure the dismiss animation completes
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    onBatchTapped(batch)
                                }
                            }
                        )
                    }
                }
                .padding()
            }
            .navigationTitle("全部批次")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Preview
struct MachineApprovalDetailView_Previews: PreviewProvider {
    static var previews: some View {
        MachineApprovalDetailView(
            machineId: "test-machine-id",
            batches: [],
            onBatchTapped: { _ in }
        )
    }
}