#import <Foundation/Foundation.h>

#if __has_attribute(swift_private)
#define AC_SWIFT_PRIVATE __attribute__((swift_private))
#else
#define AC_SWIFT_PRIVATE
#endif

/// The resource bundle ID.
static NSString * const ACBundleID AC_SWIFT_PRIVATE = @"com.lopanng.Lopan";

/// The "BrandPrimary" asset catalog color resource.
static NSString * const ACColorNameBrandPrimary AC_SWIFT_PRIVATE = @"BrandPrimary";

/// The "Error" asset catalog color resource.
static NSString * const ACColorNameError AC_SWIFT_PRIVATE = @"Error";

/// The "Success" asset catalog color resource.
static NSString * const ACColorNameSuccess AC_SWIFT_PRIVATE = @"Success";

/// The "Warning" asset catalog color resource.
static NSString * const ACColorNameWarning AC_SWIFT_PRIVATE = @"Warning";

#undef AC_SWIFT_PRIVATE
