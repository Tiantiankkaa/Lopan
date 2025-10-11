# CLAUDE.md — iOS Engineering Guide for Lopan

> Core architecture and development guidelines for the Lopan iOS application.

---

## Prerequisites & Required Documentation

### ⚠️ MANDATORY: Consult Before Implementation

#### Core Development
- **Swift Language Guide**: https://docs.swift.org/swift-book/
- **SwiftUI Documentation**: https://developer.apple.com/documentation/swiftui
- **SwiftData Framework**: https://developer.apple.com/documentation/swiftdata
- **Concurrency**: https://developer.apple.com/documentation/swift/concurrency

#### iOS 26 Specific
- **What's New in iOS 26**: https://developer.apple.com/ios/whats-new/
- **iOS 26 Release Notes**: https://developer.apple.com/documentation/ios-release-notes
- **WWDC 2025 Sessions**: https://developer.apple.com/wwdc25/
  - "What's New in SwiftData"
  - "Optimize for iOS 26"
  - "Performance Best Practices"

#### Design & UX
- **Human Interface Guidelines (HIG)**: https://developer.apple.com/design/human-interface-guidelines/
- **iOS Design Resources**: https://developer.apple.com/design/resources/
- **Accessibility**: https://developer.apple.com/accessibility/

#### Performance & Memory
- **Performance**: https://developer.apple.com/performance/
- **Energy Efficiency Guide**: https://developer.apple.com/library/archive/documentation/Performance/Conceptual/EnergyGuide-iOS/
- **Memory Management**: https://developer.apple.com/documentation/swift/memory-safety

#### Security & Privacy
- **App Privacy Details**: https://developer.apple.com/app-store/app-privacy-details/
- **Security**: https://developer.apple.com/security/
- **Privacy Best Practices**: https://developer.apple.com/privacy/

### Critical Rules
1. Always consult latest official documentation before implementing
2. Check iOS 26 updates - don't assume old API behavior
3. Review WWDC sessions for new paradigms and deprecations
4. Follow HIG strictly for all UI/UX decisions
5. Verify memory targets against Apple performance guidelines

---

## Golden Rules

**NEVER**
- Skip guardrails: no `--no-verify`, no disabled tests, no red CI merges
- Bypass architecture: UI/VM must not read/write persistence or call networking directly
- Leak sensitive data: never log PII/tokens/keys; avoid screenshots containing secrets
- Use deprecated APIs (see Deprecated APIs section)

**ALWAYS**
- Commit in small, reversible increments with clear "why" in commit/PR
- Go through **Service → Repository** for all data and external calls
- Ship PRs with tests, docs updates, and security/privacy self-check completed
- Consult Apple documentation before implementing new features

---

## Platform & Build

### Core Requirements
- **iOS 26+ (Liquid Glass design)**: Xcode 17+; Swift 6.0+
- **Deployment Target**: iOS 17.0 minimum, iOS 26.0 target
- **Target Device**: iPhone 17 Pro Max running iOS 26
- **Package Manager**: Swift Package Manager
- **Test Coverage**: ≥ 70% overall, ≥ 85% for core services

### 🔴 CRITICAL: Swift 6 Language Mode (MANDATORY)
- **Strict Concurrency**: `SWIFT_STRICT_CONCURRENCY = complete` (default in Swift 6)
- **Build Setting**: Xcode → Build Settings → "Strict Concurrency Checking" → "Complete"
- **Data-Race Safety**: Prevents data races at compile time
- **Migration Path**: minimal → targeted → complete

### 🔴 CRITICAL: Privacy Manifest (MANDATORY)
- **File**: `PrivacyInfo.xcprivacy` required in app bundle
- **Deadline**: February 12, 2025 for apps with third-party SDKs
- **Consequence**: App Store rejection if missing/incomplete
- **Must Declare**: Required Reason APIs, data collection types, domains
- **Reference**: https://developer.apple.com/documentation/bundleresources/adding-a-privacy-manifest-to-your-app-or-third-party-sdk

---

## Architecture

### Layering
```
SwiftUI View → Service → Repository ← Local (SwiftData) / Cloud
```

