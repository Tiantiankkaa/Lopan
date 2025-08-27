# CLAUDE.md — iOS Engineering & Claude Code Collaboration Guide (2025 · Professional Edition, EN)

> Purpose: Establish a production‑grade baseline for **Lopan** iOS, aligned with Apple platform best practices and safe AI collaboration. This is the single source of truth for architecture, data, networking, security & privacy, observability, testing/CI, and role module boundaries.

---

## 0. Golden Rules (NEVER / ALWAYS)

**NEVER**
- Skip guardrails: no `--no-verify`, no disabled tests, no red CI merges
- Bypass architecture: UI/VM must not read/write persistence or call networking directly
- Leak sensitive data: never log PII/tokens/keys; avoid screenshots containing secrets

**ALWAYS**
- Commit in small, reversible increments with clear “why” in commit/PR
- Go through **Service → Repository** for all data and external calls
- Ship PRs with tests, docs updates, and security/privacy self‑check completed

---

## 1. Platform & Build

### 1.1 Targets & Dependencies
- iOS 17+; latest stable Xcode; Swift 5.9+
- **Swift Package Manager** for dependencies; avoid introducing CocoaPods unless reviewed
- Environments: Debug / Release (optionally Staging); config values via **.xcconfig** (never commit secrets)

### 1.2 Launch & Tests
- Open `Lopan.xcodeproj` → select device/simulator → **Run**
- Clean build: Product → **Clean Build Folder**
- Test plans: `LopanTests` (unit) / `LopanUITests` (UI); coverage target ≥ 70% overall, ≥ 85% for core services

---

## 2. Architecture & Dependency Injection

### 2.1 Layering
```
SwiftUI View  (consumes read‑only DTO/VM)
   │
   ▼
Service (business orchestration / validation / authorization)
   │   (protocol injection)
   ▼
Repository (data access protocols) ── Local (SwiftData) / Cloud (Prod)
```

### 2.2 Dependency Injection (sample)
```swift
public protocol HasUserRepository { var users: UserRepository { get } }

public struct AppDependencies: HasUserRepository {
    public let users: UserRepository
    public init(users: UserRepository) { self.users = users }
}

private struct DependenciesKey: EnvironmentKey {
    static let defaultValue = AppDependencies(users: LocalUserRepository())
}
extension EnvironmentValues {
    var deps: AppDependencies {
        get { self[DependenciesKey.self] }
        set { self[DependenciesKey.self] = newValue }
    }
}
```

### 2.3 Concurrency
- Update UI and mutable state on the main thread: use `@MainActor` on VMs/entrypoints
- Support cancellation: `try Task.checkCancellation()`; long operations and networking must be cancellable
- Prefer **structured concurrency** (`async let`, `withTaskGroup`) over ad‑hoc `Task {}` to avoid stray tasks

---

## 3. Data & Migration (SwiftData → Cloud)

### 3.1 Models & DTOs
- SwiftData is used in development/testing only; production replaces it with a cloud backend
- Keep **domain models** separate from **DTOs** to avoid exposing persistence internals

### 3.2 Repository Protocol (example)
```swift
public protocol UserRepository {
    func fetch() async throws -> [User]
    func create(_ user: User) async throws
    func update(_ user: User) async throws
    func remove(id: User.ID) async throws
}
```

### 3.3 Migration Steps
1) Define repository protocols & DTOs per business object  
2) Provide Local (SwiftData) & Cloud implementations; switch via DI  
3) Remove any direct `ModelContext` usages from Views/VMs  
4) Provide data migration scripts and a **gray‑release rollback** plan

---

## 3+. Mandatory Requirements for SwiftData → Cloud Migration

### 3+.1 Schema & Modeling
- Map each SwiftData `@Model` to a cloud table/collection with normalized fields: `id` (UUID/ULID), `createdAt`, `updatedAt`, optional `tenantId`
- Add indexes for hot queries (e.g., `customerId + status + updatedAt DESC`)
- Optional soft delete: `deletedAt`, filtered at the Repository layer by default

### 3+.2 API Contract (Repository must enforce)
- **Cursor‑based pagination** (`cursor/nextPageToken`) — avoid offset pagination
- **Server‑driven** filtering/sorting; expose typed filters in repository APIs
- **Idempotent writes** with `idempotencyKey` to safely retry failures
- **Partial updates** (PATCH/delta) to prevent clobbering entire records

