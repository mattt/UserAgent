import Foundation

/// Errors that can occur when generating user agent strings.
///
/// `UserAgentError` represents various failure conditions that may occur during user agent generation,
/// including issues with loading browser data or filtering results.
public enum UserAgentError: Error, CaseIterable, Sendable {
    /// The browser data resource file could not be found in the bundle.
    ///
    /// This typically indicates a packaging or installation issue.
    case resourceNotFound

    /// Failed to decompress the browser data file.
    ///
    /// The compressed browser data could not be decompressed, possibly due to file corruption.
    case decompessionFailed

    /// The browser data is corrupted or cannot be parsed.
    ///
    /// This error occurs when the data format is invalid or the file has been corrupted.
    case dataCorrupted

    /// No user agents match the specified criteria.
    ///
    /// This error is thrown when a predicate filters out all available user agents,
    /// or when the browser data is empty.
    case noBrowsersAvailable

    /// The browser data format is invalid or malformed.
    ///
    /// This error occurs during parsing when the data does not conform to the expected format.
    case invalidData
}

// MARK: - LocalizedError

extension UserAgentError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .resourceNotFound:
            return "Browser data resource file not found in bundle"
        case .decompessionFailed:
            return "Failed to decompress browser data"
        case .dataCorrupted:
            return "Browser data is corrupted or invalid"
        case .noBrowsersAvailable:
            return "No user agents available"
        case .invalidData:
            return "Invalid or malformed browser data"
        }
    }
}
