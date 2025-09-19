# CLAUDE.md — iOS Engineering Guide for Lopan

> Core architecture and development guidelines for the Lopan iOS application.

---

## Golden Rules

**NEVER**
- Skip guardrails: no `--no-verify`, no disabled tests, no red CI merges
- Bypass architecture: UI/VM must not read/write persistence or call networking directly
- Leak sensitive data: never log PII/tokens/keys; avoid screenshots containing secrets

**ALWAYS**
- Commit in small, reversible increments with clear "why" in commit/PR
- Go through **Service → Repository** for all data and external calls
- Ship PRs with tests, docs updates, and security/privacy self‑check completed

---

## Platform & Build

- iOS 17+; latest stable Xcode; Swift 5.9+
- **Swift Package Manager** for dependencies
- Test coverage target ≥ 70% overall, ≥ 85% for core services

---

## Architecture

### Layering
```
SwiftUI View
   ↓
Service (business logic)
   ↓
Repository (data access) ← Local (SwiftData) / Cloud
```

### Dependency Injection
```swift
public protocol HasUserRepository { var users: UserRepository { get } }

public struct AppDependencies: HasUserRepository {
    public let users: UserRepository
}

// Environment injection
extension EnvironmentValues {
    var deps: AppDependencies {
        get { self[DependenciesKey.self] }
        set { self[DependenciesKey.self] = newValue }
    }
}
```

### Concurrency
- Use `@MainActor` for UI state management
- Support cancellation with `Task.checkCancellation()`
- Prefer structured concurrency (`withTaskGroup`) over ad-hoc tasks

---

## Data Layer

### Repository Pattern
```swift
protocol UserRepository {
    func fetch() async throws -> [User]
    func create(_ user: User) async throws
    func update(_ user: User) async throws
    func delete(id: User.ID) async throws
}
```

### Migration Strategy (SwiftData → Cloud)
1. Define repository protocols & DTOs
2. Implement Local (SwiftData) & Cloud versions
3. Remove direct `ModelContext` usage from Views
4. Feature flag rollout with rollback plan


## Networking

### HTTP Client
```swift
struct HTTPClient {
    func get<T: Decodable>(_ url: URL) async throws -> T {
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode) else {
            throw HTTPError.invalidResponse
        }
        return try JSONDecoder().decode(T.self, from: data)
    }
}
```

### Retry Logic
```swift
func withRetry<T>(_ operation: () async throws -> T) async throws -> T {
    for attempt in 1...3 {
        do { return try await operation() }
        catch {
            if attempt == 3 { throw error }
            let delay = pow(2.0, Double(attempt))
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }
    }
    fatalError() // Should never reach here
}
```

## Security & Privacy

### Keychain
```swift
enum Keychain {
    static func save(_ data: Data, account: String, service: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data
        ]
        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainError.saveFailed }
    }
}
```

### Privacy Requirements
- `PrivacyInfo.xcprivacy` for data collection declarations
- Clear purpose strings in `Info.plist`
- In-app account deletion flow

### Logging
```swift
extension Logger {
    static let app = Logger(subsystem: "com.lopan.app", category: "general")
}
// Use privacy-aware logging
Logger.app.info("User action: %{public}@", action)
```

## Directory Structure
```
Lopan/
├── Models/               # Domain models & DTOs
├── Repository/           # Data access (Local/Cloud)
├── Services/             # Business logic
├── Views/                # SwiftUI by role
│   ├── Administrator/
│   ├── Salesperson/
│   ├── WarehouseKeeper/
│   ├── WorkshopManager/
│   └── Components/       # Reusable UI
├── Utils/                # Extensions, Logger
└── Tests/                # Unit & UI tests
```

### Architecture Rules
- Views → Services only (no direct Repository access)
- Services → Repository for data access
- Keep role-based view separation

## Role Boundaries

- **Salesperson**: Customer/product management, out-of-stock tracking
- **WarehouseKeeper**: Stock management, inventory counting
- **WorkshopManager**: Production planning, batch scheduling
- **Administrator**: User management, system configuration

### Business Modules

#### Customer Out-of-Stock Management
- **Status Model**: `pending` | `completed` | `returned`
- **Flow**: Request → pending → fulfilled/completed OR refunded/returned
- **Location**: `Models/CustomerOutOfStock.swift`

#### Give-Back Management
- **Purpose**: Handle returns of delivered products
- **Separate**: Independent from out-of-stock management
- **Location**: `Views/Salesperson/GiveBackManagementView.swift`

## Coding Standards
- Value semantics & immutability preferred
- SwiftUI: minimize state, avoid long operations in Views
- Naming: PascalCase for types, camelCase for members

## Testing
- **Unit**: Business rules, concurrency, mock repositories
- **UI**: Key user flows, accessibility
- **Integration**: Network layer with custom URLProtocol

## CI/CD
- Gates: lint → build → tests → privacy checks
- Conventional commits, protected branches
- TestFlight releases with proper changelogs

## Pre-Commit Checklist
- [ ] Service/Repository pattern followed
- [ ] Concurrency safety (@MainActor for UI)
- [ ] Security: no leaked secrets, proper Keychain usage
- [ ] Privacy manifest updated
- [ ] Tests pass, coverage targets met
- [ ] Documentation updated

## Implementation Notes

### Key Patterns
- Repository: Local/Cloud/Mock implementations
- Service Layer: Business logic with authorization
- Security: Role-based access, secure keychain
- Networking: Retry logic, timeout handling
- Testing: Mock infrastructure, realistic test data

### Best Practices
- Structured concurrency (TaskGroup for batches)
- Comprehensive error handling
- Memory pressure handling
- Performance monitoring


---

*iOS 17+ SwiftUI Architecture Guide*
*Last Updated: 2025-09-19*