### 3+.3 Auth & Authorization
- Enforce role‑based **Row‑Level Security (RLS)** in the cloud (Salesperson/WarehouseKeeper/WorkshopManager/Admin)
- Double‑gate sensitive writes: Use‑case authorization in Service layer **and** cloud‑side policies
- **Audit** every write/export via `AuditEvent` with redacted context

### 3+.4 Consistency & Sync
- Define transaction boundaries for aggregates (e.g., one order/one SKU); use transactions or actor‑based serialization
- Conflict resolution policy documented (LWW, vector clock, or merge rules)
- **Offline replay**: local operation queue with `source`, `opId`, `retries`

### 3+.5 Rollout & Rollback
- Optional **dual‑write shadow** phase: write SwiftData + Cloud until checks pass, then switch to Cloud‑only
- Feature flag: `FeatureFlags.useCloudRepo` for gradual rollout
- Keep Local repository available for **instant rollback**

### 3+.6 Quality & SLOs
- Contract tests against the Cloud implementation (mock server or staging env)
- Suggested SLOs: P95 read < 300 ms; write < 500 ms (tune per region/network)
- Observability: record success rate/latency/retries/error codes per API

### 3+.7 Supabase Notes (if chosen)
- Postgres schema with **RLS enabled**; define fine‑grained POLICIES per role/tenant
- Authentication via Supabase Auth; clients hold short‑lived tokens
- Prefer RPC/views for complex reads to avoid chatty multi‑table joins from the client
- Example (illustrative only):
```sql
alter table orders enable row level security;

create policy salesperson_read on orders
for select using (
  auth.role() = 'salesperson'
  and tenant_id = auth.jwt() ->> 'tenant_id'
);

create policy salesperson_write on orders
for insert with check (
  auth.role() = 'salesperson'
  and tenant_id = auth.jwt() ->> 'tenant_id'
);
```

### 3+.8 Execution Order (recommended)
1) Freeze repository protocols & DTOs  
2) Implement Cloud repository (read → write → patch → batch)  
3) Add contract/E2E tests & metrics  
4) Run dual‑write shadow with reconciliation  
5) Flip `useCloudRepo` via feature flag, roll out gradually  
6) Remove dev‑only SwiftData seeding/reset from production builds

---

## 4. Networking, Retries & Background

### 4.1 Minimal HTTP Client
```swift
public enum HTTPError: Error { case status(Int), decoding, transport(Error) }

public struct HTTPClient {
    let session: URLSession = .shared
    public func get<T: Decodable>(_ url: URL) async throws -> T {
        var req = URLRequest(url: url)
        req.timeoutInterval = 20
        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode)
        else { throw HTTPError.status((resp as? HTTPURLResponse)?.statusCode ?? -1) }
        do { return try JSONDecoder().decode(T.self, from: data) }
        catch { throw HTTPError.decoding }
    }
}
```

### 4.2 Exponential Backoff (jittered)
```swift
func withRetry<T>(max: Int = 3, op: @escaping () async throws -> T) async throws -> T {
    var attempt = 0
    while true {
        do { return try await op() }
        catch {
            attempt += 1; if attempt >= max { throw error }
            let delay = pow(2.0, Double(attempt)) + Double.random(in: 0...0.5)
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }
    }
}
```

### 4.3 ATS & Certificates
- **ATS on by default**; any exception must be domain‑scoped, time‑boxed, and justified
- If you pin certificates/keys, define rotation and fallback strategies

### 4.4 Background Tasks (BGTaskScheduler)
```swift
BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.lopan.refresh", using: nil) { task in
    Task {
        defer { task.setTaskCompleted(success: true) }
        // Call refresh service; make it cancellable and time‑bounded
    }
}

func scheduleAppRefresh() {
    let req = BGAppRefreshTaskRequest(identifier: "com.lopan.refresh")
    req.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
    try? BGTaskScheduler.shared.submit(req)
}
```

---

## 5. Security & Privacy

### 5.1 Keychain Wrapper (sample)
```swift
import Security

enum Keychain {
    static func save(_ data: Data, account: String, service: String) throws {
        let q: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        SecItemDelete(q as CFDictionary)
        let status = SecItemAdd(q as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
        }
    }
}
```

### 5.2 Privacy Manifest & Permissions
- Provide a project‑level `PrivacyInfo.xcprivacy` declaring data collection and **Required Reason APIs**
- In `Info.plist`, write clear purpose strings: `NSCameraUsageDescription`, `NSPhotoLibraryUsageDescription`, `NSLocalNetworkUsageDescription`, etc.
- **Account deletion**: include an in‑app self‑service deletion flow (data purge + token revocation)

