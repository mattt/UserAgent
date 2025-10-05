import struct Foundation.IndexSet

/// An actor that manages user agent data storage and retrieval.
///
/// `Store` provides thread-safe access to the user agent database, with optimized lookups
/// using pre-built indices for common query patterns.
actor Store {
    private let loader = Loader()
    private var entries: [Entry]?
    private var indices: Indices?

    /// Index structures for fast lookups by common criteria.
    struct Indices {
        /// Index mapping browser kinds to entry positions.
        var byBrowser: [Browser.Kind: IndexSet]

        /// Index mapping device categories to entry positions.
        var byCategory: [Device.Category: IndexSet]

        /// Index mapping platform names to entry positions.
        var byPlatform: [String: IndexSet]

        /// Index mapping OS names to entry positions.
        var byOS: [String: IndexSet]

        /// Index mapping vendor names to entry positions.
        var byVendor: [String: IndexSet]

        /// Index mapping screen sizes to entry positions.
        var byScreenSize: [Size: IndexSet]

        /// Index mapping viewport sizes to entry positions.
        var byViewportSize: [Size: IndexSet]

        /// Index mapping connection types to entry positions.
        var byConnectionType: [String: IndexSet]
    }

    /// Retrieves a random user agent string matching the optional predicate.
    ///
    /// - Parameter predicate: An optional predicate to filter user agents.
    /// - Returns: A random user agent string.
    /// - Throws: ``UserAgentError/noBrowsersAvailable`` if no matching user agents exist.
    func random(matching predicate: Predicate?) async throws -> String {
        let entry = try await randomEntry(matching: predicate)
        return entry.userAgent
    }

    /// Retrieves multiple random user agent strings matching the optional predicate.
    ///
    /// - Parameters:
    ///   - count: The number of user agents to retrieve.
    ///   - predicate: An optional predicate to filter user agents.
    /// - Returns: An array of random user agent strings.
    /// - Throws: ``UserAgentError/noBrowsersAvailable`` if no matching user agents exist.
    func randomSample(count: Int, matching predicate: Predicate?) async throws -> [String] {
        let entries = try await randomEntries(count: count, matching: predicate)
        return entries.map { $0.userAgent }
    }

    /// Retrieves a random entry matching the optional predicate.
    private func randomEntry(matching predicate: Predicate?) async throws -> Entry {
        let pool = try await getPool(matching: predicate)

        guard !pool.isEmpty else {
            throw UserAgentError.noBrowsersAvailable
        }

        return pool.randomElement()!
    }

    /// Retrieves multiple random entries matching the optional predicate.
    private func randomEntries(count: Int, matching predicate: Predicate?) async throws -> [Entry] {
        let pool = try await getPool(matching: predicate)

        guard !pool.isEmpty else {
            throw UserAgentError.noBrowsersAvailable
        }

        return (0 ..< count).map { _ in pool.randomElement()! }
    }

    /// Gets the pool of entries matching the predicate, using indices when possible.
    private func getPool(matching predicate: Predicate?) async throws -> [Entry] {
        try await ensureLoaded()

        guard let predicate = predicate else {
            return entries!
        }

        if let indexSet = try indexSet(for: predicate) {
            return indexSet.map { entries![$0] }
        } else {
            return entries!.filter { predicate.matches($0) }
        }
    }

    /// Ensures the user agent data is loaded from disk and indices are built.
    private func ensureLoaded() async throws {
        guard entries == nil else { return }

        let loadedEntries = try await loader.loadData()

        guard !loadedEntries.isEmpty else {
            throw UserAgentError.noBrowsersAvailable
        }

        entries = loadedEntries
        indices = buildIndices(for: loadedEntries)
    }

    /// Builds index structures for efficient lookups.
    ///
    /// - Parameter entries: The entries to index.
    /// - Returns: An `Indices` structure containing all index maps.
    private func buildIndices(for entries: [Entry]) -> Indices {
        var byBrowser: [Browser.Kind: IndexSet] = [:]
        var byCategory: [Device.Category: IndexSet] = [:]
        var byPlatform: [String: IndexSet] = [:]
        var byOS: [String: IndexSet] = [:]
        var byVendor: [String: IndexSet] = [:]
        var byScreenSize: [Size: IndexSet] = [:]
        var byViewportSize: [Size: IndexSet] = [:]
        var byConnectionType: [String: IndexSet] = [:]

        for (index, entry) in entries.enumerated() {
            byBrowser[entry.browser.kind, default: IndexSet()].insert(index)

            byCategory[entry.device.category, default: IndexSet()].insert(index)

            let platform = entry.platform.lowercased()
            byPlatform[platform, default: IndexSet()].insert(index)

            if let osName = entry.os.name {
                let os = osName.lowercased()
                byOS[os, default: IndexSet()].insert(index)
            }

            if let vendor = entry.vendor {
                let vendorKey = vendor.lowercased()
                byVendor[vendorKey, default: IndexSet()].insert(index)
            }

            if let screenSize = entry.screenSize {
                byScreenSize[screenSize, default: IndexSet()].insert(index)
            }

            if let viewportSize = entry.viewportSize {
                byViewportSize[viewportSize, default: IndexSet()].insert(index)
            }

            if let connectionType = entry.connection?.effectiveType {
                let typeKey = connectionType.lowercased()
                byConnectionType[typeKey, default: IndexSet()].insert(index)
            }
        }

        return Indices(
            byBrowser: byBrowser,
            byCategory: byCategory,
            byPlatform: byPlatform,
            byOS: byOS,
            byVendor: byVendor,
            byScreenSize: byScreenSize,
            byViewportSize: byViewportSize,
            byConnectionType: byConnectionType
        )
    }

    /// Attempts to use indices to quickly resolve a predicate to an index set.
    ///
    /// Returns `nil` if the predicate requires linear scanning (e.g., custom predicates).
    ///
    /// - Parameter predicate: The predicate to resolve.
    /// - Returns: An optional `IndexSet` of matching entry positions.
    private func indexSet(for predicate: Predicate) throws -> IndexSet? {
        guard let indices = indices else { return nil }

        switch predicate {
        case .browser(let kind):
            return indices.byBrowser[kind] ?? IndexSet()

        case .device(let category):
            return indices.byCategory[category] ?? IndexSet()

        case .platform(let platform):
            return indices.byPlatform[platform.lowercased()] ?? IndexSet()

        case .os(let name):
            let osName = name.lowercased()
            var result = IndexSet()
            for (key, indexSet) in indices.byOS where key.contains(osName) {
                result.formUnion(indexSet)
            }
            return result

        case .vendor(let vendor):
            return indices.byVendor[vendor.lowercased()] ?? IndexSet()

        case .screenSize(let size):
            return indices.byScreenSize[size] ?? IndexSet()

        case .viewportSize(let size):
            return indices.byViewportSize[size] ?? IndexSet()

        case .connectionType(let type):
            return indices.byConnectionType[type.lowercased()] ?? IndexSet()

        case .and(let lhs, let rhs):
            guard let lhsSet = try indexSet(for: lhs),
                let rhsSet = try indexSet(for: rhs)
            else {
                return nil
            }
            return lhsSet.intersection(rhsSet)

        case .or(let lhs, let rhs):
            guard let lhsSet = try indexSet(for: lhs),
                let rhsSet = try indexSet(for: rhs)
            else {
                return nil
            }
            return lhsSet.union(rhsSet)

        case .not(let inner):
            guard let innerSet = try indexSet(for: inner) else {
                return nil
            }
            let all = IndexSet(integersIn: 0 ..< entries!.count)
            return all.subtracting(innerSet)

        case .custom:
            return nil
        }
    }
}