### Dependency Injection
Use environment injection for services and repositories. Never access `ModelContext` or network layers directly from Views.

### Concurrency (Swift 6)

#### Key Requirements
- **@MainActor**: REQUIRED for all UI state and SwiftUI properties
- **@Sendable**: Mark types safe for cross-concurrency sharing
- **Actor Isolation**: Use actors for mutable state shared across tasks
- **Structured Concurrency**: Prefer `async let` and `withTaskGroup`

#### Best Practices
- Always support cancellation: `try Task.checkCancellation()`
- Use `async let` for independent parallel tasks
- Use `withTaskGroup` for dynamic batch operations
- Never use `Task.detached` unless absolutely necessary
- Reference: https://developer.apple.com/documentation/swift/concurrency

---

## iOS 26 & Liquid Glass Design

> **Reference**: https://developer.apple.com/design/human-interface-guidelines/

### Design Language
Apple's most significant visual redesign since 2013. Liquid Glass brings translucent, glass-like materials emphasizing depth, fluidity, and content focus.

### Key Characteristics
- Translucent UI with dynamic material that reflects surroundings
- Optical qualities simulating real-world glass with motion-reactive effects
- Adaptive appearance for light/dark environments
- Content-first: Tab bars shrink on scroll to emphasize content

### Modal Presentation (CRITICAL)
- **`confirmationDialog()` MUST attach to triggering view** (e.g., button)
- Liquid Glass animation flows from source view
- Use `.presentationDetents([.medium, .large])` for partial heights
- Bottom sheets float with rounded corners

### Version Adaptability
- Use `@available(iOS 26, *)` for Liquid Glass-specific features
- Maintain backward compatibility to iOS 17.0

---

## Data Layer

### Repository Pattern
All data access MUST go through repository abstractions. Never access `ModelContext` directly from Views or ViewModels.

```swift
protocol CustomerRepository {
    func fetch() async throws -> [Customer]
    func create(_ customer: Customer) async throws
    func update(_ customer: Customer) async throws
    func delete(id: Customer.ID) async throws
}
```

### SwiftData Best Practices

#### ⚠️ CRITICAL: Versioned Schemas
**ALWAYS start with versioned schemas from day one** to avoid migration crashes.

```swift
enum AppSchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] {
        [Customer.self, Product.self]
    }
}
```

#### iOS 26: Class Inheritance Support
- Keep inheritance trees shallow (2-3 levels max)
- Design based on actual query needs
- Always version schemas before structural changes

#### Cloud Sync Constraints
⚠️ Once cloud sync enabled: Model changes MUST be lightweight migration compatible

**Reference**: https://developer.apple.com/documentation/swiftdata

---

## Networking

### Modern URLSession with Async/Await
- Use `async/await` for all network requests
- Implement retry logic with exponential backoff
- Use `async let` for parallel requests
- Implement caching to reduce network calls (60% reduction possible)

**Reference**: https://developer.apple.com/documentation/foundation/urlsession

---

## Security & Privacy

### 🔴 CRITICAL: PrivacyInfo.xcprivacy (2025 Requirement)

#### Requirements
- **Deadline**: February 12, 2025
- **Location**: Root of app bundle and each third-party SDK
- **Consequence**: App Store rejection if missing

#### Must Declare
1. **Required Reason APIs**: File timestamp, system boot time, disk space, user defaults
2. **Data Collection Types**: What data is collected and why
3. **Tracking Domains**: All analytics/advertising domains

#### Account Deletion (MANDATORY)
If app supports account creation:
- MUST provide in-app deletion mechanism
- Deletion option must be easy to find
- Must remove all user data from backend
- Non-compliance = App Store rejection

### Keychain
Use Keychain for all sensitive data (tokens, credentials, keys). Never hardcode secrets.

### Logging
Use privacy-aware logging with `Logger`:
```swift
Logger.app.info("User action: %{public}@", action) // Mark PII as private (default)
```

**Reference**: https://developer.apple.com/app-store/app-privacy-details/

---

## Apple Intelligence (iOS 26)

### Foundation Models Framework
- Access on-device 3B parameter LLM
- Privacy-preserving (all on-device)
- Zero cost (no API charges)
- Offline capable

