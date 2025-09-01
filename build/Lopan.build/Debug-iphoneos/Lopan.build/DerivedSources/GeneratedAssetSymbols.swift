import Foundation
#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif
#if canImport(SwiftUI)
import SwiftUI
#endif
#if canImport(DeveloperToolsSupport)
import DeveloperToolsSupport
#endif

#if SWIFT_PACKAGE
private let resourceBundle = Foundation.Bundle.module
#else
private class ResourceBundleClass {}
private let resourceBundle = Foundation.Bundle(for: ResourceBundleClass.self)
#endif

// MARK: - Color Symbols -

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension DeveloperToolsSupport.ColorResource {

    /// The "BrandPrimary" asset catalog color resource.
    static let brandPrimary = DeveloperToolsSupport.ColorResource(name: "BrandPrimary", bundle: resourceBundle)

    /// The "Error" asset catalog color resource.
    static let error = DeveloperToolsSupport.ColorResource(name: "Error", bundle: resourceBundle)

    /// The "Success" asset catalog color resource.
    static let success = DeveloperToolsSupport.ColorResource(name: "Success", bundle: resourceBundle)

    /// The "Warning" asset catalog color resource.
    static let warning = DeveloperToolsSupport.ColorResource(name: "Warning", bundle: resourceBundle)

}

// MARK: - Image Symbols -

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension DeveloperToolsSupport.ImageResource {

}

// MARK: - Color Symbol Extensions -

#if canImport(AppKit)
@available(macOS 14.0, *)
@available(macCatalyst, unavailable)
extension AppKit.NSColor {

    /// The "BrandPrimary" asset catalog color.
    static var brandPrimary: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
        .init(resource: .brandPrimary)
#else
        .init()
#endif
    }

    /// The "Error" asset catalog color.
    static var error: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
        .init(resource: .error)
#else
        .init()
#endif
    }

    /// The "Success" asset catalog color.
    static var success: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
        .init(resource: .success)
#else
        .init()
#endif
    }

    /// The "Warning" asset catalog color.
    static var warning: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
        .init(resource: .warning)
#else
        .init()
#endif
    }

}
#endif

#if canImport(UIKit)
@available(iOS 17.0, tvOS 17.0, *)
@available(watchOS, unavailable)
extension UIKit.UIColor {

    /// The "BrandPrimary" asset catalog color.
    static var brandPrimary: UIKit.UIColor {
#if !os(watchOS)
        .init(resource: .brandPrimary)
#else
        .init()
#endif
    }

    /// The "Error" asset catalog color.
    static var error: UIKit.UIColor {
#if !os(watchOS)
        .init(resource: .error)
#else
        .init()
#endif
    }

    /// The "Success" asset catalog color.
    static var success: UIKit.UIColor {
#if !os(watchOS)
        .init(resource: .success)
#else
        .init()
#endif
    }

    /// The "Warning" asset catalog color.
    static var warning: UIKit.UIColor {
#if !os(watchOS)
        .init(resource: .warning)
#else
        .init()
#endif
    }

}
#endif

#if canImport(SwiftUI)
@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension SwiftUI.Color {

    /// The "BrandPrimary" asset catalog color.
    static var brandPrimary: SwiftUI.Color { .init(.brandPrimary) }

    /// The "Error" asset catalog color.
    static var error: SwiftUI.Color { .init(.error) }

    /// The "Success" asset catalog color.
    static var success: SwiftUI.Color { .init(.success) }

    /// The "Warning" asset catalog color.
    static var warning: SwiftUI.Color { .init(.warning) }

}

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension SwiftUI.ShapeStyle where Self == SwiftUI.Color {

    /// The "BrandPrimary" asset catalog color.
    static var brandPrimary: SwiftUI.Color { .init(.brandPrimary) }

    /// The "Error" asset catalog color.
    static var error: SwiftUI.Color { .init(.error) }

    /// The "Success" asset catalog color.
    static var success: SwiftUI.Color { .init(.success) }

    /// The "Warning" asset catalog color.
    static var warning: SwiftUI.Color { .init(.warning) }

}
#endif

// MARK: - Image Symbol Extensions -

#if canImport(AppKit)
@available(macOS 14.0, *)
@available(macCatalyst, unavailable)
extension AppKit.NSImage {

}
#endif

#if canImport(UIKit)
@available(iOS 17.0, tvOS 17.0, *)
@available(watchOS, unavailable)
extension UIKit.UIImage {

}
#endif

// MARK: - Thinnable Asset Support -

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
@available(watchOS, unavailable)
extension DeveloperToolsSupport.ColorResource {

    private init?(thinnableName: Swift.String, bundle: Foundation.Bundle) {
#if canImport(AppKit) && os(macOS)
        if AppKit.NSColor(named: NSColor.Name(thinnableName), bundle: bundle) != nil {
            self.init(name: thinnableName, bundle: bundle)
        } else {
            return nil
        }
#elseif canImport(UIKit) && !os(watchOS)
        if UIKit.UIColor(named: thinnableName, in: bundle, compatibleWith: nil) != nil {
            self.init(name: thinnableName, bundle: bundle)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}

#if canImport(AppKit)
@available(macOS 14.0, *)
@available(macCatalyst, unavailable)
extension AppKit.NSColor {

    private convenience init?(thinnableResource: DeveloperToolsSupport.ColorResource?) {
#if !targetEnvironment(macCatalyst)
        if let resource = thinnableResource {
            self.init(resource: resource)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}
#endif

#if canImport(UIKit)
@available(iOS 17.0, tvOS 17.0, *)
@available(watchOS, unavailable)
extension UIKit.UIColor {

    private convenience init?(thinnableResource: DeveloperToolsSupport.ColorResource?) {
#if !os(watchOS)
        if let resource = thinnableResource {
            self.init(resource: resource)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}
#endif

#if canImport(SwiftUI)
@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension SwiftUI.Color {

    private init?(thinnableResource: DeveloperToolsSupport.ColorResource?) {
        if let resource = thinnableResource {
            self.init(resource)
        } else {
            return nil
        }
    }

}

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension SwiftUI.ShapeStyle where Self == SwiftUI.Color {

    private init?(thinnableResource: DeveloperToolsSupport.ColorResource?) {
        if let resource = thinnableResource {
            self.init(resource)
        } else {
            return nil
        }
    }

}
#endif

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
@available(watchOS, unavailable)
extension DeveloperToolsSupport.ImageResource {

    private init?(thinnableName: Swift.String, bundle: Foundation.Bundle) {
#if canImport(AppKit) && os(macOS)
        if bundle.image(forResource: NSImage.Name(thinnableName)) != nil {
            self.init(name: thinnableName, bundle: bundle)
        } else {
            return nil
        }
#elseif canImport(UIKit) && !os(watchOS)
        if UIKit.UIImage(named: thinnableName, in: bundle, compatibleWith: nil) != nil {
            self.init(name: thinnableName, bundle: bundle)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}

#if canImport(UIKit)
@available(iOS 17.0, tvOS 17.0, *)
@available(watchOS, unavailable)
extension UIKit.UIImage {

    private convenience init?(thinnableResource: DeveloperToolsSupport.ImageResource?) {
#if !os(watchOS)
        if let resource = thinnableResource {
            self.init(resource: resource)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}
#endif

