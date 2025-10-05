import Compression
import Foundation
import zlib

#if canImport(PackagePlugin)
    import PackagePlugin

    @main
    struct UpdateBrowserDataPlugin: CommandPlugin {
        func performCommand(context: PluginContext, arguments: [String]) async throws {
            print("🔄 Updating browser user agent data...")

            // Default source URL from intoli/user-agents
            let sourceURL =
                "https://raw.githubusercontent.com/intoli/user-agents/main/src/user-agents.json.gz"

            // Download the data
            print("📥 Downloading from: \(sourceURL)")
            let rawData = try await downloadData(from: sourceURL)
            print("✓ Downloaded \(rawData.count) bytes")

            // Decompress gzip if needed
            print("📦 Decompressing gzip data...")
            let jsonData = try decompressGzip(rawData)
            print("✓ Decompressed to \(jsonData.count) bytes")

            // Process to JSONL
            print("⚙️  Processing browser data...")
            let jsonlData = try await processToJSONL(jsonData)
            print("✓ Processed \(jsonlData.count) bytes")

            // Compress with LZFSE
            print("🗜️  Compressing data with LZFSE...")
            let compressedData = try compressLZFSE(jsonlData)
            let ratio = Double(jsonlData.count) / Double(compressedData.count)
            print(
                "✓ Compressed to \(compressedData.count) bytes (ratio: \(String(format: "%.2f", ratio))x)"
            )

            // Write to package resources
            let resourcesURL = context.package.directoryURL
                .appendingPathComponent("Sources")
                .appendingPathComponent("UserAgent")
                .appendingPathComponent("Resources")

            // Create directory if needed
            try FileManager.default.createDirectory(
                at: resourcesURL,
                withIntermediateDirectories: true
            )

            let outputURL = resourcesURL.appendingPathComponent("browsers.jsonl.lzfse")
            try compressedData.write(to: outputURL)

            print("✅ Successfully wrote \(outputURL.path)")
            print("🎉 Browser data update complete!")
        }

        // MARK: - Private Methods

        private func downloadData(from urlString: String) async throws -> Data {
            guard let url = URL(string: urlString) else {
                throw PluginError.invalidURL(urlString)
            }

            // Use an ephemeral session to avoid persistent caches/SQL DB logs
            let config = URLSessionConfiguration.ephemeral
            config.requestCachePolicy = .reloadIgnoringLocalCacheData
            let session = URLSession(configuration: config)
            let (data, response) = try await session.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw PluginError.invalidResponse
            }

            guard (200 ... 299).contains(httpResponse.statusCode) else {
                throw PluginError.httpError(httpResponse.statusCode)
            }

            return data
        }

        private func decompressGzip(_ data: Data) throws -> Data {
            // Use zlib inflate with windowBits=47 to accept gzip or zlib headers
            var stream = z_stream()
            let initResult = inflateInit2_(
                &stream,
                47,
                ZLIB_VERSION,
                Int32(MemoryLayout<z_stream>.size)
            )
            guard initResult == Z_OK else { throw PluginError.decompressionFailed }

            defer { inflateEnd(&stream) }

            var output = Data()
            let chunkSize = 64 * 1024

            return try data.withUnsafeBytes { (srcPtr: UnsafeRawBufferPointer) -> Data in
                guard let baseAddress = srcPtr.baseAddress?.assumingMemoryBound(to: Bytef.self)
                else {
                    throw PluginError.decompressionFailed
                }
                stream.next_in = UnsafeMutablePointer<Bytef>(mutating: baseAddress)
                stream.avail_in = uInt(data.count)

                while true {
                    var buffer = Data(count: chunkSize)
                    let written: Int = buffer.withUnsafeMutableBytes { destPtr in
                        stream.next_out = destPtr.baseAddress?.assumingMemoryBound(to: Bytef.self)
                        stream.avail_out = uInt(chunkSize)
                        let status = inflate(&stream, Z_NO_FLUSH)
                        let produced = chunkSize - Int(stream.avail_out)
                        switch status {
                        case Z_OK, Z_BUF_ERROR:
                            return produced
                        case Z_STREAM_END:
                            return produced | (1 << 30)  // mark end-of-stream
                        default:
                            return -1
                        }
                    }

                    if written < 0 { throw PluginError.decompressionFailed }

                    let isEnd = (written & (1 << 30)) != 0
                    let produced = isEnd ? (written & ~(1 << 30)) : written
                    if produced > 0 {
                        buffer.count = produced
                        output.append(buffer)
                    }
                    if isEnd { break }

                    if produced == 0 && stream.avail_in == 0 {
                        // Nothing more to produce and no input left
                        break
                    }
                }

                return output
            }
        }

        private func processToJSONL(_ data: Data) async throws -> Data {
            let decoder = JSONDecoder()
            let sourceItems = try decoder.decode([SourceItem].self, from: data)

            print("📊 Processing \(sourceItems.count) user agents...")

            // Process items and parse user agents
            var processedItems: [BrowserUserAgentData] = []
            for (index, item) in sourceItems.enumerated() {
                if index % 1000 == 0 && index > 0 {
                    print("   Processed \(index)/\(sourceItems.count)...")
                }

                if let processed = try parseUserAgent(item) {
                    processedItems.append(processed)
                }
            }

            print("✓ Successfully processed \(processedItems.count) user agents")

            // Convert to JSONL
            let encoder = JSONEncoder()
            encoder.outputFormatting = .sortedKeys

            var jsonlLines: [String] = []
            for item in processedItems {
                let jsonData = try encoder.encode(item)
                if let jsonString = String(data: jsonData, encoding: .utf8) {
                    jsonlLines.append(jsonString)
                }
            }

            let jsonlString = jsonlLines.joined(separator: "\n")
            guard let jsonlData = jsonlString.data(using: .utf8) else {
                throw PluginError.conversionFailed
            }

            return jsonlData
        }

        private func parseUserAgent(_ item: SourceItem) throws -> BrowserUserAgentData? {
            // Parse user agent string using a simple regex-based parser
            let ua = item.userAgent

            // Extract browser info
            guard let browserInfo = extractBrowserInfo(from: ua) else {
                return nil
            }

            // Extract OS info
            let osInfo = extractOSInfo(from: ua)

            // Extract device info
            let deviceBrand = extractDeviceBrand(from: ua)

            return BrowserUserAgentData(
                userAgent: ua,
                percent: item.weight * 100,
                type: item.deviceCategory,
                deviceBrand: deviceBrand,
                browser: browserInfo.family,
                browserVersion: browserInfo.version,
                browserVersionMajorMinor: browserInfo.versionMajorMinor,
                os: osInfo?.family,
                osVersion: osInfo?.version,
                oscpu: item.oscpu,
                platform: item.platform,
                appName: item.appName,
                connection: item.connection.map { conn in
                    BrowserUserAgentData.Connection(
                        downlink: conn.downlink,
                        effectiveType: conn.effectiveType,
                        rtt: conn.rtt
                    )
                },
                cpuClass: item.cpuClass,
                vendor: item.vendor,
                pluginsLength: item.pluginsLength,
                screenHeight: item.screenHeight,
                screenWidth: item.screenWidth,
                viewportHeight: item.viewportHeight,
                viewportWidth: item.viewportWidth
            )
        }

        private func extractBrowserInfo(from ua: String) -> (
            family: String, version: String, versionMajorMinor: Double
        )? {
            // Common browser patterns (order matters - most specific first)
            let patterns: [(name: String, regex: String)] = [
                ("Edge", #"Edg(?:e)?\/(\d+(?:\.\d+)*)"#),
                ("Opera", #"OPR\/(\d+(?:\.\d+)*)"#),
                ("Chrome", #"Chrome\/(\d+(?:\.\d+)*)"#),
                ("Firefox", #"Firefox\/(\d+(?:\.\d+)*)"#),
                ("Mobile Safari", #"Mobile.*Safari\/(\d+(?:\.\d+)*)"#),
                ("Safari", #"Version\/(\d+(?:\.\d+)*)"#),
                ("Internet Explorer", #"(?:MSIE|rv:)(\d+(?:\.\d+)*)"#),
            ]

            for (name, pattern) in patterns {
                if let regex = try? NSRegularExpression(pattern: pattern, options: []),
                    let match = regex.firstMatch(in: ua, range: NSRange(ua.startIndex..., in: ua)),
                    match.numberOfRanges > 1,
                    let versionRange = Range(match.range(at: 1), in: ua)
                {

                    let version = String(ua[versionRange])
                    let components = version.split(separator: ".").map(String.init)

                    if components.count >= 2,
                        let major = Double(components[0]),
                        let minor = Double(components[1])
                    {
                        let versionMajorMinor = major + minor / 100.0
                        return (name, version, versionMajorMinor)
                    } else if components.count >= 1,
                        let major = Double(components[0])
                    {
                        return (name, version, major)
                    }
                }
            }

            return nil
        }

        private func extractOSInfo(from ua: String) -> (family: String, version: String)? {
            let patterns: [(name: String, regex: String)] = [
                ("iOS", #"iPhone OS (\d+(?:_\d+)*)"#),
                ("Android", #"Android (\d+(?:\.\d+)*)"#),
                ("macOS", #"Mac OS X (\d+(?:[_\.]\d+)*)"#),
                ("Windows", #"Windows NT (\d+(?:\.\d+)*)"#),
                ("Linux", #"(Linux)"#),
            ]

            for (name, pattern) in patterns {
                if let regex = try? NSRegularExpression(pattern: pattern, options: []),
                    let match = regex.firstMatch(in: ua, range: NSRange(ua.startIndex..., in: ua))
                {

                    if match.numberOfRanges > 1,
                        let versionRange = Range(match.range(at: 1), in: ua)
                    {
                        let version = String(ua[versionRange]).replacingOccurrences(
                            of: "_",
                            with: "."
                        )
                        return (name, version)
                    } else {
                        return (name, "")
                    }
                }
            }

            return nil
        }

        private func extractDeviceBrand(from ua: String) -> String? {
            if ua.contains("iPhone") || ua.contains("iPad") || ua.contains("iPod") {
                return "Apple"
            } else if ua.contains("Samsung") {
                return "Samsung"
            } else if ua.contains("Pixel") {
                return "Google"
            }
            return nil
        }

        private func compressLZFSE(_ data: Data) throws -> Data {
            let sourceBuffer = [UInt8](data)
            // LZFSE can, in worst-case scenarios, expand data slightly.
            // A safe buffer size is the source size plus a small margin.
            let destinationBufferSize = sourceBuffer.count + 1024
            var destinationBuffer = [UInt8](repeating: 0, count: destinationBufferSize)

            let compressedSize = compression_encode_buffer(
                &destinationBuffer,
                destinationBufferSize,
                sourceBuffer,
                sourceBuffer.count,
                nil,
                COMPRESSION_LZFSE
            )

            guard compressedSize > 0 else {
                throw PluginError.compressionFailed
            }

            return Data(destinationBuffer.prefix(compressedSize))
        }
    }
#endif

// MARK: - Error Types

enum PluginError: Error, CustomStringConvertible {
    case invalidURL(String)
    case invalidResponse
    case httpError(Int)
    case decompressionFailed
    case conversionFailed
    case compressionFailed

    var description: String {
        switch self {
        case .invalidURL(let url):
            return "Invalid URL: \(url)"
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .decompressionFailed:
            return "Failed to decompress gzip data"
        case .conversionFailed:
            return "Failed to convert data to JSONL"
        case .compressionFailed:
            return "Failed to compress data with LZFSE"
        }
    }
}

// MARK: - Data Models

struct SourceItem: Codable {
    let userAgent: String
    let weight: Double
    let deviceCategory: String
    let platform: String
    let appName: String?
    let connection: Connection?
    let cpuClass: String?
    let oscpu: String?
    let vendor: String?
    let pluginsLength: Int?
    let screenHeight: Int?
    let screenWidth: Int?
    let viewportHeight: Int?
    let viewportWidth: Int?

    struct Connection: Codable {
        let downlink: Double?
        let effectiveType: String?
        let rtt: Int?
    }
}

struct BrowserUserAgentData: Codable {
    let userAgent: String
    let percent: Double
    let type: String
    let deviceBrand: String?
    let browser: String
    let browserVersion: String
    let browserVersionMajorMinor: Double
    let os: String?
    let osVersion: String?
    let oscpu: String?
    let platform: String
    let appName: String?
    let connection: Connection?
    let cpuClass: String?
    let vendor: String?
    let pluginsLength: Int?
    let screenHeight: Int?
    let screenWidth: Int?
    let viewportHeight: Int?
    let viewportWidth: Int?

    struct Connection: Codable {
        let downlink: Double?
        let effectiveType: String?
        let rtt: Int?

        enum CodingKeys: String, CodingKey {
            case downlink
            case effectiveType = "effective_type"
            case rtt
        }
    }

    enum CodingKeys: String, CodingKey {
        case userAgent = "user_agent"
        case percent
        case type
        case deviceBrand = "device_brand"
        case browser
        case browserVersion = "browser_version"
        case browserVersionMajorMinor = "browser_version_major_minor"
        case os
        case osVersion = "os_version"
        case oscpu
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
}
