//
//  EditProductView.swift
//  Lopan
//
//  Placeholder stub for legacy compatibility
//  TODO: Migrate to new product editing architecture
//

import SwiftUI

/// Legacy product editing view - forwards to ModernAddProductView
struct EditProductView: View {
    @Environment(\.dismiss) private var dismiss
    let product: Product

    var body: some View {
        // For now, just show a simple message
        // In the future, this can be replaced with a proper editing interface
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "pencil.circle")
                    .font(.system(size: 64))
                    .foregroundColor(.secondary)

                Text("Product Editing")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Use the new product management interface to edit products.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .navigationTitle("Edit Product")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    EditProductView(product: Product(sku: "PRD-TEST001", name: "Test Product", imageData: nil, price: 100))
}
