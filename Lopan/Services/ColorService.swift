//
//  ColorService.swift
//  Lopan
//
//  Created by Claude Code on 2025/7/31.
//

import Foundation
import SwiftUI

@MainActor
public class ColorService: ObservableObject, ServiceCleanupProtocol {
    // MARK: - Published Properties
    @Published var colors: [ColorCard] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // MARK: - Dependencies
    private let colorRepository: ColorRepository
    private let machineRepository: MachineRepository
    private let auditService: NewAuditingService
    private let authService: AuthenticationService
    
    // MARK: - Task Management
    private var isCleanedUp = false
    
    init(colorRepository: ColorRepository, machineRepository: MachineRepository, auditService: NewAuditingService, authService: AuthenticationService) {
        self.colorRepository = colorRepository
        self.machineRepository = machineRepository
        self.auditService = auditService
        self.authService = authService
    }
    
    // MARK: - Cleanup
    func cleanup() {
        isCleanedUp = true
        
        // Clear published properties
        colors.removeAll()
        isLoading = false
        errorMessage = nil
    }
    
    // MARK: - Safety Checks
    private var isUserLoggedIn: Bool {
        return !isCleanedUp && authService.currentUser != nil && authService.isAuthenticated
    }
    
    // MARK: - Color Management
    func loadColors() async {
        // Safety check: Don't proceed if user is logged out or service is cleaned up
        guard isUserLoggedIn else { return }
        
        isLoading = true
        errorMessage = nil
        
        let task = Task { @MainActor in
            do {
                // Check if task was cancelled
                try Task.checkCancellation()
                
                // Double-check user is still logged in before SwiftData operation
                guard isUserLoggedIn else { return }
                
                let fetchedColors = try await colorRepository.fetchAllColors()
                
                // Final check before updating UI
                guard !Task.isCancelled && isUserLoggedIn else { return }
                
                colors = fetchedColors
            } catch is CancellationError {
                // Task was cancelled - this is expected during logout
                return
            } catch {
                guard isUserLoggedIn else { return }
                errorMessage = "Failed to load colors: \(error.localizedDescription)"
            }
            
            if isUserLoggedIn {
                isLoading = false
            }
        }
        
        await task.value
    }
    
    func loadActiveColors() async {
        // Safety check: Don't proceed if user is logged out or service is cleaned up
        guard isUserLoggedIn else { return }
        
        isLoading = true
        errorMessage = nil
        
        let task = Task { @MainActor in
            do {
                // Check if task was cancelled
                try Task.checkCancellation()
                
                // Double-check user is still logged in before SwiftData operation
                guard isUserLoggedIn else { return }
                
                let fetchedColors = try await colorRepository.fetchActiveColors()
                
                // Final check before updating UI
                guard !Task.isCancelled && isUserLoggedIn else { return }
                
                colors = fetchedColors
            } catch is CancellationError {
                // Task was cancelled - this is expected during logout
                return
            } catch {
                guard isUserLoggedIn else { return }
                errorMessage = "Failed to load active colors: \(error.localizedDescription)"
            }
            
            if isUserLoggedIn {
                isLoading = false
            }
        }
        
        await task.value
    }
    
    func addColor(name: String, hexCode: String) async -> Bool {
        // Safety check: Don't proceed if user is logged out or service is cleaned up
        guard isUserLoggedIn else { return false }
        
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
        
        let task = Task { @MainActor in
            do {
                // Check if task was cancelled
                try Task.checkCancellation()
                
                // Double-check user is still logged in before SwiftData operation
                guard isUserLoggedIn else { return false }
                
                let newColor = ColorCard(name: name.trimmingCharacters(in: .whitespacesAndNewlines), hexCode: hexCode.uppercased(), createdBy: currentUser.id)
                try await colorRepository.addColor(newColor)
                
                // Check again before audit log
                guard !Task.isCancelled && isUserLoggedIn else { return false }
                
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
                
                if isUserLoggedIn {
                    isLoading = false
                }
                return true
                
            } catch is CancellationError {
                // Task was cancelled - this is expected during logout
                return false
            } catch {
                guard isUserLoggedIn else { return false }
                errorMessage = "Failed to add color: \(error.localizedDescription)"
                isLoading = false
                return false
            }
        }
        
        let result = await task.value
        
        return result
    }
    
