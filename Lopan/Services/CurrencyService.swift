//
//  CurrencyService.swift
//  Lopan
//
//  Created by Claude Code on 2025-10-07.
//  Centralized currency management for company-wide currency settings
//

import Foundation

/// Service for managing company-wide currency settings
/// Provides formatted price strings and allows easy currency migration
final class CurrencyService {

    // MARK: - Singleton

    static let shared = CurrencyService()

    private init() {
        // Load currency from UserDefaults or use sensible default
        if storedCurrencyCode == nil {
            // First launch: Auto-detect from device locale
            let detectedCurrency = Locale.current.currency?.identifier ?? "USD"
            setCurrency(detectedCurrency)
        }
    }

    // MARK: - Storage Keys

    private let currencyCodeKey = "com.lopan.currencyCode"

    // MARK: - Currency Code

    /// Current company currency code (ISO 4217)
    var currencyCode: String {
        get {
            storedCurrencyCode ?? "USD"
        }
    }

    private var storedCurrencyCode: String? {
        UserDefaults.standard.string(forKey: currencyCodeKey)
    }

    /// Changes the company currency code
    /// - Parameter code: ISO 4217 currency code (e.g., "NGN", "USD", "KES")
    func setCurrency(_ code: String) {
        UserDefaults.standard.set(code, forKey: currencyCodeKey)

        // Post notification for UI updates
        NotificationCenter.default.post(
            name: .currencyDidChange,
            object: nil,
            userInfo: ["currencyCode": code]
        )
    }

    // MARK: - Price Formatting

    /// Formats a decimal price with the current currency symbol
    /// - Parameter price: Price value
    /// - Returns: Formatted string (e.g., "₦150.00" or "$150.00")
    func formatPrice(_ price: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        return formatter.string(from: price as NSDecimalNumber) ?? "\(currencyCode) \(price)"
    }

    /// Formats an optional decimal price
    /// - Parameter price: Optional price value
    /// - Returns: Formatted string or "N/A" if nil
    func formatPrice(_ price: Decimal?) -> String {
        guard let price = price else { return "N/A" }
        return formatPrice(price)
    }

    // MARK: - Currency Symbol

    /// Returns the currency symbol for the current currency
    /// - Returns: Symbol string (e.g., "₦", "$", "£")
    var currencySymbol: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        return formatter.currencySymbol
    }

    // MARK: - Currency Display Name

    /// Returns the display name for the current currency
    /// - Returns: Localized currency name (e.g., "Nigerian Naira", "US Dollar")
    var currencyDisplayName: String {
        let locale = Locale.current
        return locale.localizedString(forCurrencyCode: currencyCode) ?? currencyCode
    }
}

// MARK: - Notification Names

extension Notification.Name {
    /// Posted when the currency code changes
    static let currencyDidChange = Notification.Name("currencyDidChange")
}

// MARK: - Common Currencies

extension CurrencyService {
    /// List of commonly used currencies for the currency picker
    static let commonCurrencies: [(code: String, name: String, symbol: String)] = [
        // Africa
        ("NGN", "Nigerian Naira", "₦"),
        ("ZAR", "South African Rand", "R"),
        ("KES", "Kenyan Shilling", "KSh"),
        ("GHS", "Ghanaian Cedi", "₵"),
        ("EGP", "Egyptian Pound", "£"),

        // Americas
        ("USD", "US Dollar", "$"),
        ("CAD", "Canadian Dollar", "CA$"),
        ("BRL", "Brazilian Real", "R$"),
        ("MXN", "Mexican Peso", "$"),

        // Asia
        ("CNY", "Chinese Yuan", "¥"),
        ("INR", "Indian Rupee", "₹"),
        ("JPY", "Japanese Yen", "¥"),
        ("SGD", "Singapore Dollar", "S$"),
        ("AED", "UAE Dirham", "د.إ"),
        ("KRW", "South Korean Won", "₩"),

        // Europe
        ("EUR", "Euro", "€"),
        ("GBP", "British Pound", "£"),
        ("CHF", "Swiss Franc", "CHF"),

        // Oceania
        ("AUD", "Australian Dollar", "A$"),
        ("NZD", "New Zealand Dollar", "NZ$")
    ]

    /// Returns the display info for a given currency code
    /// - Parameter code: ISO 4217 currency code
    /// - Returns: Tuple with code, name, and symbol, or nil if not found
    static func currencyInfo(for code: String) -> (code: String, name: String, symbol: String)? {
        commonCurrencies.first { $0.code == code }
    }
}