### 5.3 Logging & Audit
```swift
import os
extension Logger {
    static let app = Logger(subsystem: "com.lopan.app", category: "general")
}
// Use privacy‑aware interpolation and avoid printing secrets
Logger.app.info("User action: %{public}@", "list_products")
Logger.app.error("Network error: %{public}@", "\(code)")
```

---

## 6. Observability & Quality
- **MetricKit** for crashes/hangs/energy diagnostics (respect privacy & regulations)
- Add **signposts** (`os_signpost`) around critical paths for Instruments

---

## 7. Directory Structure (Recommended)
```
Lopan/
├── Configuration/        # .xcconfig, PrivacyInfo.xcprivacy
├── Models/               # Domain models (SwiftData/DTO)
├── Repository/           # Protocols & implementations (Local/Cloud/Mock)
│   ├── Local/
│   └── Cloud/
├── Services/             # Business orchestration
├── Views/                # SwiftUI (by role)
│   ├── Administrator/
│   ├── Salesperson/
│   ├── WarehouseKeeper/
│   ├── WorkshopManager/
│   └── Components/       # Reusable UI
├── Utils/                # Extensions, Logger, FeatureFlags
└── Tests/                # Unit & UI tests
```

---

## 7+. Directory Structure Enforcement (Executable Rules)
1) **Path = boundary**: Views may import other Views, `Services`, and shared `Utils`; **must not** import `Repository/Local` or `Repository/Cloud` directly  
2) **Naming**: role folders split by domain, e.g., `Views/WorkshopManager/Batches/`, `Views/WarehouseKeeper/Inventory/`  
3) **Ownership (CODEOWNERS suggestion)**:
```
# Docs & Standards
/CLAUDE*.md                    @lopan/arch-reviewers
/Configuration/**              @lopan/release-engineers

# Data & Repos
/Repository/**                 @lopan/data
/Services/**                   @lopan/serverless @lopan/ios-core

# Roles
/Views/Administrator/**        @lopan/admin-ui
/Views/Salesperson/**          @lopan/sales-ui
/Views/WarehouseKeeper/**      @lopan/warehouse-ui
/Views/WorkshopManager/**      @lopan/workshop-ui
/Views/Components/**           @lopan/design-system
```
4) **SPM boundaries (optional)**: split `Repository` and `Services` into Swift packages; Views depend on `Services` only  
5) **Lint**: add AST/custom rules (or SwiftLint custom_rules) forbidding `import SwiftData` or `URLSession` inside `Views/*`

---

## 8. Role Module Boundaries (Responsibility & Data Entry)

- **Salesperson**: customers/products, OOS tracking; read‑only inventory/production; exports must be redacted and audited  
- **WarehouseKeeper**: stock in/out, counting; event‑sourced ledger with serialized writes per SKU (actor or transaction)  
- **WorkshopManager**: plan/schedule, machine sync, auto‑completion; one **state machine** entrypoint for batch transitions  
- **Administrator**: RBAC & audit, versioned config center (activate/rollback), feature flags

> No cross‑domain access: all writes go through **Service → Repository → Audit**.

---

## 9. Coding Conventions
- Prefer value semantics & immutability; express errors via `throws`/`Result`
- SwiftUI: minimize state; avoid long operations directly in Views
- Naming: types in PascalCase; members/functions in camelCase; async funcs encode side effects/timeouts/cancellation

---

## 10. Testing Strategy
- Unit: business rules, edge cases, concurrency/cancellation; inject Mock repositories
- UI: key flows (login, order, stock, scheduling); add accessibility paths
- Network: use custom `URLProtocol` for deterministic tests; control timeouts/retries

---

## 11. CI/CD
- **CI gates**: format/lint → build → unit/UI tests → static analysis → privacy checks (manifest/permissions)
- **Conventional Commits**; protected branches + CODEOWNERS; no hook bypassing
- **Release**: TestFlight with change log, test focus, test accounts; pre‑submission re‑check ATS/privacy manifest/account deletion

---

## 12. Claude Code Collaboration (Hard Requirements)
- **One task pack at a time** with context, constraints, DoD & tests
- **Output**: smallest reviewable diff + tests + docs
- **Safety self‑check**: Claude must answer the pre‑commit checklist (see §13) and self‑score

---