    func updateColor(_ color: ColorCard, name: String, hexCode: String) async -> Bool {
        // Safety check: Don't proceed if user is logged out or service is cleaned up
        guard isUserLoggedIn else { return false }
        
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
        
        let task = Task { @MainActor in
            do {
                // Check if task was cancelled
                try Task.checkCancellation()
                
                // Double-check user is still logged in before SwiftData operation
                guard isUserLoggedIn else {
                    // Revert changes on logout
                    color.name = oldName
                    color.hexCode = oldHex
                    return false
                }
                
                try await colorRepository.updateColor(color)
                
                // Check again before audit log
                guard !Task.isCancelled && isUserLoggedIn else { return false }
                
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
                
            } catch is CancellationError {
                // Task was cancelled - revert changes
                color.name = oldName
                color.hexCode = oldHex
                return false
            } catch {
                // Revert changes on error
                color.name = oldName
                color.hexCode = oldHex
                guard isUserLoggedIn else { return false }
                errorMessage = "Failed to update color: \(error.localizedDescription)"
                return false
            }
        }
        
        let result = await task.value
        
        return result
    }
    
    func deleteColor(_ color: ColorCard) async -> Bool {
        // Safety check: Don't proceed if user is logged out or service is cleaned up
        guard isUserLoggedIn else { return false }
        
        guard let currentUser = authService.currentUser,
              currentUser.hasRole(.workshopManager) || currentUser.hasRole(.administrator) else {
            errorMessage = "Insufficient permissions to delete colors"
            return false
        }
        
        let task = Task { @MainActor in
            do {
                // Check if task was cancelled
                try Task.checkCancellation()
                
                // Double-check user is still logged in before SwiftData operation
                guard isUserLoggedIn else { return false }
                
                // Check if color is in use by any guns
                let machines = try await machineRepository.fetchAllMachines()
                
                // Check again after async operation
                guard !Task.isCancelled && isUserLoggedIn else { return false }
                
                let isInUse = machines.contains { machine in
                    machine.guns.contains { $0.currentColorId == color.id }
                }
                
                if isInUse {
                    errorMessage = "Cannot delete color that is currently assigned to guns"
                    return false
                }
                
                try await colorRepository.deleteColor(color)
                
                // Check again before audit log
                guard !Task.isCancelled && isUserLoggedIn else { return false }
                
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
                
            } catch is CancellationError {
                // Task was cancelled - this is expected during logout
                return false
            } catch {
                guard isUserLoggedIn else { return false }
                errorMessage = "Failed to delete color: \(error.localizedDescription)"
                return false
            }
        }
        
        let result = await task.value
        
        return result
    }
    
    // MARK: - Gun Color Assignment
    func assignColorToGun(_ color: ColorCard, gun: WorkshopGun) async -> Bool {
        // Safety check: Don't proceed if user is logged out or service is cleaned up
        guard isUserLoggedIn else { return false }
        
        guard let currentUser = authService.currentUser,
              currentUser.hasRole(.workshopManager) || currentUser.hasRole(.administrator) else {
            errorMessage = "Insufficient permissions to assign colors"
            return false
        }
        
        let oldColorId = gun.currentColorId
        let oldColorName = gun.currentColorName
        let oldColorHex = gun.currentColorHex
        
        gun.assignColor(color)
        
        let task = Task { @MainActor in
            do {
                // Check if task was cancelled
                try Task.checkCancellation()
                
                // Double-check user is still logged in before SwiftData operation
                guard isUserLoggedIn else {
                    // Revert changes on logout
                    gun.currentColorId = oldColorId
                    gun.currentColorName = oldColorName
                    gun.currentColorHex = oldColorHex
                    return false
                }
                
                let machine = try await machineRepository.fetchAllMachines().first { $0.guns.contains { $0.id == gun.id } }
                
                // Check again after async operation
                guard !Task.isCancelled && isUserLoggedIn else {
                    // Revert changes if cancelled
                    gun.currentColorId = oldColorId
                    gun.currentColorName = oldColorName
                    gun.currentColorHex = oldColorHex
                    return false
                }
                
                if let machine = machine {
                    try await machineRepository.updateMachine(machine)
                }
                
                // Check again before audit log
                guard !Task.isCancelled && isUserLoggedIn else { return false }
                
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
                
            } catch is CancellationError {
                // Task was cancelled - revert changes
                gun.currentColorId = oldColorId
                gun.currentColorName = oldColorName
                gun.currentColorHex = oldColorHex
                return false
            } catch {
                // Revert changes on error
                gun.currentColorId = oldColorId
                gun.currentColorName = oldColorName
                gun.currentColorHex = oldColorHex
                guard isUserLoggedIn else { return false }
                errorMessage = "Failed to assign color to gun: \(error.localizedDescription)"
                return false
            }
        }
        
        let result = await task.value
        
        return result
    }
    
