//
//  CloudRepositoryStubs.swift
//  Lopan
//
//  Created by Claude Code on 2025/8/27.
//

import Foundation

// MARK: - Cloud User Repository

final class CloudUserRepository: UserRepository, Sendable {
    private let cloudProvider: CloudProvider
    private let baseEndpoint = "/api/users"
    
    init(cloudProvider: CloudProvider) {
        self.cloudProvider = cloudProvider
    }
    
    func createUser(name: String, phone: String) async throws -> User {
        let user = User(wechatId: "", name: name, phone: phone)
        let dto = UserDTO(from: user)
        let response = try await cloudProvider.post(endpoint: baseEndpoint, body: dto, responseType: UserDTO.self)
        
        guard response.success, let responseDTO = response.data else {
            throw RepositoryError.saveFailed(response.error ?? "Create user failed")
        }
        
        return try responseDTO.toDomain()
    }
    
    func fetchUsers() async throws -> [User] {
        let response = try await cloudProvider.getPaginated(endpoint: baseEndpoint, type: UserDTO.self, page: 0, pageSize: 1000)
        
        guard response.success else {
            throw RepositoryError.connectionFailed(response.error ?? "Fetch users failed")
        }
        
        return try response.items.compactMap { try? $0.toDomain() }
    }
    
    func updateUser(_ user: User) async throws {
        let dto = UserDTO(from: user)
        let endpoint = "\(baseEndpoint)/\(user.id)"
        let response = try await cloudProvider.put(endpoint: endpoint, body: dto, responseType: UserDTO.self)
        
        guard response.success else {
            throw RepositoryError.saveFailed(response.error ?? "Update user failed")
        }
    }
    
    func deleteUser(_ user: User) async throws {
        let endpoint = "\(baseEndpoint)/\(user.id)"
        let response = try await cloudProvider.delete(endpoint: endpoint)
        
        guard response.success else {
            throw RepositoryError.deleteFailed(response.error ?? "Delete user failed")
        }
    }
    
    func findUserById(_ id: String) async throws -> User? {
        let endpoint = "\(baseEndpoint)/\(id)"
        let response = try await cloudProvider.get(endpoint: endpoint, type: UserDTO.self)
        
        guard response.success, let dto = response.data else {
            return nil
        }
        
        return try dto.toDomain()
    }
    
    func fetchUser(byId id: String) async throws -> User? {
        let endpoint = "\(baseEndpoint)/\(id)"
        let response = try await cloudProvider.get(endpoint: endpoint, type: UserDTO.self)
        
        guard response.success else {
            if response.error?.contains("not found") == true {
                return nil
            }
            throw RepositoryError.connectionFailed(response.error ?? "Fetch user by ID failed")
        }
        
        return try response.data?.toDomain()
    }
    
    func fetchUser(byWechatId wechatId: String) async throws -> User? {
        let endpoint = "\(baseEndpoint)/by-wechat/\(wechatId)"
        let response = try await cloudProvider.get(endpoint: endpoint, type: UserDTO.self)
        
        guard response.success else {
            if response.error?.contains("not found") == true {
                return nil
            }
            throw RepositoryError.connectionFailed(response.error ?? "Fetch user by WeChat ID failed")
        }
        
        return try response.data?.toDomain()
    }
    
    func findUsersByRole(_ role: UserRole) async throws -> [User] {
        let endpoint = "\(baseEndpoint)/role/\(role.rawValue)"
        let response = try await cloudProvider.getPaginated(endpoint: endpoint, type: UserDTO.self, page: 0, pageSize: 1000)
        
        guard response.success else {
            throw RepositoryError.connectionFailed(response.error ?? "Find users by role failed")
        }
        
        return try response.items.compactMap { try? $0.toDomain() }
    }
    
    func fetchUser(byAppleUserId appleUserId: String) async throws -> User? {
        let endpoint = "\(baseEndpoint)/by-apple/\(appleUserId)"
        let response = try await cloudProvider.get(endpoint: endpoint, type: UserDTO.self)
        
        guard response.success else {
            if response.error?.contains("not found") == true {
                return nil
            }
            throw RepositoryError.connectionFailed(response.error ?? "Fetch user by Apple ID failed")
        }
        
        return try response.data?.toDomain()
    }
    
