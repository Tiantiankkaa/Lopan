//
//  ColorService.swift
//  Lopan
//
//  Created by Claude Code on 2025/7/31.
//

import Foundation
import SwiftUI

@MainActor
class ColorService: ObservableObject {
    // MARK: - Published Properties
    @Published var colors: [ColorCard] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // MARK: - Dependencies
    private let colorRepository: ColorRepository
    private let machineRepository: MachineRepository
    private let auditService: NewAuditingService
    private let authService: AuthenticationService
    
    init(colorRepository: ColorRepository, machineRepository: MachineRepository, auditService: NewAuditingService, authService: AuthenticationService) {
        self.colorRepository = colorRepository
        self.machineRepository = machineRepository
        self.auditService = auditService
        self.authService = authService
    }
    
    // MARK: - Color Management
    func loadColors() async {
        isLoading = true
        errorMessage = nil
        
        do {
            colors = try await colorRepository.fetchAllColors()
        } catch {
            errorMessage = "Failed to load colors: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func loadActiveColors() async {
        isLoading = true
        errorMessage = nil
        
        do {
            colors = try await colorRepository.fetchActiveColors()
        } catch {
            errorMessage = "Failed to load active colors: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func addColor(name: String, hexCode: String) async -> Bool {
        guard let currentUser = authService.currentUser,
              currentUser.hasRole(.workshopManager) || currentUser.hasRole(.administrator) else {
            errorMessage = "Insufficient permissions to add colors"
            return false
        }
        
        // Validate input
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Color name cannot be empty"
            return false
        }
        
        guard isValidHexColor(hexCode) else {
            errorMessage = "Invalid hex color code"
            return false
        }
        
        // Check for duplicate names
        if colors.contains(where: { $0.name.lowercased() == name.lowercased() && $0.isActive }) {
            errorMessage = "A color with this name already exists"
            return false
        }
        
        isLoading = true
        
        do {
            let newColor = ColorCard(name: name.trimmingCharacters(in: .whitespacesAndNewlines), hexCode: hexCode.uppercased(), createdBy: currentUser.id)
            try await colorRepository.addColor(newColor)
            
            // Audit log
            try await auditService.logOperation(
                operationType: .create,
                entityType: .color,
                entityId: newColor.id,
                entityDescription: newColor.name,
                operatorUserId: currentUser.id,
                operatorUserName: currentUser.name,
                operationDetails: [
                    "colorName": newColor.name,
                    "hexCode": newColor.hexCode,
                    "createdBy": currentUser.name
                ]
            )
            
            await loadColors()
            isLoading = false
            return true
            
        } catch {
            errorMessage = "Failed to add color: \(error.localizedDescription)"
            isLoading = false
            return false
        }
    }
    
    func updateColor(_ color: ColorCard, name: String, hexCode: String) async -> Bool {
        guard let currentUser = authService.currentUser,
              currentUser.hasRole(.workshopManager) || currentUser.hasRole(.administrator) else {
            errorMessage = "Insufficient permissions to update colors"
            return false
        }
        
        // Validate input
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Color name cannot be empty"
            return false
        }
        
        guard isValidHexColor(hexCode) else {
            errorMessage = "Invalid hex color code"
            return false
        }
        
        // Check for duplicate names (excluding current)
        if colors.contains(where: { $0.id != color.id && $0.name.lowercased() == name.lowercased() && $0.isActive }) {
            errorMessage = "A color with this name already exists"
            return false
        }
        
        let oldName = color.name
        let oldHex = color.hexCode
        
        color.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        color.hexCode = hexCode.uppercased()
        
        do {
            try await colorRepository.updateColor(color)
            
            // Audit log
            try await auditService.logOperation(
                operationType: .update,
                entityType: .color,
                entityId: color.id,
                entityDescription: color.name,
                operatorUserId: currentUser.id,
                operatorUserName: currentUser.name,
                operationDetails: [
                    "oldName": oldName,
                    "newName": color.name,
                    "oldHex": oldHex,
                    "newHex": color.hexCode,
                    "updatedBy": currentUser.name
                ]
            )
            
            return true
            
        } catch {
            // Revert changes on error
            color.name = oldName
            color.hexCode = oldHex
            errorMessage = "Failed to update color: \(error.localizedDescription)"
            return false
        }
    }
    
