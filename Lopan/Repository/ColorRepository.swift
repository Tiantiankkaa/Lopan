//
//  ColorRepository.swift
//  Lopan
//
//  Created by Claude Code on 2025/7/31.
//

import Foundation

protocol ColorRepository {
    func fetchAllColors() async throws -> [ColorCard]
    func fetchActiveColors() async throws -> [ColorCard]
    func fetchColorById(_ id: String) async throws -> ColorCard?
    func addColor(_ color: ColorCard) async throws
    func updateColor(_ color: ColorCard) async throws
    func deleteColor(_ color: ColorCard) async throws
    func deactivateColor(_ color: ColorCard) async throws
    func searchColors(by name: String) async throws -> [ColorCard]
}