    func fetchUser(byPhone phone: String) async throws -> User? {
        let endpoint = "\(baseEndpoint)/by-phone/\(phone)"
        let response = try await cloudProvider.get(endpoint: endpoint, type: UserDTO.self)
        
        guard response.success else {
            if response.error?.contains("not found") == true {
                return nil
            }
            throw RepositoryError.connectionFailed(response.error ?? "Fetch user by phone failed")
        }
        
        return try response.data?.toDomain()
    }
    
    func addUser(_ user: User) async throws {
        let endpoint = baseEndpoint
        let userDTO = UserDTO.fromDomain(user)
        let response = try await cloudProvider.post(endpoint: endpoint, body: userDTO, responseType: UserDTO.self)
        
        guard response.success else {
            throw RepositoryError.saveFailed(response.error ?? "Add user failed")
        }
    }
    
    func deleteUsers(_ users: [User]) async throws {
        for user in users {
            let endpoint = "\(baseEndpoint)/\(user.id)"
            let response = try await cloudProvider.delete(endpoint: endpoint)
            
            if !response.success {
                throw RepositoryError.deleteFailed(response.error ?? "Delete user failed")
            }
        }
    }
}

// MARK: - Cloud Customer Repository

final class CloudCustomerRepository: CustomerRepository, Sendable {
    private let cloudProvider: CloudProvider
    private let baseEndpoint = "/api/customers"
    
    init(cloudProvider: CloudProvider) {
        self.cloudProvider = cloudProvider
    }
    
    func fetchCustomers() async throws -> [Customer] {
        let response = try await cloudProvider.getPaginated(endpoint: baseEndpoint, type: CustomerDTO.self, page: 0, pageSize: 1000)
        
        guard response.success else {
            throw RepositoryError.connectionFailed(response.error ?? "Fetch customers failed")
        }
        
        return response.items.map { $0.toDomain() }
    }
    
    func addCustomer(_ customer: Customer) async throws {
        let dto = CustomerDTO(from: customer)
        let response = try await cloudProvider.post(endpoint: baseEndpoint, body: dto, responseType: CustomerDTO.self)
        
        guard response.success else {
            throw RepositoryError.saveFailed(response.error ?? "Add customer failed")
        }
    }
    
    func updateCustomer(_ customer: Customer) async throws {
        let dto = CustomerDTO(from: customer)
        let endpoint = "\(baseEndpoint)/\(customer.id)"
        let response = try await cloudProvider.put(endpoint: endpoint, body: dto, responseType: CustomerDTO.self)
        
        guard response.success else {
            throw RepositoryError.saveFailed(response.error ?? "Update customer failed")
        }
    }
    
    func deleteCustomer(_ customer: Customer) async throws {
        let endpoint = "\(baseEndpoint)/\(customer.id)"
        let response = try await cloudProvider.delete(endpoint: endpoint)
        
        guard response.success else {
            throw RepositoryError.deleteFailed(response.error ?? "Delete customer failed")
        }
    }
    
    func fetchCustomer(by id: String) async throws -> Customer? {
        let endpoint = "\(baseEndpoint)/\(id)"
        let response = try await cloudProvider.get(endpoint: endpoint, type: CustomerDTO.self)
        
        guard response.success, let dto = response.data else {
            return nil
        }
        
        return dto.toDomain()
    }
    
    func searchCustomers(query: String) async throws -> [Customer] {
        let encodedSearch = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let endpoint = "\(baseEndpoint)/search?q=\(encodedSearch)"
        let response = try await cloudProvider.getPaginated(endpoint: endpoint, type: CustomerDTO.self, page: 0, pageSize: 1000)
        
        guard response.success else {
            throw RepositoryError.connectionFailed(response.error ?? "Search customers failed")
        }
        
        return response.items.map { $0.toDomain() }
    }
    
    func deleteCustomers(_ customers: [Customer]) async throws {
        for customer in customers {
            let endpoint = "\(baseEndpoint)/\(customer.id)"
            let response = try await cloudProvider.delete(endpoint: endpoint)
            
            if !response.success {
                throw RepositoryError.deleteFailed(response.error ?? "Delete customer failed")
            }
        }
    }
}