    func deleteColor(_ color: ColorCard) async -> Bool {
        guard let currentUser = authService.currentUser,
              currentUser.hasRole(.workshopManager) || currentUser.hasRole(.administrator) else {
            errorMessage = "Insufficient permissions to delete colors"
            return false
        }
        
        // Check if color is in use by any guns
        do {
            let machines = try await machineRepository.fetchAllMachines()
            let isInUse = machines.contains { machine in
                machine.guns.contains { $0.currentColorId == color.id }
            }
            
            if isInUse {
                errorMessage = "Cannot delete color that is currently assigned to guns"
                return false
            }
            
            try await colorRepository.deleteColor(color)
            
            // Audit log
            try await auditService.logOperation(
                operationType: .delete,
                entityType: .color,
                entityId: color.id,
                entityDescription: color.name,
                operatorUserId: currentUser.id,
                operatorUserName: currentUser.name,
                operationDetails: [
                    "colorName": color.name,
                    "hexCode": color.hexCode,
                    "deletedBy": currentUser.name
                ]
            )
            
            await loadColors()
            return true
            
        } catch {
            errorMessage = "Failed to delete color: \(error.localizedDescription)"
            return false
        }
    }
    
    // MARK: - Gun Color Assignment
    func assignColorToGun(_ color: ColorCard, gun: WorkshopGun) async -> Bool {
        guard let currentUser = authService.currentUser,
              currentUser.hasRole(.workshopManager) || currentUser.hasRole(.administrator) else {
            errorMessage = "Insufficient permissions to assign colors"
            return false
        }
        
        let oldColorId = gun.currentColorId
        let oldColorName = gun.currentColorName
        
        gun.assignColor(color)
        
        do {
            let machine = try await machineRepository.fetchAllMachines().first { $0.guns.contains { $0.id == gun.id } }
            if let machine = machine {
                try await machineRepository.updateMachine(machine)
            }
            
            // Audit log
            try await auditService.logOperation(
                operationType: .colorAssignment,
                entityType: .gun,
                entityId: gun.id,
                entityDescription: gun.name,
                operatorUserId: currentUser.id,
                operatorUserName: currentUser.name,
                operationDetails: [
                    "gunName": gun.name,
                    "oldColor": oldColorName ?? "None",
                    "newColor": color.name,
                    "newColorHex": color.hexCode,
                    "assignedBy": currentUser.name
                ]
            )
            
            return true
            
        } catch {
            // Revert changes on error
            gun.currentColorId = oldColorId
            gun.currentColorName = oldColorName
            errorMessage = "Failed to assign color to gun: \(error.localizedDescription)"
            return false
        }
    }
    
    func clearGunColor(_ gun: WorkshopGun) async -> Bool {
        guard let currentUser = authService.currentUser,
              currentUser.hasRole(.workshopManager) || currentUser.hasRole(.administrator) else {
            errorMessage = "Insufficient permissions to clear gun colors"
            return false
        }
        
        let oldColorName = gun.currentColorName
        gun.clearColor()
        
        do {
            let machine = try await machineRepository.fetchAllMachines().first { $0.guns.contains { $0.id == gun.id } }
            if let machine = machine {
                try await machineRepository.updateMachine(machine)
            }
            
            // Audit log
            try await auditService.logOperation(
                operationType: .colorAssignment,
                entityType: .gun,
                entityId: gun.id,
                entityDescription: gun.name,
                operatorUserId: currentUser.id,
                operatorUserName: currentUser.name,
                operationDetails: [
                    "gunName": gun.name,
                    "oldColor": oldColorName ?? "None",
                    "newColor": "None",
                    "clearedBy": currentUser.name
                ]
            )
            
            return true
            
        } catch {
            errorMessage = "Failed to clear gun color: \(error.localizedDescription)"
            return false
        }
    }
    
    // MARK: - Utility Methods
    func searchColors(by name: String) async -> [ColorCard] {
        do {
            return try await colorRepository.searchColors(by: name)
        } catch {
            errorMessage = "Failed to search colors: \(error.localizedDescription)"
            return []
        }
    }
    
    private func isValidHexColor(_ hex: String) -> Bool {
        let hex = hex.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        let regex = "^#?([A-Fa-f0-9]{6}|[A-Fa-f0-9]{3})$"
        return hex.range(of: regex, options: .regularExpression) != nil
    }
    
    func clearError() {
        errorMessage = nil
    }
}