/// A predicate for filtering user agents based on their characteristics.
///
/// Predicates can be combined using logical operators (`&&`, `||`, `!`) to create complex filtering criteria.
///
/// ## Usage
///
/// Use predicates to filter user agents by browser, device, platform, or operating system:
///
/// ```swift
/// // Filter by device type
/// let mobile = try await UserAgent.random(matching: .mobile)
/// let desktop = try await UserAgent.random(matching: .desktop)
///
/// // Filter by browser
/// let chrome = try await UserAgent.random(matching: .browser(.chrome))
///
/// // Combine predicates
/// let chromeMobile = try await UserAgent.random(matching: .browser(.chrome) && .mobile)
/// let windowsOrMac = try await UserAgent.random(matching: .platform("Win32") || .platform("MacIntel"))
///
/// // Negate predicates
/// let notSafari = try await UserAgent.random(matching: !.browser(.safari))
///
/// // Custom filtering
/// let modernBrowsers = try await UserAgent.random(matching: .custom { entry in
///     entry.browser.version >= Version("100.0")!
/// })
/// ```
///
/// ## Topics
///
/// ### Device Type Predicates
///
/// - ``mobile``
/// - ``desktop``
/// - ``tablet``
///
/// ### Specific Criteria
///
/// - ``browser(_:)``
/// - ``device(_:)``
/// - ``platform(_:)``
/// - ``os(_:)``
/// - ``custom(_:)``
///
/// ### Logical Operations
///
/// - ``&&(_:_:)``
/// - ``||(_:_:)``
/// - ``!(_:)``
public indirect enum Predicate: Sendable {
    /// Matches user agents from a specific browser.
    ///
    /// - Parameter kind: The browser kind to match.
    case browser(Browser.Kind)

    /// Matches user agents from a specific device category.
    ///
    /// - Parameter category: The device category to match.
    case device(Device.Category)

    /// Matches user agents from a specific platform.
    ///
    /// Platform matching is case-insensitive.
    ///
    /// - Parameter platform: The platform name to match (e.g., `"MacIntel"`, `"Win32"`, `"Linux x86_64"`, `"Linux armv81"`).
    case platform(String)

    /// Matches user agents from a specific operating system.
    ///
    /// OS matching is case-insensitive and performs a substring search.
    ///
    /// See: MDN Navigator.oscpu — `https://developer.mozilla.org/en-US/docs/Web/API/Navigator/oscpu`
    ///
    /// - Parameter name: The OS name to match (e.g., `"Windows"`, `"iOS"`, `"Android"`).
    case os(String)

    /// Matches user agents from a specific vendor.
    ///
    /// Vendor matching is case-insensitive.
    ///
    /// - Parameter name: The vendor name to match (e.g., `"Google Inc."`, `"Apple Computer, Inc."`).
    case vendor(String)

    /// Matches user agents with a specific screen size.
    ///
    /// - Parameter size: The screen size to match.
    case screenSize(Size)

    /// Matches user agents with a specific viewport size.
    ///
    /// - Parameter size: The viewport size to match.
    case viewportSize(Size)

    /// Matches user agents with a specific connection type.
    ///
    /// Connection type matching is case-insensitive.
    ///
    /// - Parameter effectiveType: The effective connection type to match (e.g., `"4g"`, `"3g"`, `"2g"`, `"slow-2g"`).
    case connectionType(String)

    /// Matches user agents where both predicates are true (logical AND).
    ///
    /// - Parameters:
    ///   - lhs: The left-hand predicate.
    ///   - rhs: The right-hand predicate.
    case and(Predicate, Predicate)

    /// Matches user agents where either predicate is true (logical OR).
    ///
    /// - Parameters:
    ///   - lhs: The left-hand predicate.
    ///   - rhs: The right-hand predicate.
    case or(Predicate, Predicate)

    /// Matches user agents where the predicate is false (logical NOT).
    ///
    /// - Parameter predicate: The predicate to negate.
    case not(Predicate)

    /// Matches user agents using a custom filtering function.
    ///
    /// The custom closure receives the full entry for evaluation.
    ///
    /// - Parameter filter: A closure that returns `true` if the user agent should match.
    case custom(@Sendable (_ entry: Entry) -> Bool)

    /// A predicate that matches mobile devices.
    public static var mobile: Predicate { .device(.mobile) }

    /// A predicate that matches desktop computers.
    public static var desktop: Predicate { .device(.desktop) }

    /// A predicate that matches tablet devices.
    public static var tablet: Predicate { .device(.tablet) }

    /// Combines two predicates with a logical AND operation.
    ///
    /// - Parameters:
    ///   - lhs: The left-hand predicate.
    ///   - rhs: The right-hand predicate.
    /// - Returns: A predicate that matches when both operands match.
    public static func && (lhs: Predicate, rhs: Predicate) -> Predicate {
        .and(lhs, rhs)
    }

    /// Combines two predicates with a logical OR operation.
    ///
    /// - Parameters:
    ///   - lhs: The left-hand predicate.
    ///   - rhs: The right-hand predicate.
    /// - Returns: A predicate that matches when either operand matches.
    public static func || (lhs: Predicate, rhs: Predicate) -> Predicate {
        .or(lhs, rhs)
    }

    /// Negates a predicate with a logical NOT operation.
    ///
    /// - Parameter predicate: The predicate to negate.
    /// - Returns: A predicate that matches when the operand does not match.
    public static prefix func ! (predicate: Predicate) -> Predicate {
        .not(predicate)
    }

    /// Evaluates whether an entry matches this predicate.
    ///
    /// - Parameter entry: The entry to evaluate.
    /// - Returns: `true` if the entry matches the predicate; otherwise, `false`.
    func matches(_ entry: Entry) -> Bool {
        switch self {
        case .browser(let kind):
            return entry.browser.kind == kind
        case .platform(let name):
            return entry.platform.lowercased() == name.lowercased()
        case .os(let name):
            return entry.os.name?.lowercased().contains(name.lowercased()) ?? false
        case .vendor(let name):
            return entry.vendor?.lowercased() == name.lowercased()
        case .screenSize(let size):
            return entry.screenSize == size
        case .viewportSize(let size):
            return entry.viewportSize == size
        case .connectionType(let type):
            return entry.connection?.effectiveType?.lowercased() == type.lowercased()
        case .device(let device):
            return entry.device.category == device
        case .and(let lhs, let rhs):
            return lhs.matches(entry) && rhs.matches(entry)
        case .or(let lhs, let rhs):
            return lhs.matches(entry) || rhs.matches(entry)
        case .not(let predicate):
            return !predicate.matches(entry)
        case .custom(let filter):
            return filter(entry)
        }
    }
}
