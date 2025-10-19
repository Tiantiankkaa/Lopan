//
//  UserRepository.swift
//  Lopan
//
//  Created by Claude Code on 2025/7/31.
//

import Foundation

@MainActor
public protocol UserRepository {
    func fetchUsers() async throws -> [User]
    func fetchUser(byId id: String) async throws -> User?
    func fetchUser(byWechatId wechatId: String) async throws -> User?
    func fetchUser(byAppleUserId appleUserId: String) async throws -> User?
    func fetchUser(byPhone phone: String) async throws -> User?
    func addUser(_ user: User) async throws
    func updateUser(_ user: User) async throws
    func deleteUser(_ user: User) async throws
    func deleteUsers(_ users: [User]) async throws
}