// MARK: - Cloud Product Repository

final class CloudProductRepository: ProductRepository, Sendable {
    private let cloudProvider: CloudProvider
    private let baseEndpoint = "/api/products"
    
    init(cloudProvider: CloudProvider) {
        self.cloudProvider = cloudProvider
    }
    
    func fetchProducts() async throws -> [Product] {
        let response = try await cloudProvider.getPaginated(endpoint: baseEndpoint, type: ProductDTO.self, page: 0, pageSize: 1000)
        
        guard response.success else {
            throw RepositoryError.connectionFailed(response.error ?? "Fetch products failed")
        }
        
        return response.items.map { $0.toDomain() }
    }
    
    func addProduct(_ product: Product) async throws {
        let dto = ProductDTO(from: product)
        let response = try await cloudProvider.post(endpoint: baseEndpoint, body: dto, responseType: ProductDTO.self)
        
        guard response.success else {
            throw RepositoryError.saveFailed(response.error ?? "Add product failed")
        }
    }
    
    func updateProduct(_ product: Product) async throws {
        let dto = ProductDTO(from: product)
        let endpoint = "\(baseEndpoint)/\(product.id)"
        let response = try await cloudProvider.put(endpoint: endpoint, body: dto, responseType: ProductDTO.self)
        
        guard response.success else {
            throw RepositoryError.saveFailed(response.error ?? "Update product failed")
        }
    }
    
    func deleteProduct(_ product: Product) async throws {
        let endpoint = "\(baseEndpoint)/\(product.id)"
        let response = try await cloudProvider.delete(endpoint: endpoint)
        
        guard response.success else {
            throw RepositoryError.deleteFailed(response.error ?? "Delete product failed")
        }
    }
    
    func fetchProduct(by id: String) async throws -> Product? {
        let endpoint = "\(baseEndpoint)/\(id)"
        let response = try await cloudProvider.get(endpoint: endpoint, type: ProductDTO.self)
        
        guard response.success, let dto = response.data else {
            return nil
        }
        
        return dto.toDomain()
    }
    
    func fetchProductsWithSizes() async throws -> [Product] {
        let endpoint = "\(baseEndpoint)/with-sizes"
        let response = try await cloudProvider.getPaginated(endpoint: endpoint, type: ProductDTO.self, page: 0, pageSize: 1000)
        
        guard response.success else {
            throw RepositoryError.connectionFailed(response.error ?? "Fetch products with sizes failed")
        }
        
        return response.items.map { $0.toDomain() }
    }
    
    func searchProducts(query: String) async throws -> [Product] {
        let encodedSearch = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let endpoint = "\(baseEndpoint)/search?q=\(encodedSearch)"
        let response = try await cloudProvider.getPaginated(endpoint: endpoint, type: ProductDTO.self, page: 0, pageSize: 1000)
        
        guard response.success else {
            throw RepositoryError.connectionFailed(response.error ?? "Search products failed")
        }
        
        return response.items.map { $0.toDomain() }
    }
    
    func deleteProducts(_ products: [Product]) async throws {
        for product in products {
            let endpoint = "\(baseEndpoint)/\(product.id)"
            let response = try await cloudProvider.delete(endpoint: endpoint)
            
            if !response.success {
                throw RepositoryError.deleteFailed(response.error ?? "Delete product failed")
            }
        }
    }
}

// MARK: - Stub Repositories (minimal implementations)

final class CloudPackagingRepository: PackagingRepository, Sendable {
    private let cloudProvider: CloudProvider
    
    init(cloudProvider: CloudProvider) {
        self.cloudProvider = cloudProvider
    }
    
    func fetchPackagingRecords() async throws -> [PackagingRecord] {
        // Stub implementation
        return []
    }
    
    func addPackagingRecord(_ record: PackagingRecord) async throws {
        // Stub implementation
    }
    
    func updatePackagingRecord(_ record: PackagingRecord) async throws {
        // Stub implementation
    }
    
    func deletePackagingRecord(_ record: PackagingRecord) async throws {
        // Stub implementation
    }
    
