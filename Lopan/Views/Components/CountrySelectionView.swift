//
//  CountrySelectionView.swift
//  Lopan
//
//  Created by Claude Code on 2025-10-09.
//

import SwiftUI

struct CountrySelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedCountry: Country?
    @State private var searchText = ""

    private var filteredCountries: [Country] {
        if searchText.isEmpty {
            return Country.allCountries
        }
        return Country.allCountries.filter { country in
            country.name.localizedCaseInsensitiveContains(searchText) ||
            country.id.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            List(filteredCountries) { country in
                Button(action: {
                    selectedCountry = country
                    dismiss()
                }) {
                    HStack {
                        Text(country.flag)
                            .font(.system(size: 24))
                        Text(country.name)
                            .font(.system(size: 16))
                        Spacer()
                        if selectedCountry?.id == country.id {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .searchable(text: $searchText, prompt: "Search countries")
            .navigationTitle("Select Country")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct RegionSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    let country: Country
    @Binding var selectedRegion: String
    @State private var searchText = ""

    private var filteredRegions: [String] {
        if searchText.isEmpty {
            return country.regions
        }
        return country.regions.filter { region in
            region.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            List(filteredRegions, id: \.self) { region in
                Button(action: {
                    selectedRegion = region
                    dismiss()
                }) {
                    HStack {
                        Text(region)
                            .font(.system(size: 16))
                        Spacer()
                        if selectedRegion == region {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .searchable(text: $searchText, prompt: "Search regions")
            .navigationTitle("Select Region")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview("Country Selection") {
    CountrySelectionView(selectedCountry: .constant(nil))
}

#Preview("Region Selection") {
    RegionSelectionView(country: .china, selectedRegion: .constant(""))
}
