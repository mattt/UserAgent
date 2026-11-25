import Foundation

/// An entry representing a user agent record with associated metadata.
///
/// Each entry contains a user agent string along with parsed information about
/// the browser, device, operating system, and platform.
public struct Entry: Hashable, Sendable {
    /// The complete user agent string.
    public let userAgent: String

    /// The usage percentage of this user agent in real-world traffic.
    public let percent: Double

    /// The device information for this user agent.
    public let device: Device

    /// The browser information for this user agent.
    public let browser: Browser

    /// The operating system information for this user agent.
    public let os: OS

    /// The platform identifier for this user agent.
    public let platform: String

    /// The `navigator.appName` value.
    public let appName: String?

    /// Network connection information.
    public let connection: Connection?

    /// The `navigator.cpuClass` value.
    public let cpuClass: String?

    /// The `navigator.vendor` value.
    public let vendor: String?

    /// The number of plugins (`navigator.plugins.length`).
    public let pluginsLength: Int?

    /// The screen size in pixels (`screen.width` × `screen.height`).
    public let screenSize: Size?

    /// The viewport size in pixels (`window.innerWidth` × `window.innerHeight`).
    public let viewportSize: Size?

    /// Network connection information.
    public struct Connection: Hashable, Sendable {
        /// The current downlink in megabits per second.
        public let downlink: Double?

        /// The effective connection type (e.g., '4g', '3g').
        public let effectiveType: String?

        /// The round-trip time in milliseconds.
        public let rtt: Int?
    }
}

// MARK: -

/// Represents a version number.
public struct Version: Hashable, Sendable, Comparable {
    /// The full version string.
    ///
    /// For example: `"121.0.6167.85"` or `"17.2.1"`.
    public let string: String

    /// The major version number.
    public let major: Int

    /// The minor version number.
    public let minor: Int

    /// Creates a version by parsing a version string.
    ///
    /// The string is split by periods,
    /// and the first two components are parsed as major and minor version numbers.
    /// If parsing fails or the string doesn't contain valid version numbers,
    /// then it returns `nil`.
    ///
    /// - Parameter string: A version string like `"121.0.6167.85"` or `"17.2"`.
    /// - Returns: A `Version` instance, or `nil` if parsing fails.
    ///
    /// ## Examples
    ///
    /// ```swift
    /// Version("121.0.6167.85") // Version(major: 121, minor: 0)
    /// Version("17.2.1")        // Version(major: 17, minor: 2)
    /// Version("100")           // Version(major: 100, minor: 0)
    /// Version("invalid")       // nil
    /// ```
    public init?(_ string: String) {
        let components = string.split(separator: ".").map(String.init)
        guard let major = components.first.flatMap(Int.init) else {
            return nil
        }

        let minor = components.count > 1 ? (Int(components[1]) ?? 0) : 0

        self.string = string
        self.major = major
        self.minor = minor
    }

    /// Compares two versions for ordering.
    ///
    /// Versions are compared first by major version, then by minor version.
    public static func < (lhs: Version, rhs: Version) -> Bool {
        if lhs.major != rhs.major {
            return lhs.major < rhs.major
        }
        return lhs.minor < rhs.minor
    }
}

// MARK: -

/// Information about a web browser.
///
/// A `Browser` represents metadata about a specific web browser, including its type and version information.
public struct Browser: Hashable, Sendable {
    /// The kind of browser.
    ///
    /// Represents the major browser vendors supported by this library.
    public enum Kind: String, Hashable, Sendable, CaseIterable {
        /// Google Chrome browser
        case chrome

        /// Mozilla Firefox browser
        case firefox

        /// Apple Safari browser
        case safari

        /// Microsoft Edge browser
        case edge

        /// Opera browser
        case opera

        /// Returns a random browser kind.
        ///
        /// - Returns: A randomly selected browser kind from all available cases.
        public static func random() -> Kind {
            allCases.randomElement()!
        }
    }
    /// The kind of browser (Chrome, Firefox, Safari, etc.).
    public let kind: Kind

    /// The version of the browser.
    public let version: Version
}

// MARK: -

/// Represents dimensions in pixels.
public struct Size: Hashable, Sendable {
    /// The width in pixels.
    public let width: Int

    /// The height in pixels.
    public let height: Int
}

// MARK: -

/// Information about a device type.
///
/// A `Device` categorizes the type of device associated with a user agent.
public struct Device: Hashable, Codable, Sendable {
    /// The category of device.
    ///
    /// Represents the primary device form factors.
    public enum Category: String, CaseIterable, Hashable, Codable, Sendable {
        /// Desktop or laptop computers
        case desktop

        /// Mobile phones
        case mobile

        /// Tablet devices
        case tablet
    }

    /// The category of this device.
    public let category: Category
}

// MARK: -

/// Information about an operating system.
///
/// An `OS` contains metadata about the operating system associated with a user agent.
public struct OS: Hashable, Sendable {
    /// The name of the operating system.
    ///
    /// For example: `"Windows"`, `"macOS"`, `"iOS"`, or `"Android"`.
    /// This property may be `nil` if the operating system cannot be determined.
    public let name: String?