    func fetchPackagingRecord(by id: String) async throws -> PackagingRecord? {
        return nil
    }
    
    func fetchPackagingRecords(for teamId: String) async throws -> [PackagingRecord] {
        return []
    }
    
    func fetchPackagingRecords(for date: Date) async throws -> [PackagingRecord] {
        return []
    }
    
    func fetchPackagingTeams() async throws -> [PackagingTeam] {
        return []
    }
    
    func fetchPackagingTeam(by id: String) async throws -> PackagingTeam? {
        return nil
    }
    
    func addPackagingTeam(_ team: PackagingTeam) async throws {
        // Stub implementation
    }
    
    func updatePackagingTeam(_ team: PackagingTeam) async throws {
        // Stub implementation
    }
    
    func deletePackagingTeam(_ team: PackagingTeam) async throws {
        // Stub implementation
    }
}

final class CloudProductionRepository: ProductionRepository, Sendable {
    private let cloudProvider: CloudProvider
    
    init(cloudProvider: CloudProvider) {
        self.cloudProvider = cloudProvider
    }
    
    // ProductionStyle operations
    func fetchProductionStyles() async throws -> [ProductionStyle] {
        return []
    }
    
    func fetchProductionStyle(by id: String) async throws -> ProductionStyle? {
        return nil
    }
    
    func fetchProductionStyles(by status: StyleStatus) async throws -> [ProductionStyle] {
        return []
    }
    
    func addProductionStyle(_ style: ProductionStyle) async throws {
        // Stub implementation
    }
    
    func updateProductionStyle(_ style: ProductionStyle) async throws {
        // Stub implementation
    }
    
    func deleteProductionStyle(_ style: ProductionStyle) async throws {
        // Stub implementation
    }
    
    // WorkshopProduction operations
    func fetchWorkshopProductions() async throws -> [WorkshopProduction] {
        return []
    }
    
    func fetchWorkshopProduction(by id: String) async throws -> WorkshopProduction? {
        return nil
    }
    
    func addWorkshopProduction(_ production: WorkshopProduction) async throws {
        // Stub implementation
    }
    
    func updateWorkshopProduction(_ production: WorkshopProduction) async throws {
        // Stub implementation
    }
    
    func deleteWorkshopProduction(_ production: WorkshopProduction) async throws {
        // Stub implementation
    }
    
    // EVAGranulation operations
    func fetchEVAGranulations() async throws -> [EVAGranulation] {
        return []
    }
    
    func fetchEVAGranulation(by id: String) async throws -> EVAGranulation? {
        return nil
    }
    
    func addEVAGranulation(_ granulation: EVAGranulation) async throws {
        // Stub implementation
    }
    
    func updateEVAGranulation(_ granulation: EVAGranulation) async throws {
        // Stub implementation
    }
    
    func deleteEVAGranulation(_ granulation: EVAGranulation) async throws {
        // Stub implementation
    }
    
    // WorkshopIssue operations
    func fetchWorkshopIssues() async throws -> [WorkshopIssue] {
        return []
    }
    
    func fetchWorkshopIssue(by id: String) async throws -> WorkshopIssue? {
        return nil
    }
    
    func addWorkshopIssue(_ issue: WorkshopIssue) async throws {
        // Stub implementation
    }
    
    func updateWorkshopIssue(_ issue: WorkshopIssue) async throws {
        // Stub implementation
    }
    
    func deleteWorkshopIssue(_ issue: WorkshopIssue) async throws {
        // Stub implementation
    }
}

final class CloudAuditRepository: AuditRepository, Sendable {
    private let cloudProvider: CloudProvider
    
    init(cloudProvider: CloudProvider) {
        self.cloudProvider = cloudProvider
    }
    
    func saveAuditLog(_ log: AuditLog) async throws {
        // Stub implementation
    }
    
    func fetchAuditLog(by id: String) async throws -> AuditLog? {
        // Stub implementation
        return nil
    }
    
    func fetchAuditLogs() async throws -> [AuditLog] {
        // Stub implementation
        return []
    }
    
    func fetchAuditLogs(forEntity entityId: String) async throws -> [AuditLog] {
        // Stub implementation
        return []
    }
    
