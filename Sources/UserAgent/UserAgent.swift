import Foundation

/// A namespace for generating random browser user agent strings.
///
/// `UserAgent` provides methods to generate realistic user agent strings based on real-world browser usage data.
/// User agent strings can be filtered using predicates to match specific browsers, devices, platforms, or operating systems.
///
/// ## Usage
///
/// Generate a random user agent:
///
/// ```swift
/// let userAgent = try await UserAgent.random()
/// // "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36..."
/// ```
///
/// Generate a user agent matching specific criteria:
///
/// ```swift
/// let mobileUserAgent = try await UserAgent.random(matching: .mobile)
/// let chromeOnWindows = try await UserAgent.random(matching: .browser(.chrome) && .platform("Windows"))
/// ```
///
/// Generate multiple user agents:
///
/// ```swift
/// let userAgents = try await UserAgent.randomSample(count: 10, matching: .desktop)
/// ```
///
/// ## Topics
///
/// ### Generating User Agents
///
/// - ``random()``
/// - ``random(matching:)``
///
/// ### Generating Multiple User Agents
///
/// - ``randomSample(count:)``
/// - ``randomSample(count:matching:)``
public enum UserAgent {
    private static let store = Store()

    /// Returns a random user agent string.
    ///
    /// - Returns: A randomly selected user agent string from the available pool.
    /// - Throws: ``UserAgentError/noBrowsersAvailable`` if no user agents are available.
    public static func random() async throws -> String {
        try await store.random(matching: nil)
    }

    /// Returns a random user agent string matching the specified criteria.
    ///
    /// - Parameter predicate: A ``Predicate`` that filters which user agents can be selected.
    /// - Returns: A randomly selected user agent string matching the predicate.
    /// - Throws: ``UserAgentError/noBrowsersAvailable`` if no user agents match the predicate.
    public static func random(matching predicate: Predicate) async throws -> String {
        try await store.random(matching: predicate)
    }

    /// Returns an array of random user agent strings.
    ///
    /// The same user agent may appear multiple times in the result.
    ///
    /// - Parameter count: The number of user agent strings to generate.
    /// - Returns: An array of randomly selected user agent strings.
    /// - Throws: ``UserAgentError/noBrowsersAvailable`` if no user agents are available.
    public static func randomSample(count: Int) async throws -> [String] {
        try await store.randomSample(count: count, matching: nil)
    }

    /// Returns an array of random user agent strings matching the specified criteria.
    ///
    /// The same user agent may appear multiple times in the result.
    ///
    /// - Parameters:
    ///   - count: The number of user agent strings to generate.
    ///   - predicate: A ``Predicate`` that filters which user agents can be selected.
    /// - Returns: An array of randomly selected user agent strings matching the predicate.
    /// - Throws: ``UserAgentError/noBrowsersAvailable`` if no user agents match the predicate.
    public static func randomSample(
        count: Int,
        matching predicate: Predicate
    ) async throws -> [String] {
        try await store.randomSample(count: count, matching: predicate)
    }
}