### Capabilities
Text summarization, entity extraction, sentiment analysis, creative content generation

### Lopan Use Cases
1. Auto-summarize customer notes
2. Extract customer info from free text
3. Analyze feedback sentiment
4. Generate product descriptions

**Reference**: https://developer.apple.com/documentation/foundationmodels

---

## Deprecated APIs & Migration (2025)

### ❌ Deprecated in Xcode 17 / iOS 26
- **@IBDesignable**: Use SwiftUI Previews
- **genstrings**: Use String Catalogs
- **Swift Migrator**: Manual migration via compiler diagnostics
- **Old UIApplicationDelegate methods**: Use UIScene lifecycle
- **Legacy MDM Commands**: Transition to DDM

**Always check iOS 26 Release Notes before using any API**

---

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

---

## Role Boundaries

- **Salesperson**: Customer/product management, out-of-stock tracking
- **WarehouseKeeper**: Stock management, inventory counting
- **WorkshopManager**: Production planning, batch scheduling
- **Administrator**: User management, system configuration

### Business Modules

#### Customer Out-of-Stock Management
- **Status**: `pending` | `completed` | `refunded`
- **Flow**: Request → pending → fulfilled/completed OR cancelled/refunded

#### Business Terminology
- **Delivery (还货)**: Fulfilling orders by delivering goods TO customers (Company → Customer)
- **Refund (退货)**: Cancelling orders and returning TO supplier (Customer → Company/Supplier)

---

## Coding Standards

- **Value semantics & immutability** preferred
- **SwiftUI**: Minimize state, avoid long operations in Views
- **Naming**: UpperCamelCase for types, lowerCamelCase for members (see Swift API Design Guidelines)
- **Documentation**: All public APIs require doc comments
- **Reference**: https://www.swift.org/documentation/api-design-guidelines/

---

## Testing

- **Unit**: Business rules, concurrency, mock repositories
- **UI**: Key user flows, accessibility
- **Integration**: Network layer with custom URLProtocol

---

## CI/CD & App Distribution

### CI Pipeline Gates
1. Lint (SwiftLint compliance)
2. Build (Release configuration)
3. Tests (≥70% coverage, no failures)
4. Privacy checks (PrivacyInfo.xcprivacy validation)
5. Concurrency safety (no Swift 6 warnings)
6. Security scan (no hardcoded secrets)

### TestFlight Requirements
- Privacy manifest present and complete
- Beta app description written
- Privacy policy URL accessible
- App Review Guidelines compliance

### App Store Connect
- **Privacy Disclosures**: MANDATORY questionnaire in App Store Connect
- **Privacy Policy URL**: MANDATORY, must be publicly accessible
- **Account Deletion**: Must be implemented if accounts supported
- **Sensitive Permissions**: Provide clear justifications in metadata

### Version Management
- **Semantic Versioning**: MAJOR.MINOR.PATCH
- **Conventional Commits**: `feat:`, `fix:`, `docs:`, `refactor:`
- **Protected Branches**: `main` requires PR reviews

---

## Pre-Commit Checklist

### Architecture & Code Quality
- [ ] Service/Repository pattern followed
- [ ] Swift 6 concurrency compliance (no warnings)
- [ ] @MainActor applied to all UI state
- [ ] No deprecated APIs used

### Security & Privacy
- [ ] No hardcoded secrets
- [ ] Keychain usage proper
- [ ] PrivacyInfo.xcprivacy updated
- [ ] Privacy-aware logging (no PII)

### Testing & Quality
- [ ] All tests pass
- [ ] Coverage targets met (≥70%)
- [ ] No compiler warnings
- [ ] Build succeeds in Release

### SwiftData
- [ ] Versioned schemas used
- [ ] Migration plan defined
- [ ] Cloud sync compatible (if applicable)

### Documentation
- [ ] README/docs updated
- [ ] CHANGELOG entry added
- [ ] Commit follows conventional format

---

*iOS 26 Liquid Glass SwiftUI Architecture Guide*
*Target: iPhone 17 Pro Max • iOS 26.0*
*Swift 6.0+ • Xcode 17+ • 2025 Privacy Standards*
*Last Updated: 2025-10-11*