## 13. Pre‑Commit Checklist (DoD)
- [ ] No direct persistence access; only via Service/Repository  
- [ ] Concurrency safe; UI updates on main; cancellable tasks where needed  
- [ ] ATS compliant; no global exceptions; cert pinning has rotation plan  
- [ ] Keychain/file protection configured; no sensitive logs/screenshots  
- [ ] `PrivacyInfo.xcprivacy` and Info.plist purpose strings complete  
- [ ] Unit/UI tests pass; coverage at target  
- [ ] Accessibility & localization basic checks passed  
- [ ] Change notes, migration impact, and rollback plan in PR

---

## 14. Appendices (Samples & Templates)

### 14.1 Repository Local/Cloud Skeletons
```swift
public final class LocalUserRepository: UserRepository {
    public init() {}
    public func fetch() async throws -> [User] { /* SwiftData read */ [] }
    public func create(_ user: User) async throws { /* SwiftData write */ }
    public func update(_ user: User) async throws { }
    public func remove(id: User.ID) async throws { }
}

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

### 14.2 Authorization (Sample)
```swift
enum Role { case admin, salesperson, keeper, manager }
enum Action { case createOrder, adjustInventory, planBatch, exportData }

struct AuthorizationService {
    func authorize(_ action: Action, for role: Role) -> Bool {
        switch (role, action) {
        case (.admin, _): true
        case (.salesperson, .createOrder), (.salesperson, .exportData): true
        case (.keeper, .adjustInventory): true
        case (.manager, .planBatch): true
        default: false
        }
    }
}
```

### 14.3 Audit Event Model (Sample)
```swift
struct AuditEvent: Codable {
    enum Kind: String { case login, write, export, configChange }
    let id: UUID
    let kind: Kind
    let actorId: String
    let occurredAt: Date
    let target: String
    let redactedContext: String
}
```

### 14.4 Info.plist / ATS Snippet (Illustrative)
```xml
<key>NSAppTransportSecurity</key>
<dict>
  <key>NSAllowsArbitraryLoads</key><false/>
  <key>NSExceptionDomains</key>
  <dict>
    <key>api.example.com</key>
    <dict>
      <key>NSIncludesSubdomains</key><true/>
      <key>NSTemporaryExceptionAllowsInsecureHTTPLoads</key><false/>
      <key>NSRequiresCertificateTransparency</key><true/>
    </dict>
  </dict>
</dict>
```

### 14.5 Task Pack (Claude Prompt) Template
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

---

## 15. Reusable System Components (Generated from Customer Out-of-Stock Refactoring)

> **Note**: The following components were created during the Customer Out-of-Stock management module refactoring and are designed for system-wide reuse across all Lopan modules.

### 15.1 Security & Privacy Components

#### SecureKeychain Wrapper (`Utils/Security/SecureKeychain.swift`)
Enhanced Keychain wrapper with secure key derivation and PII protection:
```swift
// REUSABLE: Enhanced keychain operations with secure key derivation
enum SecureKeychain {
    static func saveSecurely<T: Codable>(_ value: T, forKey key: String) throws {
        let derivedKey = deriveSecureKey(from: key)
        let data = try JSONEncoder().encode(value)
        try save(data, account: derivedKey, service: "com.lopan.secure")
    }
    
    private static func deriveSecureKey(from key: String) -> String {
        // Implements PBKDF2 key derivation for secure storage keys
    }
}
```

#### DataRedaction Utility (`Utils/Privacy/DataRedaction.swift`)
PII-aware data redaction for logging and audit trails:
```swift
// REUSABLE: Privacy-aware data redaction for all logging
struct DataRedaction {
    static func redactPII<T>(_ value: T, fields: [String]) -> [String: Any] {
        // Safe redaction of sensitive fields in logs and audit events
        // Usage: DataRedaction.redactPII(user, fields: ["phone", "email"])
    }
}
```

### 15.2 Performance & Caching Components

#### LRU Memory Cache (`Utils/Caching/LRUMemoryCache.swift`)
Generic LRU cache with memory pressure handling:
```swift
// REUSABLE: Memory-efficient LRU cache for any data type
@MainActor
class LRUMemoryCache<Key: Hashable, Value> {
    private var cache: [Key: Value] = [:]
    private var accessOrder: [Key] = []
    private let maxSize: Int
    private let maxMemoryBytes: Int
    
