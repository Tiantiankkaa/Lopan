# CLAUDE.md

This file provides technical and architectural guidelines for Claude Code (claude.ai/code) and the development team working in this repository.  
**Please strictly follow these conventions to ensure code maintainability, team collaboration, and smooth future database migration.**

---

## 1. Development & Running

### 1.1 Build & Launch

- **Build**: Open `Lopan.xcodeproj` with Xcode
- **Run**: Select device or simulator, then click Run
- **Clean**: In Xcode menu, choose Product → Clean Build Folder

### 1.2 Testing

- **Unit Tests**: Run the `LopanTests` target in Xcode
- **UI Tests**: Run the `LopanUITests` target in Xcode

---

## 2. Technical Architecture

### 2.1 Tech Stack

- **SwiftUI**: Modern declarative UI framework
- **SwiftData**: Local data persistence (for development and testing)
- **Xcode Project**: Targets iOS 17.0+
- **(For production) Cloud Database**: Supabase, Firebase, AWS DynamoDB, or other cloud DBs

### 2.2 Layering & Architectural Pattern

- **Authentication Flow**: Login via WeChat, phone, or Apple ID → Assign role → Enter role-specific dashboard
- **Data Layer (Models)**: Relationships managed via SwiftData (to be adapted for cloud DB in production)
- **Repository Layer** (recommended): Centralized data access interfaces for seamless switching between local and cloud backends
- **Service Layer**: Business logic, only interacts with the Repository layer
- **View Layer**: Organized by user role, strictly avoids direct data storage access (interacts only with Service/Repository)

---

## 3. Key Business Models & Relationships

- **User**: Core user model, with role and access control
- **Customer/Product**: Business entities with one-to-many relationships
- **CustomerOutOfStock**: Tracks customer-product out-of-stock priorities
- **Production Models**: WorkshopProduction, EVAGranulation, WorkshopIssue, etc.

---

## 4. Roles & Permissions

- **Salesperson**: Customer/product management, out-of-stock tracking
- **Warehouse Keeper**: Production style and inventory management
- **Workshop Manager**: Production status and equipment monitoring
- **EVA Granulation Technician**: Raw material tracking, granulation records
- **Workshop Technician**: Equipment maintenance, issue reporting
- **Administrator**: Full system and user management

---

## 5. Data Initialization & Sample Data

- **Development phase**: All data storage uses SwiftData in-memory mode (`isStoredInMemoryOnly: true`)
- **Sample data**: Automatically injected on app launch via `DataInitializationService`
- **Data clear/reset**: Provided for testing and development only, must be disabled/removed in production

---

## 6. Directory Structure Specification

```
Lopan/
├── Models/              # SwiftData model definitions (will need to map to cloud models)
├── Repository/          # Data access protocols & local/cloud implementations (highly recommended)
│   ├── Local/
│   └── Cloud/
├── Services/            # Business logic (depends on Repository only)
├── Views/               # SwiftUI views organized by role
│   ├── Administrator/
│   ├── Salesperson/
│   └── Components/      # Reusable UI components
├── Utils/               # Utility functions and extensions
└── Configuration/       # App configuration
```

---

## 7. Coding Conventions & Best Practices

- **Never access SwiftData directly outside the Service/Repository layer**
- **All data CRUD operations must go through the Repository layer** so cloud DB can be swapped in without touching business or view code
- **Extract all reusable UI into Components**
- **Do not create unnecessary files or functions**; always check for existing reusable code first
- **Test data injection and reset are for dev only and must be removed for production**
- **Directory structure and interface definitions should remain stable**
- **When adding features, always check if existing Services/Components/Utils can be reused**

---

## 8. Database Migration & Adaptation (SwiftData → Cloud)

### 8.1 Migration Goals

- Before production, replace all SwiftData persistence with cloud database
- The codebase must be decoupled enough that only the Repository layer implementation needs to be swapped, with zero impact on business or view layers

### 8.2 Claude/Team Migration Checklist

| Module             | File/Class Name                       | Current Implementation   | Migration Suggestion            |
|--------------------|---------------------------------------|-------------------------|---------------------------------|
| User Model         | Models/User.swift                     | SwiftData               | Cloud DB Model/DTO              |
| Data Initialization| Services/DataInitializationService    | SwiftData batch writes  | Cloud DB initialization scripts |
| User CRUD          | Services/UserService.swift            | ModelContext            | UserRepository protocol adapter |
| Business Data Mgmt | Views/XXX/                            | Direct ModelContext     | Access/persist via Repository   |
| ...                | ...                                   | ...                     | ...                             |

> **Recommendation:** Inject Repository protocol into each Service, so that Local, Cloud, or Mock implementations can be switched at build/runtime.

### 8.3 Repository Protocol Example (pseudocode)

```swift
protocol UserRepository {
    func fetchUsers() async throws -> [User]
    func addUser(_ user: User) async throws
    // other CRUD methods...
}
```

---

## 9. References & Supplementary Notes

- For further extension—code style guide, naming conventions, API documentation, branching strategy, etc.—refer to Apple’s official sample projects or leading industry repositories.
- Documentation and code comments should be bilingual (Chinese & English) or Chinese-only, as fits the team’s actual use.

---

If you need additional templates for migration scripts, code quality automation, or team onboarding docs, let us know.  
**All contributors must strictly comply with the above conventions for high project quality and easy maintainability.**
