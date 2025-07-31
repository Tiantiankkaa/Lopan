//
//  LocalUserRepository.swift
//  Lopan
//
//  Created by Claude Code on 2025/7/31.
//

import Foundation
import SwiftData

@MainActor
class LocalUserRepository: UserRepository {
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    func fetchUsers() async throws -> [User] {
        let descriptor = FetchDescriptor<User>()
        return try modelContext.fetch(descriptor)
    }
    
    func fetchUser(byId id: String) async throws -> User? {
        let descriptor = FetchDescriptor<User>()
        let users = try modelContext.fetch(descriptor)
        return users.first { $0.id == id }
    }
    
    func fetchUser(byWechatId wechatId: String) async throws -> User? {
        let descriptor = FetchDescriptor<User>()
        let users = try modelContext.fetch(descriptor)
        return users.first { $0.wechatId == wechatId }
    }
    
    func fetchUser(byAppleUserId appleUserId: String) async throws -> User? {
        let descriptor = FetchDescriptor<User>()
        let users = try modelContext.fetch(descriptor)
        return users.first { $0.appleUserId == appleUserId }
    }
    
    func fetchUser(byPhone phone: String) async throws -> User? {
        let descriptor = FetchDescriptor<User>()
        let users = try modelContext.fetch(descriptor)
        return users.first { $0.phone == phone }
    }
    
    func addUser(_ user: User) async throws {
        modelContext.insert(user)
        try modelContext.save()
    }
    
    func updateUser(_ user: User) async throws {
        try modelContext.save()
    }
    
    func deleteUser(_ user: User) async throws {
        modelContext.delete(user)
        try modelContext.save()
    }
    
    func deleteUsers(_ users: [User]) async throws {
        for user in users {
            modelContext.delete(user)
        }
        try modelContext.save()
    }
}