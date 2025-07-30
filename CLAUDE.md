# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Development Commands

### Building and Running
- **Build**: Use Xcode to build the project (`Lopan.xcodeproj`)
- **Run**: Select target device/simulator in Xcode and click run
- **Clean**: Product → Clean Build Folder in Xcode

### Testing
- **Unit Tests**: Run `LopanTests` target in Xcode
- **UI Tests**: Run `LopanUITests` target in Xcode

## Architecture Overview

### Technology Stack
- **SwiftUI**: Modern declarative UI framework
- **SwiftData**: Data persistence with `ModelContainer` and `ModelContext`
- **Xcode Project**: iOS app targeting iOS 17.0+

### Core Architecture Pattern
The app follows a role-based dashboard architecture where users see different interfaces based on their assigned role:

1. **Authentication Flow**: Users log in via WeChat ID → Role assignment → Role-specific dashboard
2. **Data Layer**: SwiftData models with relationships managed through `ModelContext`
3. **Service Layer**: Services handle business logic (AuthenticationService, DataInitializationService, etc.)
4. **View Layer**: SwiftUI views organized by user role in separate folders

### Key Models and Relationships
- **User**: Core user model with role-based access control
- **Customer/Product**: Business entities with one-to-many relationships  
- **CustomerOutOfStock**: Links customers and products with priority tracking
- **Production Models**: WorkshopProduction, EVAGranulation, WorkshopIssue for manufacturing workflow

### Role-Based Access System
Six distinct user roles with dedicated dashboard views:
- **Salesperson**: Customer/product management, out-of-stock tracking
- **Warehouse Keeper**: Production style and inventory management  
- **Workshop Manager**: Production status and equipment monitoring
- **EVA Granulation Technician**: Raw material tracking and granulation records
- **Workshop Technician**: Equipment maintenance and issue reporting
- **Administrator**: Full system access and user management

### Data Initialization
- Uses in-memory storage (`isStoredInMemoryOnly: true`) for development
- Sample data automatically initialized on app launch via `DataInitializationService`
- Clear/reinitialize capability available for testing

### File Organization
```
Lopan/
├── Models/           # SwiftData models
├── Services/         # Business logic services  
├── Views/           # SwiftUI views organized by role
│   ├── Administrator/
│   ├── Salesperson/
│   └── Components/   # Reusable UI components
├── Utils/           # Helper utilities
└── Configuration/   # App configuration
```

### Development Notes
- Currently uses demo/sample data for development
- WeChat integration is simulated (not actual WeChat SDK)
- Database relationships managed through SwiftData with proper cascade handling
- All UI text in Chinese for Chinese manufacturing environment