    /// The version of the operating system.
    ///
    /// For example: `Version("10.0")` for Windows 10 or `Version("17.2")` for iOS 17.2.
    /// This property may be `nil` if the version cannot be determined or parsed.
    public let version: Version?

    /// The brand of the device manufacturer.
    ///
    /// For example: `"Samsung"`, `"Google"`, or `"Apple"`.
    /// This property is typically set for mobile devices and may be `nil` for desktop operating systems.
    public let deviceBrand: String?

    /// The `navigator.oscpu` value.
    ///
    /// For example: `"Windows NT 10.0; Win64; x64"` or `"Intel Mac OS X 10_15_7"`.
    /// This property may be `nil` if not available.
    public let oscpu: String?
}

// MARK: - Decodable

extension Entry: Decodable {
    enum CodingKeys: String, CodingKey {
        case userAgent = "user_agent"
        case percent
        case type
        case browser
        case browserVersion = "browser_version"
        case browserVersionMajorMinor = "browser_version_major_minor"
        case os
        case osVersion = "os_version"
        case oscpu
        case deviceBrand = "device_brand"
        case platform
        case appName = "app_name"
        case connection
        case cpuClass = "cpu_class"
        case vendor
        case pluginsLength = "plugins_length"
        case screenHeight = "screen_height"
        case screenWidth = "screen_width"
        case viewportHeight = "viewport_height"
        case viewportWidth = "viewport_width"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        userAgent = try container.decode(String.self, forKey: .userAgent)
        percent = try container.decode(Double.self, forKey: .percent)
        let rawType = try container.decode(String.self, forKey: .type)
        switch rawType.lowercased() {
        case "desktop":
            device = Device(category: .desktop)
        case "mobile":
            device = Device(category: .mobile)
        case "tablet":
            device = Device(category: .tablet)
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Invalid device category: \(rawType)"
            )
        }
        platform = try container.decode(String.self, forKey: .platform)

        let browserName = try container.decode(String.self, forKey: .browser)
        let browserVersionString = try container.decode(String.self, forKey: .browserVersion)
        _ = try container.decode(Double.self, forKey: .browserVersionMajorMinor)

        let normalizedBrowserName = browserName.lowercased().replacingOccurrences(
            of: " ",
            with: "_"
        )
        let browserKind: Browser.Kind?
        if normalizedBrowserName == "mobile_safari" {
            browserKind = .safari
        } else {
            browserKind = Browser.Kind(rawValue: normalizedBrowserName)
        }
        guard let browserKind else {
            throw DecodingError.dataCorruptedError(
                forKey: .browser,
                in: container,
                debugDescription: "Invalid browser: \(browserName)"
            )
        }

        guard let version = Version(browserVersionString) else {
            throw DecodingError.dataCorruptedError(
                forKey: .browserVersion,
                in: container,
                debugDescription: "Invalid browser version: \(browserVersionString)"
            )
        }

        browser = Browser(kind: browserKind, version: version)

        let osName = try container.decodeIfPresent(String.self, forKey: .os)
        let osVersionString = try container.decodeIfPresent(String.self, forKey: .osVersion)
        let osVersion = osVersionString.flatMap(Version.init)
        let oscpu = try container.decodeIfPresent(String.self, forKey: .oscpu)
        let deviceBrand = try container.decodeIfPresent(String.self, forKey: .deviceBrand)

        os = OS(name: osName, version: osVersion, deviceBrand: deviceBrand, oscpu: oscpu)

        appName = try container.decodeIfPresent(String.self, forKey: .appName)
        connection = try container.decodeIfPresent(Connection.self, forKey: .connection)
        cpuClass = try container.decodeIfPresent(String.self, forKey: .cpuClass)
        vendor = try container.decodeIfPresent(String.self, forKey: .vendor)
        pluginsLength = try container.decodeIfPresent(Int.self, forKey: .pluginsLength)

        let screenWidth = try container.decodeIfPresent(Int.self, forKey: .screenWidth)
        let screenHeight = try container.decodeIfPresent(Int.self, forKey: .screenHeight)
        if let width = screenWidth, let height = screenHeight {
            screenSize = Size(width: width, height: height)
        } else {
            screenSize = nil
        }

        let viewportWidth = try container.decodeIfPresent(Int.self, forKey: .viewportWidth)
        let viewportHeight = try container.decodeIfPresent(Int.self, forKey: .viewportHeight)
        if let width = viewportWidth, let height = viewportHeight {
            viewportSize = Size(width: width, height: height)
        } else {
            viewportSize = nil
        }
    }
}

extension Entry.Connection: Decodable {
    enum CodingKeys: String, CodingKey {
        case downlink
        case effectiveType = "effective_type"
        case rtt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        downlink = try container.decodeIfPresent(Double.self, forKey: .downlink)
        effectiveType = try container.decodeIfPresent(String.self, forKey: .effectiveType)
        rtt = try container.decodeIfPresent(Int.self, forKey: .rtt)
    }
}
