//
//  LocationDataService.swift
//  Lopan
//
//  Created by Claude Code on 2025-10-09.
//

import Foundation

/// Service for managing location data (countries, regions, cities)
@MainActor
class LocationDataService {
    static let shared = LocationDataService()

    private init() {}

    /// Load location data (placeholder for future implementation)
    func loadLocationData() async {
        // Placeholder - location data is already defined in Country.swift
        print("📍 LocationDataService: Using static country data from Country.swift")
    }

    /// Get country by ID
    /// - Parameter id: Country code (e.g., "CN", "US", "NG")
    /// - Returns: Country object or nil if not found
    func getCountry(byId id: String) -> Country? {
        return Country.allCountries.first { $0.id == id }
    }
}
