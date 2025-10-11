//
//  Customer+Extensions.swift
//  Lopan
//
//  Created by Claude Code on 2025-10-09.
//

import Foundation

extension Customer {
    // MARK: - Formatted Phone Numbers

    /// Get formatted phone number for display in native iOS style
    /// Example: "+234 801 234 5678"
    var formattedPhone: String {
        guard !phone.isEmpty else { return "" }
        return PhoneNumberFormatter.formatForDisplay(phone)
    }

    /// Get formatted WhatsApp number for display in native iOS style
    /// Example: "+234 801 234 5678"
    var formattedWhatsApp: String {
        guard !whatsappNumber.isEmpty else { return "" }
        return PhoneNumberFormatter.formatForDisplay(whatsappNumber)
    }

    /// Get phone number formatted for accessibility (VoiceOver)
    var accessiblePhone: String {
        guard !phone.isEmpty else { return "No phone number" }
        return PhoneNumberFormatter.formatForAccessibility(phone)
    }

    /// Get WhatsApp number formatted for accessibility (VoiceOver)
    var accessibleWhatsApp: String {
        guard !whatsappNumber.isEmpty else { return "No WhatsApp number" }
        return PhoneNumberFormatter.formatForAccessibility(whatsappNumber)
    }

    // MARK: - Location Display

    /// Get formatted location string: "City, Region, Country"
    /// Example: "Lagos Island, Lagos State, Nigeria"
    /// Returns empty string if location data is incomplete
    var formattedLocation: String {
        // All three components are required for a valid location
        guard !city.isEmpty, !region.isEmpty, !countryName.isEmpty else {
            return ""
        }
        return "\(city), \(region), \(countryName)"
    }

    /// Get short formatted location: "City, Country"
    /// Example: "Lagos Island, Nigeria"
    var formattedLocationShort: String {
        if !city.isEmpty && !countryName.isEmpty {
            return "\(city), \(countryName)"
        } else if !city.isEmpty {
            return city
        } else if !countryName.isEmpty {
            return countryName
        }
        return ""
    }

    /// Get location with flag emoji: "🇳🇬 Lagos Island, Lagos State"
    var formattedLocationWithFlag: String {
        let flag = getCountryFlag()
        let location = formattedLocationShort

        if !flag.isEmpty && !location.isEmpty {
            return "\(flag) \(location)"
        } else if !location.isEmpty {
            return location
        }
        return ""
    }

    /// Check if customer has complete location data
    var hasCompleteLocation: Bool {
        return !country.isEmpty && !region.isEmpty && !city.isEmpty
    }

    /// Get country flag emoji based on country code
    private func getCountryFlag() -> String {
        guard !country.isEmpty else { return "" }

        // Try to find country in the database
        if let matchedCountry = Country.allCountries.first(where: { $0.id == country }) {
            return matchedCountry.flag
        }

        // Fallback: No flag
        return ""
    }

    // MARK: - Display Helpers

    /// Check if customer has any contact information
    var hasContactInfo: Bool {
        return !phone.isEmpty || !whatsappNumber.isEmpty
    }

    /// Get primary contact method (phone if available, otherwise WhatsApp)
    var primaryContact: String {
        if !phone.isEmpty {
            return formattedPhone
        } else if !whatsappNumber.isEmpty {
            return formattedWhatsApp
        }
        return ""
    }

    /// Get display subtitle for customer card (location or legacy address)
    var displaySubtitle: String {
        // Priority 1: Use structured location if available
        if hasCompleteLocation {
            return formattedLocation
        }

        // Priority 2: Fall back to legacy address field (for backward compatibility)
        if !address.isEmpty {
            return address
        }

        // Priority 3: Show partial location if available
        if !city.isEmpty {
            return city
        }

        return "No location"
    }
}
