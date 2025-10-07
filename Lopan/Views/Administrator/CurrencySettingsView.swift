//
//  CurrencySettingsView.swift
//  Lopan
//
//  Created by Claude Code on 2025-10-07.
//  Admin interface for managing company-wide currency settings
//

import SwiftUI

/// Administrator view for configuring company currency
struct CurrencySettingsView: View {

    // MARK: - State

    @State private var selectedCurrency: String
    @State private var searchText = ""
    @State private var showConfirmation = false
    @Environment(\.dismiss) private var dismiss

    init() {
        _selectedCurrency = State(initialValue: CurrencyService.shared.currencyCode)
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            List {
                // Current Currency Section
                Section {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Current Currency")
                                .font(.system(size: 14))
                                .foregroundColor(Color(hex: "#6B7280") ?? Color.secondary)

                            HStack(spacing: 8) {
                                Text(CurrencyService.shared.currencySymbol)
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(Color(hex: "#6366F1") ?? Color.blue)

                                Text(CurrencyService.shared.currencyDisplayName)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(Color(hex: "#111827") ?? Color.primary)
                            }

                            Text(CurrencyService.shared.currencyCode)
                                .font(.system(size: 12))
                                .foregroundColor(Color(hex: "#9CA3AF") ?? Color.secondary)
                        }

                        Spacer()

                        // Price Preview
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Example")
                                .font(.system(size: 12))
                                .foregroundColor(Color(hex: "#6B7280") ?? Color.secondary)

                            Text(CurrencyService.shared.formatPrice(150.00))
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(Color(hex: "#111827") ?? Color.primary)
                        }
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("Active Currency")
                        .font(.system(size: 13, weight: .semibold))
                        .textCase(.uppercase)
                }

                // Common Currencies Section
                Section {
                    ForEach(filteredCurrencies, id: \.code) { currency in
                        currencyRow(currency)
                    }
                } header: {
                    Text("Select Currency")
                        .font(.system(size: 13, weight: .semibold))
                        .textCase(.uppercase)
                }

                // Warning Section
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: "info.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(Color(hex: "#F59E0B") ?? Color.orange)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Currency Migration")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Color(hex: "#111827") ?? Color.primary)

                            Text("Changing currency affects all product prices and sales records. Historical data remains unchanged - only the display symbol changes.")
                                .font(.system(size: 13))
                                .foregroundColor(Color(hex: "#6B7280") ?? Color.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .searchable(text: $searchText, prompt: "Search currencies...")
            .navigationTitle("Currency Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if selectedCurrency != CurrencyService.shared.currencyCode {
                            showConfirmation = true
                        } else {
                            dismiss()
                        }
                    }
                    .disabled(selectedCurrency == CurrencyService.shared.currencyCode)
                }
            }
            .confirmationDialog(
                "Change Company Currency?",
                isPresented: $showConfirmation,
                titleVisibility: .visible
            ) {
                Button("Change Currency", role: .destructive) {
                    CurrencyService.shared.setCurrency(selectedCurrency)
                    LopanHapticEngine.shared.success()
                    dismiss()
                }

                Button("Cancel", role: .cancel) {
                    selectedCurrency = CurrencyService.shared.currencyCode
                }
            } message: {
                Text("This will change the currency symbol for all products and sales. Price values remain the same.")
            }
        }
    }

    // MARK: - Currency Row

    @ViewBuilder
    private func currencyRow(_ currency: (code: String, name: String, symbol: String)) -> some View {
        Button {
            LopanHapticEngine.shared.light()
            selectedCurrency = currency.code
        } label: {
            HStack(spacing: 12) {
                // Currency Symbol
                Text(currency.symbol)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(Color(hex: "#6366F1") ?? Color.blue)
                    .frame(width: 40, alignment: .center)

                // Currency Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(currency.name)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color(hex: "#111827") ?? Color.primary)

                    Text(currency.code)
                        .font(.system(size: 13))
                        .foregroundColor(Color(hex: "#6B7280") ?? Color.secondary)
                }

                Spacer()

                // Selection Indicator
                if selectedCurrency == currency.code {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(Color(hex: "#6366F1") ?? Color.blue)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Filtered Currencies

    private var filteredCurrencies: [(code: String, name: String, symbol: String)] {
        if searchText.isEmpty {
            return CurrencyService.commonCurrencies
        }

        return CurrencyService.commonCurrencies.filter { currency in
            currency.code.localizedCaseInsensitiveContains(searchText) ||
            currency.name.localizedCaseInsensitiveContains(searchText)
        }
    }
}

// MARK: - Preview

#Preview {
    CurrencySettingsView()
}