    func fetchAuditLogs(forUser userId: String) async throws -> [AuditLog] {
        // Stub implementation
        return []
    }
    
    func fetchAuditLogs(forAction action: String) async throws -> [AuditLog] {
        // Stub implementation
        return []
    }
    
    func fetchAuditLogs(from startDate: Date, to endDate: Date) async throws -> [AuditLog] {
        // Stub implementation
        return []
    }
    
    func addAuditLog(_ log: AuditLog) async throws {
        // Stub implementation
    }
    
    func deleteAuditLog(_ log: AuditLog) async throws {
        // Stub implementation
    }
    
    func deleteAuditLogs(olderThan date: Date) async throws {
        // Stub implementation
    }
}

final class CloudMachineRepository: MachineRepository, Sendable {
    private let cloudProvider: CloudProvider
    
    init(cloudProvider: CloudProvider) {
        self.cloudProvider = cloudProvider
    }
    
    func fetchAllMachines() async throws -> [WorkshopMachine] {
        // Stub implementation
        return []
    }
    
    func fetchMachine(byId id: String) async throws -> WorkshopMachine? {
        // Stub implementation
        return nil
    }
    
    func saveMachine(_ machine: WorkshopMachine) async throws {
        // Stub implementation
    }
    
    func updateMachine(_ machine: WorkshopMachine) async throws {
        // Stub implementation
    }
    
    func deleteMachine(_ machine: WorkshopMachine) async throws {
        // Stub implementation
    }
    
    func fetchMachines(byStatus status: MachineStatus) async throws -> [WorkshopMachine] {
        // Stub implementation
        return []
    }
    
    func fetchAvailableMachines() async throws -> [WorkshopMachine] {
        // Stub implementation
        return []
    }
    
    func fetchMachineById(_ id: String) async throws -> WorkshopMachine? {
        return nil
    }
    
    func fetchMachine(byNumber number: Int) async throws -> WorkshopMachine? {
        return nil
    }
    
    func fetchActiveMachines() async throws -> [WorkshopMachine] {
        return []
    }
    
    func fetchMachinesWithStatus(_ status: MachineStatus) async throws -> [WorkshopMachine] {
        return []
    }
    
    func addMachine(_ machine: WorkshopMachine) async throws {
        // Stub implementation
    }
    
    // Station Operations
    func fetchStations(for machineId: String) async throws -> [WorkshopStation] {
        return []
    }
    
    func updateStation(_ station: WorkshopStation) async throws {
        // Stub implementation
    }
    
    // Gun Operations
    func fetchGuns(for machineId: String) async throws -> [WorkshopGun] {
        return []
    }
    
    func updateGun(_ gun: WorkshopGun) async throws {
        // Stub implementation
    }
    
    // Batch-aware Machine Queries
    func fetchMachinesWithoutPendingApprovalBatches() async throws -> [WorkshopMachine] {
        return []
    }
}

final class CloudColorRepository: ColorRepository, Sendable {
    private let cloudProvider: CloudProvider
    
    init(cloudProvider: CloudProvider) {
        self.cloudProvider = cloudProvider
    }
    
    func fetchAllColors() async throws -> [ColorCard] {
        // Stub implementation
        return []
    }
    
    func fetchColor(byId id: String) async throws -> ColorCard? {
        // Stub implementation
        return nil
    }
    
    func saveColor(_ color: ColorCard) async throws {
        // Stub implementation
    }
    
    func updateColor(_ color: ColorCard) async throws {
        // Stub implementation
    }
    
    func deleteColor(_ color: ColorCard) async throws {
        // Stub implementation
    }
    
    func fetchColors(byName name: String) async throws -> [ColorCard] {
        // Stub implementation
        return []
    }
    
    func fetchActiveColors() async throws -> [ColorCard] {
        return []
    }
    
    func fetchColorById(_ id: String) async throws -> ColorCard? {
        return nil
    }
    
    func addColor(_ color: ColorCard) async throws {
        // Stub implementation
    }
    
    func deactivateColor(_ color: ColorCard) async throws {
        // Stub implementation
    }
    
    func searchColors(by name: String) async throws -> [ColorCard] {
        return []
    }
}

