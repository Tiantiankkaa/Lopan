# CLAUDE-EXAMPLES.md — Code Templates & Implementation Examples

> **Companion Document to CLAUDE.md**  
> Focus: Practical implementation examples, templates, and patterns for iOS development

---

## Table of Contents

1. [Repository Patterns](#1-repository-patterns)
2. [Service Layer Templates](#2-service-layer-templates)
3. [Security & Authorization Examples](#3-security--authorization-examples)
4. [Networking & Background Tasks](#4-networking--background-tasks)
5. [Testing Templates](#5-testing-templates)
6. [CI/CD Configuration](#6-cicd-configuration)
7. [Task Pack Templates](#7-task-pack-templates)

---

## 1. Repository Patterns

### 1.1 Repository Local/Cloud Skeletons

**Local Repository Implementation:**
```swift
public final class LocalUserRepository: UserRepository {
    public init() {}
    public func fetch() async throws -> [User] { /* SwiftData read */ [] }
    public func create(_ user: User) async throws { /* SwiftData write */ }
    public func update(_ user: User) async throws { }
    public func remove(id: User.ID) async throws { }
}
```

**Cloud Repository Implementation:**
```swift
public final class CloudUserRepository: UserRepository {
    let http = HTTPClient()
    public func fetch() async throws -> [User] {
        try await withRetry { try await http.get(URL(string: "https://api.lopan/users")!) }
    }
    public func create(_ user: User) async throws { /* call cloud API */ }
    public func update(_ user: User) async throws { /* call cloud API */ }
    public func remove(id: User.ID) async throws { /* call cloud API */ }
}
```

### 1.2 Repository Protocol Template

**Generic Repository Protocol:**
```swift
public protocol Repository {
    associatedtype Entity: Identifiable, Codable
    
    func fetch() async throws -> [Entity]
    func fetch(by id: Entity.ID) async throws -> Entity?
    func create(_ entity: Entity) async throws -> Entity
    func update(_ entity: Entity) async throws -> Entity
    func remove(id: Entity.ID) async throws
}
```

### 1.3 Mock Repository Implementation

**Safe Mock Pattern:**
```swift
public final class MockUserRepository: UserRepository {
    private var users: [User] = [
        User(wechatId: "test_wx", name: "Test User", phone: "1234567890")
    ]
    
    public init() {}
    
    public func fetch() async throws -> [User] {
        try? await Task.sleep(nanoseconds: 100_000_000) // Simulate network delay
        return users
    }
    
    public func create(_ user: User) async throws {
        users.append(user)
    }
    
    public func update(_ user: User) async throws {
        if let index = users.firstIndex(where: { $0.id == user.id }) {
            users[index] = user
        }
    }
    
    public func remove(id: User.ID) async throws {
        users.removeAll { $0.id == id }
    }
}
```

---

## 2. Service Layer Templates

### 2.1 Business Service Template

**Service Orchestration Pattern:**
```swift
@MainActor
public final class UserManagementService: ObservableObject {
    private let repository: UserRepository
    private let auditService: AuditService
    private let authService: AuthorizationService
    
    @Published public var users: [User] = []
    @Published public var isLoading = false
    
    public init(repository: UserRepository, 
                auditService: AuditService,
                authService: AuthorizationService) {
        self.repository = repository
        self.auditService = auditService
        self.authService = authService
    }
    
    public func loadUsers() async {
        guard authService.canPerform(.readUsers) else { return }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            let fetchedUsers = try await repository.fetch()
            await MainActor.run {
                self.users = fetchedUsers
            }
            
            await auditService.log(.dataAccess, target: "users", context: "list_view")
        } catch {
            // Handle error appropriately
        }
    }
    
    public func createUser(_ user: User) async throws {
        guard authService.canPerform(.createUser) else {
            throw AuthorizationError.insufficientPermissions
        }
        
        try await repository.create(user)
        await auditService.log(.dataWrite, target: "users", context: "user_created")
        await loadUsers() // Refresh list
    }
}
```

### 2.2 Coordinator Pattern

**Navigation Coordinator:**
```swift
@MainActor
public final class UserCoordinator: ObservableObject {
    @Published public var navigationPath = NavigationPath()
    @Published public var selectedUser: User?
    
    private let userService: UserManagementService
    
    public init(userService: UserManagementService) {
        self.userService = userService
    }
    
    public func navigateToUserDetail(_ user: User) {
        selectedUser = user
        navigationPath.append(UserDetailDestination.detail(user))
    }
    
    public func navigateBack() {
        navigationPath.removeLast()
    }
    
    public func resetNavigation() {
        navigationPath.removeLast(navigationPath.count)
    }
}
```

---

## 3. Security & Authorization Examples

### 3.1 Authorization Service

**Role-Based Authorization:**
```swift
enum Role { case admin, salesperson, keeper, manager }
enum Action { case createOrder, adjustInventory, planBatch, exportData }

struct AuthorizationService {
    private let currentUserRole: Role
    
    init(currentUserRole: Role) {
        self.currentUserRole = currentUserRole
    }
    
    func authorize(_ action: Action, for role: Role) -> Bool {
        switch (role, action) {
        case (.admin, _): return true
        case (.salesperson, .createOrder), (.salesperson, .exportData): return true
        case (.keeper, .adjustInventory): return true
        case (.manager, .planBatch): return true
        default: return false
        }
    }
    
    func canPerform(_ action: Action) -> Bool {
        return authorize(action, for: currentUserRole)
    }
}
```

### 3.2 Secure Keychain Wrapper

**Enhanced Keychain Implementation:**
```swift
import Security

enum SecureKeychain {
    enum KeychainError: Error {
        case saveFailed(OSStatus)
        case loadFailed(OSStatus)
        case deleteFailed(OSStatus)
        case encodingFailed
    }
    
    static func save<T: Codable>(_ value: T, forKey key: String, service: String = "com.lopan.app") throws {
        guard let data = try? JSONEncoder().encode(value) else {
            throw KeychainError.encodingFailed
        }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        
        // Delete existing item
        SecItemDelete(query as CFDictionary)
        
        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }
    
    static func load<T: Codable>(_ type: T.Type, forKey key: String, service: String = "com.lopan.app") throws -> T? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let value = try? JSONDecoder().decode(type, from: data) else {
            if status == errSecItemNotFound {
                return nil
            }
            throw KeychainError.loadFailed(status)
        }
        
        return value
    }
}
```

### 3.3 Audit Event Model

**Comprehensive Audit Logging:**
```swift
struct AuditEvent: Codable, Identifiable {
    enum Kind: String, Codable {
        case login, logout, dataAccess, dataWrite, dataExport
        case configChange, permissionChange, systemEvent
    }
    
    let id: UUID
    let kind: Kind
    let actorId: String
    let actorRole: String
    let occurredAt: Date
    let target: String
    let redactedContext: String
    let ipAddress: String?
    let userAgent: String?
    
    init(kind: Kind, 
         actorId: String, 
         actorRole: String, 
         target: String, 
         context: String,
         ipAddress: String? = nil,
         userAgent: String? = nil) {
        self.id = UUID()
        self.kind = kind
        self.actorId = actorId
        self.actorRole = actorRole
        self.occurredAt = Date()
        self.target = target
        self.redactedContext = Self.redactSensitiveData(context)
        self.ipAddress = ipAddress
        self.userAgent = userAgent
    }
    
    private static func redactSensitiveData(_ input: String) -> String {
        return input
            .replacingOccurrences(of: #"\b\d{4}[\s-]?\d{4}[\s-]?\d{4}[\s-]?\d{4}\b"#, with: "[CARD]", options: .regularExpression)
            .replacingOccurrences(of: #"\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b"#, with: "[EMAIL]", options: .regularExpression)
            .replacingOccurrences(of: #"\b\d{3}[\s-]?\d{3}[\s-]?\d{4}\b"#, with: "[PHONE]", options: .regularExpression)
    }
}

@MainActor
public final class AuditService: ObservableObject {
    private let repository: AuditRepository
    
    public init(repository: AuditRepository) {
        self.repository = repository
    }
    
    public func log(_ kind: AuditEvent.Kind, 
                   target: String, 
                   context: String,
                   actorId: String = "current_user",
                   actorRole: String = "unknown") async {
        let event = AuditEvent(
            kind: kind,
            actorId: actorId,
            actorRole: actorRole,
            target: target,
            context: context
        )
        
        do {
            try await repository.create(event)
        } catch {
            // Log audit failure to system logs
            print("⚠️ Audit logging failed: \(error)")
        }
    }
}
```

---

## 4. Networking & Background Tasks

### 4.1 HTTP Client with Retry Logic

**Production-Ready HTTP Client:**
```swift
public enum HTTPError: Error {
    case invalidURL
    case noData
    case statusCode(Int)
    case decodingError(Error)
    case networkError(Error)
    case timeout
}

public struct HTTPClient {
    private let session: URLSession
    private let baseURL: URL
    
    public init(baseURL: URL, timeout: TimeInterval = 30) {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = timeout
        config.timeoutIntervalForResource = timeout * 2
        self.session = URLSession(configuration: config)
        self.baseURL = baseURL
    }
    
    public func get<T: Decodable>(_ path: String, type: T.Type) async throws -> T {
        guard let url = URL(string: path, relativeTo: baseURL) else {
            throw HTTPError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        return try await performRequest(request, type: type)
    }
    
    public func post<T: Codable, U: Decodable>(_ path: String, body: T, responseType: U.Type) async throws -> U {
        guard let url = URL(string: path, relativeTo: baseURL) else {
            throw HTTPError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        do {
            request.httpBody = try JSONEncoder().encode(body)
        } catch {
            throw HTTPError.decodingError(error)
        }
        
        return try await performRequest(request, type: responseType)
    }
    
    private func performRequest<T: Decodable>(_ request: URLRequest, type: T.Type) async throws -> T {
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw HTTPError.networkError(NSError(domain: "InvalidResponse", code: -1))
            }
            
            guard 200...299 ~= httpResponse.statusCode else {
                throw HTTPError.statusCode(httpResponse.statusCode)
            }
            
            do {
                return try JSONDecoder().decode(type, from: data)
            } catch {
                throw HTTPError.decodingError(error)
            }
            
        } catch {
            if let urlError = error as? URLError {
                if urlError.code == .timedOut {
                    throw HTTPError.timeout
                }
            }
            throw HTTPError.networkError(error)
        }
    }
}
```

### 4.2 Exponential Backoff Retry Logic

**Jittered Exponential Backoff:**
```swift
func withRetry<T>(
    maxAttempts: Int = 3,
    baseDelay: TimeInterval = 1.0,
    maxDelay: TimeInterval = 32.0,
    operation: @escaping () async throws -> T
) async throws -> T {
    var attempt = 0
    var lastError: Error?
    
    while attempt < maxAttempts {
        do {
            return try await operation()
        } catch {
            lastError = error
            attempt += 1
            
            // Don't retry on certain errors
            if let httpError = error as? HTTPError {
                switch httpError {
                case .statusCode(let code) where 400...499 ~= code:
                    // Client errors - don't retry
                    throw error
                default:
                    break
                }
            }
            
            if attempt >= maxAttempts {
                break
            }
            
            // Calculate delay with jitter
            let exponentialDelay = min(baseDelay * pow(2.0, Double(attempt - 1)), maxDelay)
            let jitter = Double.random(in: 0...0.1) * exponentialDelay
            let totalDelay = exponentialDelay + jitter
            
            try await Task.sleep(nanoseconds: UInt64(totalDelay * 1_000_000_000))
        }
    }
    
    throw lastError ?? HTTPError.networkError(NSError(domain: "RetryFailed", code: -1))
}
```

### 4.3 Background Task Scheduling

**BGTaskScheduler Integration:**
```swift
import BackgroundTasks

public final class BackgroundTaskManager {
    public static let shared = BackgroundTaskManager()
    
    private let backgroundRefreshIdentifier = "com.lopan.background-refresh"
    private let backgroundProcessingIdentifier = "com.lopan.background-processing"
    
    private init() {}
    
    public func registerBackgroundTasks() {
        // Register background refresh
        BGTaskScheduler.shared.register(forTaskWithIdentifier: backgroundRefreshIdentifier, using: nil) { task in
            self.handleBackgroundRefresh(task as! BGAppRefreshTask)
        }
        
        // Register background processing
        BGTaskScheduler.shared.register(forTaskWithIdentifier: backgroundProcessingIdentifier, using: nil) { task in
            self.handleBackgroundProcessing(task as! BGProcessingTask)
        }
    }
    
    public func scheduleBackgroundRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: backgroundRefreshIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15 minutes
        
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("Failed to schedule background refresh: \(error)")
        }
    }
    
    private func handleBackgroundRefresh(_ task: BGAppRefreshTask) {
        let operation = Task {
            defer { task.setTaskCompleted(success: true) }
            
            // Perform lightweight refresh operations
            await performQuickDataSync()
        }
        
        task.expirationHandler = {
            operation.cancel()
            task.setTaskCompleted(success: false)
        }
    }
    
    private func handleBackgroundProcessing(_ task: BGProcessingTask) {
        let operation = Task {
            defer { task.setTaskCompleted(success: true) }
            
            // Perform heavy processing operations
            await performHeavyProcessing()
        }
        
        task.expirationHandler = {
            operation.cancel()
            task.setTaskCompleted(success: false)
        }
    }
    
    private func performQuickDataSync() async {
        // Implement quick data synchronization
        print("Performing background refresh...")
    }
    
    private func performHeavyProcessing() async {
        // Implement heavy background processing
        print("Performing background processing...")
    }
}
```

---

## 5. Testing Templates

### 5.1 Repository Test Template

**Comprehensive Repository Testing:**
```swift
import XCTest
@testable import Lopan

final class UserRepositoryTests: XCTestCase {
    var repository: UserRepository!
    var mockUsers: [User]!
    
    override func setUp() {
        super.setUp()
        repository = MockUserRepository()
        mockUsers = [
            User(wechatId: "test1", name: "Test User 1", phone: "1111111111"),
            User(wechatId: "test2", name: "Test User 2", phone: "2222222222")
        ]
    }
    
    override func tearDown() {
        repository = nil
        mockUsers = nil
        super.tearDown()
    }
    
    func testFetchUsers() async throws {
        // When
        let users = try await repository.fetch()
        
        // Then
        XCTAssertFalse(users.isEmpty)
        XCTAssertTrue(users.allSatisfy { !$0.name.isEmpty })
    }
    
    func testCreateUser() async throws {
        // Given
        let newUser = mockUsers[0]
        
        // When
        try await repository.create(newUser)
        let users = try await repository.fetch()
        
        // Then
        XCTAssertTrue(users.contains { $0.wechatId == newUser.wechatId })
    }
    
    func testUpdateUser() async throws {
        // Given
        let originalUser = mockUsers[0]
        try await repository.create(originalUser)
        
        var updatedUser = originalUser
        updatedUser.name = "Updated Name"
        
        // When
        try await repository.update(updatedUser)
        let users = try await repository.fetch()
        
        // Then
        let fetchedUser = users.first { $0.id == updatedUser.id }
        XCTAssertEqual(fetchedUser?.name, "Updated Name")
    }
    
    func testConcurrentOperations() async throws {
        // Given
        let users = mockUsers!
        
        // When - Perform concurrent creates
        await withTaskGroup(of: Void.self) { group in
            for user in users {
                group.addTask {
                    try? await self.repository.create(user)
                }
            }
        }
        
        // Then
        let fetchedUsers = try await repository.fetch()
        XCTAssertGreaterThanOrEqual(fetchedUsers.count, users.count)
    }
}
```

### 5.2 Service Layer Test Template

**Service Testing with Mocks:**
```swift
import XCTest
@testable import Lopan

@MainActor
final class UserManagementServiceTests: XCTestCase {
    var service: UserManagementService!
    var mockRepository: MockUserRepository!
    var mockAuditService: MockAuditService!
    var mockAuthService: MockAuthorizationService!
    
    override func setUp() {
        super.setUp()
        mockRepository = MockUserRepository()
        mockAuditService = MockAuditService()
        mockAuthService = MockAuthorizationService()
        
        service = UserManagementService(
            repository: mockRepository,
            auditService: mockAuditService,
            authService: mockAuthService
        )
    }
    
    func testLoadUsersWithPermission() async {
        // Given
        mockAuthService.shouldAuthorize = true
        
        // When
        await service.loadUsers()
        
        // Then
        XCTAssertFalse(service.users.isEmpty)
        XCTAssertFalse(service.isLoading)
        XCTAssertTrue(mockAuditService.loggedEvents.contains { $0.kind == .dataAccess })
    }
    
    func testLoadUsersWithoutPermission() async {
        // Given
        mockAuthService.shouldAuthorize = false
        
        // When
        await service.loadUsers()
        
        // Then
        XCTAssertTrue(service.users.isEmpty)
        XCTAssertFalse(mockAuditService.loggedEvents.contains { $0.kind == .dataAccess })
    }
    
    func testCreateUserSuccess() async throws {
        // Given
        mockAuthService.shouldAuthorize = true
        let newUser = User(wechatId: "new_user", name: "New User", phone: "9999999999")
        
        // When
        try await service.createUser(newUser)
        
        // Then
        XCTAssertTrue(mockAuditService.loggedEvents.contains { $0.kind == .dataWrite })
        XCTAssertFalse(service.users.isEmpty)
    }
}
```

### 5.3 UI Test Template

**SwiftUI View Testing:**
```swift
import XCTest
@testable import Lopan

final class UserListViewUITests: XCTestCase {
    var app: XCUIApplication!
    
    override func setUp() {
        super.setUp()
        app = XCUIApplication()
        app.launchArguments.append("--uitesting")
        app.launch()
    }
    
    func testUserListDisplaysUsers() {
        // Navigate to user list
        app.tabBars.buttons["Users"].tap()
        
        // Verify users are displayed
        XCTAssertTrue(app.navigationBars["Users"].exists)
        XCTAssertTrue(app.tables.cells.count > 0)
    }
    
    func testCreateNewUser() {
        // Navigate to user list
        app.tabBars.buttons["Users"].tap()
        
        // Tap add button
        app.navigationBars.buttons["Add"].tap()
        
        // Fill user form
        app.textFields["Name"].tap()
        app.textFields["Name"].typeText("Test User")
        
        app.textFields["Phone"].tap()
        app.textFields["Phone"].typeText("1234567890")
        
        // Save user
        app.navigationBars.buttons["Save"].tap()
        
        // Verify user was added
        XCTAssertTrue(app.tables.cells.containing(.staticText, identifier: "Test User").exists)
    }
    
    func testAccessibilitySupport() {
        app.tabBars.buttons["Users"].tap()
        
        // Verify accessibility elements exist
        XCTAssertTrue(app.tables.firstMatch.isAccessibilityElement)
        XCTAssertNotNil(app.tables.firstMatch.accessibilityLabel)
    }
}
```

---

## 6. CI/CD Configuration

### 6.1 GitHub Actions Workflow

**Complete iOS CI Pipeline:**
```yaml
name: iOS CI

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

jobs:
  test:
    runs-on: macos-latest
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Setup Xcode
      uses: maxim-lobanov/setup-xcode@v1
      with:
        xcode-version: latest-stable
        
    - name: Cache SPM
      uses: actions/cache@v3
      with:
        path: .build
        key: ${{ runner.os }}-spm-${{ hashFiles('**/Package.resolved') }}
        restore-keys: |
          ${{ runner.os }}-spm-
          
    - name: Install dependencies
      run: xcodebuild -resolvePackageDependencies
      
    - name: Run SwiftLint
      run: swiftlint lint --reporter github-actions-logging
      
    - name: Run tests
      run: |
        xcodebuild test \
          -project Lopan.xcodeproj \
          -scheme Lopan \
          -destination 'platform=iOS Simulator,name=iPhone 15,OS=17.0' \
          -enableCodeCoverage YES \
          -resultBundlePath TestResults.xcresult
          
    - name: Upload test results
      uses: actions/upload-artifact@v3
      if: always()
      with:
        name: test-results
        path: TestResults.xcresult
        
    - name: Code Coverage Report
      run: |
        xcrun xccov view --report --json TestResults.xcresult > coverage.json
        echo "Code coverage: $(xcrun xccov view --report TestResults.xcresult | grep "Overall coverage" | awk '{print $3}')"
        
    - name: Security Scan
      run: |
        # Check for hardcoded secrets
        if grep -r "API_KEY\|SECRET\|PASSWORD" --exclude-dir=.git --exclude="*.md" .; then
          echo "⚠️  Potential secrets found"
          exit 1
        fi
        
    - name: Privacy Manifest Check
      run: |
        if [ ! -f "Lopan/PrivacyInfo.xcprivacy" ]; then
          echo "❌ Privacy manifest missing"
          exit 1
        fi
        
  build:
    runs-on: macos-latest
    needs: test
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Setup Xcode
      uses: maxim-lobanov/setup-xcode@v1
      with:
        xcode-version: latest-stable
        
    - name: Build for Release
      run: |
        xcodebuild build \
          -project Lopan.xcodeproj \
          -scheme Lopan \
          -configuration Release \
          -destination 'generic/platform=iOS'
          
    - name: Archive
      if: github.ref == 'refs/heads/main'
      run: |
        xcodebuild archive \
          -project Lopan.xcodeproj \
          -scheme Lopan \
          -configuration Release \
          -archivePath Lopan.xcarchive \
          -destination 'generic/platform=iOS'
```

### 6.2 SwiftLint Configuration

**Production SwiftLint Rules:**
```yaml
# .swiftlint.yml
included:
  - Lopan
excluded:
  - Lopan/Generated
  - Tests/Generated
  - .build

analyzer_rules:
  - unused_declaration
  - unused_import

disabled_rules:
  - trailing_whitespace
  - todo

opt_in_rules:
  - array_init
  - closure_end_indentation
  - closure_spacing
  - collection_alignment
  - contains_over_filter_count
  - contains_over_filter_is_empty
  - empty_count
  - empty_string
  - explicit_init
  - file_name
  - first_where
  - force_unwrapping
  - implicitly_unwrapped_optional
  - last_where
  - let_var_whitespace
  - literal_expression_end_indentation
  - multiline_arguments
  - multiline_function_chains
  - multiline_literal_brackets
  - multiline_parameters
  - nimble_operator
  - operator_usage_whitespace
  - overridden_super_call
  - pattern_matching_keywords
  - prefer_self_type_over_type_of_self
  - redundant_nil_coalescing
  - redundant_type_annotation
  - strict_fileprivate
  - switch_case_alignment
  - toggle_bool
  - trailing_closure
  - unneeded_parentheses_in_closure_argument
  - vertical_parameter_alignment_on_call
  - vertical_whitespace_closing_braces
  - vertical_whitespace_opening_braces
  - yoda_condition

# Rule configurations
line_length:
  warning: 120
  error: 200

file_length:
  warning: 400
  error: 800

function_body_length:
  warning: 30
  error: 50

type_body_length:
  warning: 300
  error: 500

custom_rules:
  no_direct_swiftdata_import:
    name: "No Direct SwiftData Import in Views"
    regex: "^import SwiftData$"
    match_kinds:
      - keyword
    included: ".*/Views/.*\\.swift"
    message: "Views should not import SwiftData directly. Use Services instead."
    severity: error
    
  no_direct_urlsession_import:
    name: "No Direct URLSession in Views"
    regex: "URLSession"
    included: ".*/Views/.*\\.swift"
    message: "Views should not use URLSession directly. Use Repository pattern."
    severity: error
```

---

## 7. Task Pack Templates

### 7.1 Basic Task Pack Template

**Standard Claude Prompt Structure:**
```markdown
# Task
Module: <name> · Context: <business> · Goal: <measurable deliverable> · Constraints: <concurrency/security/perf> · References: <paths/APIs/PRs>

# Acceptance (DoD)
- [ ] Tests cover target scenarios; CI green; privacy/security checks passed; docs updated

# Output Format
- Minimal reviewable diff + affected files list
- Test cases and run instructions
- Risks & rollback plan

# Tests
- <unit/integration/UI cases>
```

### 7.2 Repository Implementation Task

**Repository-Specific Task Template:**
```markdown
# Task: Implement User Repository Pattern
Module: User Management · Context: Data layer abstraction · Goal: Create Local and Cloud UserRepository implementations · Constraints: Must support offline mode, <100ms P95 response · References: /Models/User.swift, /Repository/

# Acceptance (DoD)
- [ ] UserRepository protocol defined with CRUD operations
- [ ] LocalUserRepository implementation using SwiftData
- [ ] CloudUserRepository implementation with retry logic
- [ ] MockUserRepository for testing with realistic data
- [ ] Unit tests covering all repository methods
- [ ] Integration tests for repository switching
- [ ] Performance tests meeting P95 <100ms requirement
- [ ] Migration guide from direct SwiftData access

# Output Format
- Repository protocol definition
- Three implementations (Local, Cloud, Mock)
- Comprehensive test suite
- Performance benchmarks
- Migration documentation

# Tests
- Unit: CRUD operations, error handling, concurrent access
- Integration: Repository factory switching, data consistency
- Performance: Response time under load, memory usage
```

### 7.3 Service Layer Task Template

**Business Logic Implementation:**
```markdown
# Task: Implement Customer Out-of-Stock Service
Module: Customer Management · Context: Business logic orchestration · Goal: Create service managing OOS lifecycle · Constraints: Three states only (pending/completed/returned), audit all operations · References: /Models/CustomerOutOfStock.swift, /Services/

# Acceptance (DoD)
- [ ] CustomerOutOfStockService with state management
- [ ] Authorization checks for all operations
- [ ] Audit logging for all state changes
- [ ] Validation rules for state transitions
- [ ] Unit tests covering all business rules
- [ ] Integration tests with repository layer
- [ ] Error handling with appropriate user feedback
- [ ] Documentation of business rules and flows

# Output Format
- Service implementation with clear business methods
- State machine validation logic
- Comprehensive test coverage
- Business rule documentation
- Error scenarios and handling

# Tests
- Unit: State transitions, validation rules, authorization
- Integration: Service-repository interaction, audit logging
- Business: End-to-end workflows, edge cases
```

### 7.4 Performance Optimization Task

**System Performance Enhancement:**
```markdown
# Task: Implement Three-Tier Caching System
Module: Core Performance · Context: System-wide caching infrastructure · Goal: 50MB cache with <10ms hit times · Constraints: Memory budget 50MB total, automatic eviction, iOS memory pressure handling · References: /Core/Cache/, CLAUDE-PERFORMANCE.md

# Acceptance (DoD)
- [ ] SmartCacheManager with hot/warm/predictive tiers
- [ ] LRU eviction algorithm implementation
- [ ] Memory pressure integration with iOS system
- [ ] Cache hit rate >80% for frequent operations
- [ ] P95 response time <10ms for cache hits
- [ ] Background cache optimization with BGTaskScheduler
- [ ] Performance monitoring and metrics collection
- [ ] Cache warming strategies for predictive tier

# Output Format
- Core cache infrastructure
- Memory management integration
- Performance monitoring tools
- Background optimization system
- Comprehensive performance tests

# Tests
- Unit: Cache operations, eviction policies, memory management
- Performance: Hit rates, response times, memory usage
- Integration: System memory pressure, background tasks
- Load: High-concurrency access patterns
```

---

**Related Documents:**
- [CLAUDE.md](./CLAUDE.md) - Core architecture guidelines
- [CLAUDE-PERFORMANCE.md](./CLAUDE-PERFORMANCE.md) - Performance optimization standards
- [CustomerOutOfStockOptimization_Implementation.md](./CustomerOutOfStockOptimization_Implementation.md) - Specific implementation plan

---

*Document Version: 1.0*  
*Last Updated: 2025-08-31*  
*Companion to: CLAUDE.md*

---

## Table of Contents

1. [Repository Patterns](#1-repository-patterns)
2. [Service Layer Templates](#2-service-layer-templates)
3. [Security Implementation Examples](#3-security-implementation-examples)
4. [Testing Examples](#4-testing-examples)
5. [CI/CD Templates](#5-cicd-templates)
6. [Configuration Samples](#6-configuration-samples)

---

## 1. Repository Patterns

### 1.1 Basic Repository Implementation

**Local Repository (SwiftData):**
```swift
public final class LocalUserRepository: UserRepository {
    public init() {}
    
    public func fetch() async throws -> [User] { 
        // SwiftData read implementation
        return []
    }
    
    public func create(_ user: User) async throws { 
        // SwiftData write implementation
    }
    
    public func update(_ user: User) async throws { 
        // SwiftData update implementation
    }
    
    public func remove(id: User.ID) async throws { 
        // SwiftData delete implementation
    }
}
```

**Cloud Repository (Production):**
```swift
public final class CloudUserRepository: UserRepository {
    let http = HTTPClient()
    
    public func fetch() async throws -> [User] {
        try await withRetry { 
            try await http.get(URL(string: "https://api.lopan/users")!) 
        }
    }
    
    public func create(_ user: User) async throws { 
        try await withRetry {
            try await http.post(URL(string: "https://api.lopan/users")!, body: user)
        }
    }
    
    public func update(_ user: User) async throws { 
        try await withRetry {
            try await http.put(URL(string: "https://api.lopan/users/\(user.id)")!, body: user)
        }
    }
    
    public func remove(id: User.ID) async throws { 
        try await withRetry {
            try await http.delete(URL(string: "https://api.lopan/users/\(id)")!)
        }
    }
}
```

### 1.2 Repository Factory Pattern

**Protocol Definition:**
```swift
public protocol RepositoryFactory: Sendable {
    var userRepository: UserRepository { get }
    var customerRepository: CustomerRepository { get }
    var productRepository: ProductRepository { get }
    var auditRepository: AuditRepository { get }
}
```

**Local Implementation:**
```swift
public final class LocalRepositoryFactory: RepositoryFactory {
    public lazy var userRepository: UserRepository = LocalUserRepository()
    public lazy var customerRepository: CustomerRepository = LocalCustomerRepository()
    public lazy var productRepository: ProductRepository = LocalProductRepository()
    public lazy var auditRepository: AuditRepository = LocalAuditRepository()
    
    public init() {}
}
```

**Cloud Implementation:**
```swift
public final class CloudRepositoryFactory: RepositoryFactory {
    private let httpClient: HTTPClient
    
    public lazy var userRepository: UserRepository = CloudUserRepository(httpClient: httpClient)
    public lazy var customerRepository: CustomerRepository = CloudCustomerRepository(httpClient: httpClient)
    public lazy var productRepository: ProductRepository = CloudProductRepository(httpClient: httpClient)
    public lazy var auditRepository: AuditRepository = CloudAuditRepository(httpClient: httpClient)
    
    public init(httpClient: HTTPClient = HTTPClient()) {
        self.httpClient = httpClient
    }
}
```

---

## 2. Service Layer Templates

### 2.1 Base Service Implementation

**Generic Service Template:**
```swift
@MainActor
public class BaseService<Repository>: ObservableObject {
    protected let repository: Repository
    protected let logger = Logger.service
    
    public init(repository: Repository) {
        self.repository = repository
    }
    
    protected func handleError(_ error: Error, operation: String) {
        logger.error("Service operation failed: \(operation), error: \(error)")
    }
    
    protected func logOperation(_ operation: String, duration: TimeInterval) {
        logger.info("Service operation completed: \(operation) in \(duration)ms")
    }
}
```

**Coordinator Pattern:**
```swift
@MainActor
public class BaseCoordinator<DataService, BusinessService, CacheService>: ObservableObject {
    protected let dataService: DataService
    protected let businessService: BusinessService
    protected let cacheService: CacheService
    
    public init(
        dataService: DataService,
        businessService: BusinessService,
        cacheService: CacheService
    ) {
        self.dataService = dataService
        self.businessService = businessService
        self.cacheService = cacheService
    }
}
```

### 2.2 Authorization Service

**Role-Based Authorization:**
```swift
enum Role { 
    case admin, salesperson, keeper, manager, unauthorized
}

enum Action { 
    case createOrder, adjustInventory, planBatch, exportData, viewReports
}

struct AuthorizationService {
    func authorize(_ action: Action, for role: Role) -> Bool {
        switch (role, action) {
        case (.admin, _): 
            return true
        case (.salesperson, .createOrder), (.salesperson, .exportData):
            return true
        case (.keeper, .adjustInventory):
            return true
        case (.manager, .planBatch), (.manager, .viewReports):
            return true
        case (.unauthorized, _):
            return false
        default: 
            return false
        }
    }
    
    func validateAccess(user: User, action: Action) throws {
        guard authorize(action, for: user.primaryRole) else {
            throw AuthorizationError.accessDenied(user: user.id, action: action)
        }
    }
}

enum AuthorizationError: Error {
    case accessDenied(user: String, action: Action)
    case invalidRole(role: String)
    case sessionExpired
}
```

---

## 3. Security Implementation Examples

### 3.1 Enhanced Keychain Wrapper

**Secure Keychain Operations:**
```swift
// REUSABLE: Enhanced keychain operations with secure key derivation
enum SecureKeychain {
    private static let serviceName = "com.lopan.secure"
    
    static func saveSecurely<T: Codable>(_ data: T, forKey key: String) throws {
        let encodedData = try JSONEncoder().encode(data)
        let derivedKey = deriveKey(from: key)
        let encryptedData = try encrypt(encodedData, with: derivedKey)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecValueData as String: encryptedData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status: status)
        }
    }
    
    static func retrieveSecurely<T: Codable>(_ type: T.Type, forKey key: String) throws -> T? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let encryptedData = result as? Data else {
            return nil
        }
        
        let derivedKey = deriveKey(from: key)
        let decryptedData = try decrypt(encryptedData, with: derivedKey)
        return try JSONDecoder().decode(type, from: decryptedData)
    }
    
    private static func deriveKey(from input: String) -> Data {
        // Implement secure key derivation
        return Data(input.utf8)
    }
    
    private static func encrypt(_ data: Data, with key: Data) throws -> Data {
        // Implement AES encryption
        return data
    }
    
    private static func decrypt(_ data: Data, with key: Data) throws -> Data {
        // Implement AES decryption
        return data
    }
}

enum KeychainError: Error {
    case saveFailed(status: OSStatus)
    case retrievalFailed(status: OSStatus)
    case encryptionFailed
    case decryptionFailed
}
```

### 3.2 Data Redaction for PII Protection

**PII Data Redaction:**
```swift
// REUSABLE: PII data redaction for logging and audit trails
struct DataRedaction {
    private static let piiPatterns: [NSRegularExpression] = [
        try! NSRegularExpression(pattern: #"[0-9]{11,19}"#), // Phone numbers
        try! NSRegularExpression(pattern: #"\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b"#), // Email
        try! NSRegularExpression(pattern: #"[0-9]{15,19}"#), // Credit card numbers
    ]
    
    static func redactPII(from text: String) -> String {
        var redacted = text
        
        for pattern in piiPatterns {
            redacted = pattern.stringByReplacingMatches(
                in: redacted,
                range: NSRange(location: 0, length: redacted.count),
                withTemplate: "***REDACTED***"
            )
        }
        
        return redacted
    }
    
    static func safeLog(_ message: String, category: String = "general") {
        let redactedMessage = redactPII(from: message)
        Logger(subsystem: "com.lopan.app", category: category).info("\(redactedMessage)")
    }
}
```

---

## 4. Testing Examples

### 4.1 Repository Testing

**Mock Repository:**
```swift
class MockUserRepository: UserRepository {
    private var users: [User] = []
    private let mockDelay: UInt64 = 100_000_000 // 100ms
    
    func fetch() async throws -> [User] {
        try await Task.sleep(nanoseconds: mockDelay)
        return users
    }
    
    func create(_ user: User) async throws {
        try await Task.sleep(nanoseconds: mockDelay)
        users.append(user)
    }
    
    func update(_ user: User) async throws {
        try await Task.sleep(nanoseconds: mockDelay)
        if let index = users.firstIndex(where: { $0.id == user.id }) {
            users[index] = user
        }
    }
    
    func remove(id: User.ID) async throws {
        try await Task.sleep(nanoseconds: mockDelay)
        users.removeAll { $0.id == id }
    }
}
```

**Service Testing:**
```swift
@MainActor
final class UserServiceTests: XCTestCase {
    private var userService: UserService!
    private var mockRepository: MockUserRepository!
    
    override func setUp() async throws {
        mockRepository = MockUserRepository()
        userService = UserService(repository: mockRepository)
    }
    
    func testCreateUser() async throws {
        // Given
        let newUser = User(name: "Test User", email: "test@example.com")
        
        // When
        try await userService.createUser(newUser)
        
        // Then
        let users = try await mockRepository.fetch()
        XCTAssertEqual(users.count, 1)
        XCTAssertEqual(users.first?.name, "Test User")
    }
    
    func testFetchUsers() async throws {
        // Given
        let user1 = User(name: "User 1", email: "user1@example.com")
        let user2 = User(name: "User 2", email: "user2@example.com")
        try await mockRepository.create(user1)
        try await mockRepository.create(user2)
        
        // When
        let users = try await userService.fetchUsers()
        
        // Then
        XCTAssertEqual(users.count, 2)
    }
}
```

### 4.2 Performance Testing

**Cache Performance Tests:**
```swift
final class CachePerformanceTests: XCTestCase {
    private var cache: SmartCacheManager<TestData>!
    
    override func setUp() {
        cache = SmartCacheManager<TestData>()
    }
    
    func testCacheHitRatio() async throws {
        // Given - populate cache with test data
        let testData = generateTestData(count: 100)
        for (key, data) in testData {
            cache.cacheData([data], for: key)
        }
        
        // When - access cached data multiple times
        var hits = 0
        var misses = 0
        
        for _ in 0..<1000 {
            let randomKey = testData.keys.randomElement()!
            if cache.getCachedData(for: randomKey) != nil {
                hits += 1
            } else {
                misses += 1
            }
        }
        
        // Then - verify hit ratio meets target
        let hitRatio = Double(hits) / Double(hits + misses)
        XCTAssertGreaterThan(hitRatio, 0.8, "Cache hit ratio should be > 80%")
    }
    
    func testMemoryPressureHandling() async throws {
        measure {
            // Fill cache to capacity
            for i in 0..<1000 {
                let data = generateLargeTestData()
                cache.cacheData([data], for: "key_\(i)")
            }
            
            // Simulate memory pressure
            cache.handleMemoryPressure()
            
            // Verify cache size reduced appropriately
            let remainingSize = cache.getCurrentCacheSize()
            XCTAssertLessThan(remainingSize, cache.maxCacheSize / 2)
        }
    }
}
```

---

## 5. CI/CD Templates

### 5.1 Build Script Template

**Xcode Build Validation:**
```bash
#!/bin/bash
set -e

echo "🚀 Starting iOS build pipeline..."

# 1. Clean build directory
echo "🧹 Cleaning build directory..."
xcodebuild -project Lopan.xcodeproj -scheme Lopan clean

# 2. Build for simulator
echo "🔨 Building for iOS Simulator..."
xcodebuild -project Lopan.xcodeproj -scheme Lopan \
    -destination 'platform=iOS Simulator,name=iPhone 15,OS=latest' \
    build

# 3. Run unit tests
echo "🧪 Running unit tests..."
xcodebuild -project Lopan.xcodeproj -scheme Lopan \
    -destination 'platform=iOS Simulator,name=iPhone 15,OS=latest' \
    test

# 4. Check code coverage
echo "📊 Checking code coverage..."
xcrun xccov view --report --json DerivedData/Logs/Test/*.xcresult > coverage.json
COVERAGE=$(cat coverage.json | jq '.lineCoverage')
if (( $(echo "$COVERAGE < 0.70" | bc -l) )); then
    echo "❌ Code coverage below 70%: $COVERAGE"
    exit 1
fi
echo "✅ Code coverage: $COVERAGE"

# 5. Lint Swift code
echo "🔍 Running SwiftLint..."
if which swiftlint > /dev/null; then
    swiftlint --strict
else
    echo "⚠️ SwiftLint not installed"
fi

# 6. Check file size limits
echo "📏 Checking file size limits..."
find . -name "*.swift" -not -path "./Pods/*" | while read file; do
    LINES=$(wc -l < "$file")
    if [ $LINES -gt 800 ]; then
        echo "❌ File size violation: $file has $LINES lines (limit: 800)"
        exit 1
    fi
done

echo "✅ All checks passed!"
```

### 5.2 Performance Testing Script

**Automated Performance Validation:**
```bash
#!/bin/bash
echo "📈 Starting performance validation..."

# Build and run performance tests
xcodebuild -project Lopan.xcodeproj -scheme Lopan \
    -destination 'platform=iOS Simulator,name=iPhone 15,OS=latest' \
    test -only-testing:LopanPerformanceTests

# Extract performance metrics
xcrun xcresult get --path TestResults.xcresult --format json > results.json

# Validate performance benchmarks
python3 validate_performance.py results.json

echo "✅ Performance validation complete!"
```

---

## 6. Configuration Samples

### 6.1 Info.plist ATS Configuration

**App Transport Security:**
```xml
<key>NSAppTransportSecurity</key>
<dict>
  <key>NSAllowsArbitraryLoads</key><false/>
  <key>NSExceptionDomains</key>
  <dict>
    <key>api.lopan.com</key>
    <dict>
      <key>NSIncludesSubdomains</key><true/>
      <key>NSTemporaryExceptionAllowsInsecureHTTPLoads</key><false/>
      <key>NSRequiresCertificateTransparency</key><true/>
    </dict>
    <key>staging.lopan.com</key>
    <dict>
      <key>NSIncludesSubdomains</key><true/>
      <key>NSTemporaryExceptionAllowsInsecureHTTPLoads</key><true/>
      <key>NSExceptionMinimumTLSVersion</key><string>TLSv1.2</string>
    </dict>
  </dict>
</dict>
```

### 6.2 Privacy Configuration

**Privacy Manifest (PrivacyInfo.xcprivacy):**
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>NSPrivacyTrackingDomains</key>
    <array/>
    <key>NSPrivacyCollectedDataTypes</key>
    <array>
        <dict>
            <key>NSPrivacyCollectedDataType</key>
            <string>NSPrivacyCollectedDataTypeCustomerInfo</string>
            <key>NSPrivacyCollectedDataTypeLinked</key>
            <true/>
            <key>NSPrivacyCollectedDataTypeTracking</key>
            <false/>
            <key>NSPrivacyCollectedDataTypePurposes</key>
            <array>
                <string>NSPrivacyCollectedDataTypePurposeAppFunctionality</string>
            </array>
        </dict>
    </array>
    <key>NSPrivacyAccessedAPITypes</key>
    <array>
        <dict>
            <key>NSPrivacyAccessedAPIType</key>
            <string>NSPrivacyAccessedAPICategoryFileTimestamp</string>
            <key>NSPrivacyAccessedAPITypeReasons</key>
            <array>
                <string>C617.1</string>
            </array>
        </dict>
    </array>
</dict>
</plist>
```

### 6.3 Task Pack Template for Claude

**Claude Collaboration Template:**
```markdown
# Task
**Module**: CustomerOutOfStock  
**Context**: Performance optimization for dashboard loading  
**Goal**: Reduce dashboard load time from 300ms to <100ms  
**Constraints**: No UI/UX changes, maintain existing functionality  
**References**: CLAUDE-PERFORMANCE.md, SmartCacheManager implementation

## Acceptance Criteria (Definition of Done)
- [ ] Dashboard loads in <100ms (P95)
- [ ] Cache hit rate >80%
- [ ] Memory usage <75MB peak
- [ ] All existing tests pass
- [ ] Code coverage maintained >70%
- [ ] File size limits enforced (<800 lines)
- [ ] Performance gates validated

## Output Format
- Minimal reviewable diff with clear separation of concerns
- List of affected files with line count changes
- Performance benchmarks before/after
- Test cases covering critical paths
- Migration guide for breaking changes

## Testing Requirements
- [ ] Unit tests for new caching logic
- [ ] Integration tests for dashboard performance  
- [ ] Memory pressure simulation tests
- [ ] UI tests for existing functionality preservation
- [ ] Performance regression tests

## Risks & Mitigation
- **Risk**: Cache complexity introduces bugs
- **Mitigation**: Comprehensive test suite, gradual rollout
- **Rollback**: Feature flag to disable smart caching

## Success Metrics
- Load time: <100ms (from 300ms)
- Cache hit rate: >80%
- Memory usage: <75MB
- File size: All files <800 lines
```

---

## 7. Audit Event Model

### 7.1 Comprehensive Audit System

**Audit Event Structure:**
```swift
struct AuditEvent: Codable {
    enum Kind: String, CaseIterable {
        case login, logout, write, read, export, delete
        case configChange, roleChange, securityEvent
        case performanceAlert, systemError
    }
    
    let id: UUID
    let kind: Kind
    let actorId: String
    let actorName: String
    let targetId: String?
    let targetType: String?
    let occurredAt: Date
    let ipAddress: String?
    let userAgent: String?
    let sessionId: String
    let redactedContext: String
    let metadata: [String: String]
    
    init(kind: Kind, 
         actorId: String, 
         actorName: String,
         target: String? = nil,
         context: String,
         metadata: [String: String] = [:]) {
        self.id = UUID()
        self.kind = kind
        self.actorId = actorId
        self.actorName = actorName
        self.targetId = target
        self.targetType = nil
        self.occurredAt = Date()
        self.ipAddress = getCurrentIPAddress()
        self.userAgent = getCurrentUserAgent()
        self.sessionId = getCurrentSessionId()
        self.redactedContext = DataRedaction.redactPII(from: context)
        self.metadata = metadata
    }
}
```

### 7.2 Audit Service Implementation

**Production Audit Logging:**
```swift
@MainActor
class AuditService: ObservableObject {
    private let repository: AuditRepository
    private let queue = DispatchQueue(label: "audit.queue", qos: .background)
    
    init(repository: AuditRepository) {
        self.repository = repository
    }
    
    func logEvent(_ event: AuditEvent) {
        queue.async { [weak self] in
            Task {
                try await self?.repository.save(event)
                await self?.cleanupOldEvents()
            }
        }
    }
    
    private func cleanupOldEvents() async {
        let cutoff = Calendar.current.date(byAdding: .day, value: -90, to: Date())!
        try? await repository.deleteEvents(before: cutoff)
    }
}
```

---

**Related Documents:**
- [CLAUDE.md](./CLAUDE.md) - Core architecture guidelines
- [CLAUDE-PERFORMANCE.md](./CLAUDE-PERFORMANCE.md) - Performance optimization standards
- [CustomerOutOfStockOptimization_Implementation.md](./CustomerOutOfStockOptimization_Implementation.md) - Implementation plan

---

*Document Version: 1.0*  
*Last Updated: 2025-08-31*  
*Companion to: CLAUDE.md*