    func get(_ key: Key) -> Value? { /* LRU access pattern */ }
    func set(_ key: Key, value: Value) { /* Memory-aware insertion */ }
    func handleMemoryPressure() { /* Aggressive cleanup */ }
}
```

#### SmartCacheManager (`Utils/Caching/SmartCacheManager.swift`)
Three-tier intelligent caching with predictive preloading:
```swift
// REUSABLE: Advanced caching system for high-performance data access
@MainActor
class SmartCacheManager<T: Cacheable> {
    // Hot cache - frequently accessed (TTL: 5 min)
    // Warm cache - recently accessed (TTL: 15 min)  
    // Predictive cache - anticipated data (TTL: 1 hour)
    
    func getCachedData(for key: String) -> T? { /* Multi-tier lookup */ }
    func triggerPredictivePreloading(for key: String) { /* Pattern-based preloading */ }
}
```

### 15.3 Concurrency & Performance Patterns

#### Concurrent Batch Processing Pattern
Optimized TaskGroup pattern for batch operations:
```swift
// REUSABLE: Concurrent batch processing with actor safety
func processConcurrentBatches<T, R>(
    items: [T], 
    batchSize: Int = 10,
    processor: @escaping (T) async throws -> R
) async throws -> [R] {
    return try await withThrowingTaskGroup(of: [R].self) { group in
        for batch in items.batched(into: batchSize) {
            group.addTask {
                // Process batch concurrently while maintaining actor safety
            }
        }
        // Collect and flatten results
    }
}
```

#### Single-Pass Algorithm Optimization
Performance pattern for O(n) complexity algorithms:
```swift
// REUSABLE: Single-pass statistics calculation pattern
func calculateStatistics<T>(_ items: [T]) -> Statistics {
    return items.reduce(into: Statistics()) { stats, item in
        // Single iteration: update all counters and aggregates
        // Reduces O(4n) → O(n) complexity
    }
}
```

### 15.4 Architecture Components

#### Service Layer Base Classes
Foundation classes for service layer architecture:
```swift
// REUSABLE: Base coordinator pattern for all feature modules
@MainActor
class BaseCoordinator<DataService, BusinessService, CacheService>: ObservableObject {
    @Published var isLoading = false
    @Published var error: Error?
    
    // Standardized error handling, loading states, and lifecycle management
}

// REUSABLE: Business service validation framework
protocol BusinessServiceValidation {
    associatedtype Entity
    func validateRecord(_ record: Entity) throws
    func validateCreationRequest(_ request: Any) throws
}
```

#### Repository Pattern Templates
```swift
// REUSABLE: Generic repository with caching integration
protocol CacheableRepository {
    associatedtype Entity
    associatedtype FilterCriteria
    
    func fetchWithCache(_ criteria: FilterCriteria) async throws -> [Entity]
    func invalidateCache(for criteria: FilterCriteria)
}
```

### 15.5 UI/UX Utility Components

#### Memory Usage Monitoring
```swift
// REUSABLE: Memory usage tracking for performance debugging
struct CacheMemoryUsage {
    let recordsCount: Int
    let approximateMemoryUsage: Int
    let cacheHitRate: Double
    let lastEvictionTime: Date?
    
    // Usage: let usage = cacheService.getMemoryUsage()
}
```

#### Debounced Search Pattern
```swift
// REUSABLE: Search input debouncing for performance
@MainActor
class Debouncer {
    private var task: Task<Void, Never>?
    
    func debounce(duration: TimeInterval = 0.3, action: @escaping () async -> Void) {
        task?.cancel()
        task = Task {
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            await action()
        }
    }
}
```

### 15.6 Usage Guidelines

1. **Security Components**: Use `SecureKeychain` and `DataRedaction` for all sensitive data handling
2. **Caching**: Implement `LRUMemoryCache` for simple caching, `SmartCacheManager` for complex scenarios
3. **Performance**: Apply concurrent batch processing and single-pass patterns for heavy operations
4. **Architecture**: Extend base coordinator and repository patterns for new feature modules
5. **Memory Management**: Monitor memory usage and implement proper cleanup in all cache implementations

### 15.7 Integration Examples

```swift
// Example: Integrating reusable components in a new feature module
class ProductManagementCoordinator: BaseCoordinator<ProductDataService, ProductBusinessService, ProductCacheService> {
    private let smartCache = SmartCacheManager<Product>()
    private let debouncer = Debouncer()
    
    func searchProducts(_ query: String) {
        debouncer.debounce { [weak self] in
            // Use smart cache for search results
            await self?.loadProductsWithSmartCache(query)
        }
    }
}