final class CloudProductionBatchRepository: ProductionBatchRepository, Sendable {
    private let cloudProvider: CloudProvider
    
    init(cloudProvider: CloudProvider) {
        self.cloudProvider = cloudProvider
    }
    
    func fetchAllBatches() async throws -> [ProductionBatch] {
        // Stub implementation
        return []
    }
    
    func fetchBatch(byId id: String) async throws -> ProductionBatch? {
        // Stub implementation
        return nil
    }
    
    func fetchBatchById(_ id: String) async throws -> ProductionBatch? {
        // Stub implementation - same as fetchBatch(byId:)
        return try await fetchBatch(byId: id)
    }
    
    func saveBatch(_ batch: ProductionBatch) async throws {
        // Stub implementation
    }
    
    func updateBatch(_ batch: ProductionBatch) async throws {
        // Stub implementation
    }
    
    func deleteBatch(_ batch: ProductionBatch) async throws {
        // Stub implementation
    }
    
    func addBatch(_ batch: ProductionBatch) async throws {
        // Stub implementation
    }
    
    func deleteBatch(id: String) async throws {
        // Stub implementation
    }
    
    func fetchBatchesByStatus(_ status: BatchStatus) async throws -> [ProductionBatch] {
        // Stub implementation
        return []
    }
    
    func fetchBatchesByMachine(_ machineId: String) async throws -> [ProductionBatch] {
        // Stub implementation
        return []
    }
    
    func fetchActiveBatches() async throws -> [ProductionBatch] {
        // Stub implementation
        return []
    }
    
    func fetchPendingBatches() async throws -> [ProductionBatch] {
        // Stub implementation
        return []
    }
    
    func fetchBatchHistory(limit: Int?) async throws -> [ProductionBatch] {
        // Stub implementation
        return []
    }
    
    // Product Config operations
    func addProductConfig(_ productConfig: ProductConfig, toBatch batchId: String) async throws {
        // Stub implementation
    }
    
    func updateProductConfig(_ productConfig: ProductConfig) async throws {
        // Stub implementation
    }
    
    func removeProductConfig(_ productConfig: ProductConfig) async throws {
        // Stub implementation
    }
    
    func fetchProductConfigs(forBatch batchId: String) async throws -> [ProductConfig] {
        // Stub implementation
        return []
    }
    
    // Batch number generation support
    func fetchLatestBatchNumber(forDate dateString: String, batchType: BatchType) async throws -> String? {
        // Stub implementation
        return nil
    }
    
    // MARK: - Shift-aware Batch Operations
    func fetchBatches(forDate date: Date, shift: Shift) async throws -> [ProductionBatch] {
        // Stub implementation
        return []
    }
    
    func fetchBatches(forDate date: Date) async throws -> [ProductionBatch] {
        // Stub implementation
        return []
    }
    
    func fetchShiftAwareBatches() async throws -> [ProductionBatch] {
        // Stub implementation
        return []
    }
    
    func fetchBatches(from startDate: Date, to endDate: Date, shift: Shift?) async throws -> [ProductionBatch] {
        // Stub implementation
        return []
    }
    
    func hasConflictingBatches(forDate date: Date, shift: Shift, machineId: String, excludingBatchId: String?) async throws -> Bool {
        // Stub implementation
        return false
    }
    
    func fetchBatchesRequiringMigration() async throws -> [ProductionBatch] {
        // Stub implementation
        return []
    }
    
    // MARK: - Optimized Query Methods
    func fetchActiveBatchForMachine(_ machineId: String) async throws -> ProductionBatch? {
        // Stub implementation
        return nil
    }
    
    func fetchLatestBatchForMachineAndShift(machineId: String, date: Date, shift: Shift) async throws -> ProductionBatch? {
        // Stub implementation
        return nil
    }
    
    func fetchActiveBatchesWithStatus(_ statuses: [BatchStatus]) async throws -> [ProductionBatch] {
        // Stub implementation
        return []
    }
    
    func fetchBatchesForMachine(_ machineId: String, statuses: [BatchStatus], from startDate: Date?, to endDate: Date?) async throws -> [ProductionBatch] {
        // Stub implementation
        return []
    }
}