    func clearGunColor(_ gun: WorkshopGun) async -> Bool {
        // Safety check: Don't proceed if user is logged out or service is cleaned up
        guard isUserLoggedIn else { return false }
        
        guard let currentUser = authService.currentUser,
              currentUser.hasRole(.workshopManager) || currentUser.hasRole(.administrator) else {
            errorMessage = "Insufficient permissions to clear gun colors"
            return false
        }
        
        let oldColorId = gun.currentColorId
        let oldColorName = gun.currentColorName
        let oldColorHex = gun.currentColorHex
        
        gun.clearColor()
        
        let task = Task { @MainActor in
            do {
                // Check if task was cancelled
                try Task.checkCancellation()
                
                // Double-check user is still logged in before SwiftData operation
                guard isUserLoggedIn else {
                    // Revert changes on logout
                    gun.currentColorId = oldColorId
                    gun.currentColorName = oldColorName
                    gun.currentColorHex = oldColorHex
                    return false
                }
                
                let machine = try await machineRepository.fetchAllMachines().first { $0.guns.contains { $0.id == gun.id } }
                
                // Check again after async operation
                guard !Task.isCancelled && isUserLoggedIn else {
                    // Revert changes if cancelled
                    gun.currentColorId = oldColorId
                    gun.currentColorName = oldColorName
                    gun.currentColorHex = oldColorHex
                    return false
                }
                
                if let machine = machine {
                    try await machineRepository.updateMachine(machine)
                }
                
                // Check again before audit log
                guard !Task.isCancelled && isUserLoggedIn else { return false }
                
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
                
            } catch is CancellationError {
                // Task was cancelled - revert changes
                gun.currentColorId = oldColorId
                gun.currentColorName = oldColorName
                gun.currentColorHex = oldColorHex
                return false
            } catch {
                // Revert changes on error
                gun.currentColorId = oldColorId
                gun.currentColorName = oldColorName
                gun.currentColorHex = oldColorHex
                guard isUserLoggedIn else { return false }
                errorMessage = "Failed to clear gun color: \(error.localizedDescription)"
                return false
            }
        }
        
        let result = await task.value
        
        return result
    }
    
    // MARK: - Utility Methods
    func searchColors(by name: String) async -> [ColorCard] {
        // Safety check: Don't proceed if user is logged out or service is cleaned up
        guard isUserLoggedIn else { return [] }
        
        let task = Task<[ColorCard], Never> { @MainActor in
            do {
                // Check if task was cancelled
                try Task.checkCancellation()
                
                // Double-check user is still logged in before SwiftData operation
                guard isUserLoggedIn else { return [] }
                
                let searchResults = try await colorRepository.searchColors(by: name)
                
                // Final check before returning results
                guard !Task.isCancelled && isUserLoggedIn else { return [] }
                
                return searchResults
            } catch is CancellationError {
                // Task was cancelled - this is expected during logout
                return []
            } catch {
                guard isUserLoggedIn else { return [] }
                errorMessage = "Failed to search colors: \(error.localizedDescription)"
                return []
            }
        }
        
        let result = await task.value
        
        return result
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