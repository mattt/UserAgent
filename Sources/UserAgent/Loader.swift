import Compression
import Foundation

/// An actor responsible for loading and parsing user agent data from bundled resources.
///
/// `Loader` handles decompression of LZFSE-compressed browser data and parses JSON Lines format into structured entries.
/// The loaded data is cached to avoid redundant I/O operations.
actor Loader {
    private var cachedData: [Entry]?

    /// Loads user agent entries from the bundled resource file.
    ///
    /// This method decompresses and parses the browser data file on first call,
    /// then caches the result for subsequent calls.
    ///
    /// - Returns: An array of parsed user agent entries.
    /// - Throws: ``UserAgentError/resourceNotFound`` if the data file is missing,
    ///           ``UserAgentError/decompressedFailed`` if decompression fails,
    ///           ``UserAgentError/invalidData`` if the data format is invalid, or
    ///           ``UserAgentError/dataCorrupted`` if no valid entries are found.
    func loadData() async throws -> [Entry] {
        if let cached = cachedData {
            return cached
        }

        guard let url = Bundle.module.url(forResource: "browsers", withExtension: "jsonl.lzfse")
        else {
            throw UserAgentError.resourceNotFound
        }

        let compressedData = try Data(contentsOf: url)

        guard let decompressedData = decompress(compressedData) else {
            throw UserAgentError.decompessionFailed
        }

        let entries = try parseJSONLines(decompressedData)

        cachedData = entries
        return entries
    }

    /// Decompresses LZFSE-compressed data.
    ///
    /// - Parameter data: The compressed data to decompress.
    /// - Returns: The decompressed data, or `nil` if decompression fails.
    private func decompress(_ data: Data) -> Data? {
        let destinationBufferSize = data.count * 42
        var destinationBuffer = Data(count: destinationBufferSize)

        let decompressedSize = data.withUnsafeBytes { srcPtr -> Int in
            destinationBuffer.withUnsafeMutableBytes { destPtr in
                compression_decode_buffer(
                    destPtr.baseAddress!.assumingMemoryBound(to: UInt8.self),
                    destinationBufferSize,
                    srcPtr.baseAddress!.assumingMemoryBound(to: UInt8.self),
                    data.count,
                    nil,
                    COMPRESSION_LZFSE
                )
            }
        }

        guard decompressedSize > 0 else {
            return nil
        }

        return destinationBuffer.prefix(decompressedSize)
    }

    /// Parses JSON Lines format data into user agent entries.
    ///
    /// Each line is expected to be a separate JSON object representing one user agent entry.
    /// Invalid lines are skipped, but if no valid entries are found, an error is thrown.
    ///
    /// - Parameter data: The data containing newline-delimited JSON objects.
    /// - Returns: An array of successfully parsed entries.
    /// - Throws: ``UserAgentError/invalidData`` if the data cannot be decoded as UTF-8,
    ///           or ``UserAgentError/dataCorrupted`` if no valid entries are found.
    private func parseJSONLines(_ data: Data) throws -> [Entry] {
        guard let text = String(data: data, encoding: .utf8) else {
            throw UserAgentError.invalidData
        }

        let decoder = JSONDecoder()
        var entries: [Entry] = []

        for line in text.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            guard let lineData = trimmed.data(using: .utf8) else {
                continue
            }

            do {
                let entry = try decoder.decode(Entry.self, from: lineData)
                entries.append(entry)
            } catch {
                continue
            }
        }

        guard !entries.isEmpty else {
            throw UserAgentError.dataCorrupted
        }

        return entries
    }
}
