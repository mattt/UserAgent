import struct Foundation.Data
import class Foundation.JSONDecoder
import Testing

@testable import UserAgent

@Suite("UserAgent Tests")
struct UserAgentTests {

    @Test("Random user agent returns valid string")
    func randomUserAgent() async throws {
        let userAgent = try await UserAgent.random()

        #expect(!userAgent.isEmpty)
        #expect(userAgent.contains("Mozilla") || userAgent.contains("Opera"))
    }

    @Test("Random user agent for specific browser")
    func randomUserAgentForBrowser() async throws {
        for browserKind in Browser.Kind.allCases {
            let userAgent = try await UserAgent.random(matching: .browser(browserKind))
            #expect(!userAgent.isEmpty)
        }
    }

    @Test("Random sample returns multiple user agents")
    func randomSample() async throws {
        let userAgents = try await UserAgent.randomSample(count: 10)

        #expect(userAgents.count == 10)
        for userAgent in userAgents {
            #expect(!userAgent.isEmpty)
        }
    }

    @Test("Random sample for specific browser")
    func randomSampleForBrowser() async throws {
        let chromeAgents = try await UserAgent.randomSample(count: 5, matching: .browser(.chrome))

        #expect(chromeAgents.count == 5)
        for userAgent in chromeAgents {
            #expect(!userAgent.isEmpty)
            #expect(userAgent.contains("Chrome"))
        }
    }

    @Test("Random returns different user agents (probabilistic)")
    func randomReturnsDifferentUserAgents() async throws {
        var userAgents = Set<String>()

        for _ in 0 ..< 100 {
            let userAgent = try await UserAgent.random()
            userAgents.insert(userAgent)
        }

        #expect(userAgents.count > 1)
    }

    @Test("Multiple calls work correctly")
    func multipleCalls() async throws {
        let first = try await UserAgent.random()
        let second = try await UserAgent.random()
        let entries = try await UserAgent.randomSample(count: 5)

        #expect(!first.isEmpty)
        #expect(!second.isEmpty)
        #expect(entries.count == 5)
    }
}

@Suite("Predicate Tests")
struct PredicateTests {

    @Test("Predicate browser filter")
    func browserPredicate() async throws {
        let userAgent = try await UserAgent.random(matching: .browser(.chrome))

        #expect(!userAgent.isEmpty)
        #expect(userAgent.contains("Chrome"))
    }

    @Test("Predicate mobile filter")
    func mobilePredicate() async throws {
        let userAgent = try await UserAgent.random(matching: .mobile)

        #expect(!userAgent.isEmpty)
    }

    @Test("Predicate desktop filter")
    func desktopPredicate() async throws {
        let userAgent = try await UserAgent.random(matching: .desktop)

        #expect(!userAgent.isEmpty)
    }

    @Test("Predicate AND operator")
    func andOperator() async throws {
        let userAgent = try await UserAgent.random(matching: .mobile && .browser(.safari))

        #expect(!userAgent.isEmpty)
        #expect(userAgent.contains("Safari") || userAgent.contains("Mobile"))
    }

    @Test("Predicate OR operator")
    func orOperator() async throws {
        let userAgent = try await UserAgent.random(
            matching: .browser(.chrome) || .browser(.firefox)
        )

        #expect(!userAgent.isEmpty)
        #expect(userAgent.contains("Chrome") || userAgent.contains("Firefox"))
    }

    @Test("Predicate NOT operator")
    func notOperator() async throws {
        let userAgent = try await UserAgent.random(matching: !.browser(.chrome))

        #expect(!userAgent.isEmpty)
    }

    @Test("Predicate OS filter")
    func osPredicate() async throws {
        let userAgent = try await UserAgent.random(matching: .os("windows"))

        #expect(!userAgent.isEmpty)
    }

    @Test("Complex predicate combination")
    func complexPredicate() async throws {
        let predicate: Predicate = (.mobile && .browser(.safari)) || (.desktop && .browser(.chrome))
        let userAgent = try await UserAgent.random(matching: predicate)

        #expect(!userAgent.isEmpty)
    }

    @Test("Random sample with predicate")
    func randomSampleWithPredicate() async throws {
        let userAgents = try await UserAgent.randomSample(count: 10, matching: .browser(.firefox))

        #expect(userAgents.count == 10)
        for userAgent in userAgents {
            #expect(!userAgent.isEmpty)
            #expect(userAgent.contains("Firefox"))
        }
    }

    @Test("Random sample with complex predicate")
    func randomSampleWithComplexPredicate() async throws {
        let userAgents = try await UserAgent.randomSample(
            count: 5,
            matching: .mobile && .browser(.safari)
        )

        #expect(userAgents.count == 5)
        for userAgent in userAgents {
            #expect(!userAgent.isEmpty)
        }
    }

    @Test("Predicate vendor filter", .enabled(if: false))
    func vendorPredicate() async throws {
        // Note: This test requires regenerated data with vendor field populated
        let userAgent = try await UserAgent.random(matching: .vendor("Google Inc."))

        #expect(!userAgent.isEmpty)
    }

    @Test("Predicate screen size filter", .enabled(if: false))
    func screenSizePredicate() async throws {
        // Note: This test requires regenerated data with screen size fields populated
        let userAgent = try await UserAgent.random(
            matching: .screenSize(Size(width: 1920, height: 1080))
        )

        #expect(!userAgent.isEmpty)
    }

    @Test("Predicate viewport size filter", .enabled(if: false))
    func viewportSizePredicate() async throws {
        // Note: This test requires regenerated data with viewport size fields populated
        let userAgent = try await UserAgent.random(
            matching: .viewportSize(Size(width: 1920, height: 1080))
        )

        #expect(!userAgent.isEmpty)
    }

    @Test("Predicate connection type filter", .enabled(if: false))
    func connectionTypePredicate() async throws {
        // Note: This test requires regenerated data with connection type field populated
        let userAgent = try await UserAgent.random(matching: .connectionType("4g"))

        #expect(!userAgent.isEmpty)
    }

    @Test("Custom predicate with Entry")
    func customPredicateWithEntry() async throws {
        let userAgent = try await UserAgent.random(
            matching: .custom { entry in
                entry.browser.version >= Version("100.0")!
            }
        )

        #expect(!userAgent.isEmpty)
    }

    @Test("Custom predicate accessing new fields", .enabled(if: false))
    func customPredicateNewFields() async throws {
        // Note: This test requires regenerated data with screen size fields populated
        let userAgent = try await UserAgent.random(
            matching: .custom { entry in
                entry.screenSize != nil
            }
        )

        #expect(!userAgent.isEmpty)
    }

    @Test("Custom predicate with connection info", .enabled(if: false))
    func customPredicateConnectionInfo() async throws {
        // Note: This test requires regenerated data with connection field populated
        let userAgent = try await UserAgent.random(
            matching: .custom { entry in
                entry.connection?.effectiveType != nil
            }
        )

        #expect(!userAgent.isEmpty)
    }

    @Test("Complex predicate with new fields", .enabled(if: false))
    func complexPredicateWithNewFields() async throws {
        // Note: This test requires regenerated data with all new fields populated
        let predicate: Predicate = .mobile && .connectionType("4g") && .vendor("Google Inc.")
        let userAgent = try await UserAgent.random(matching: predicate)

        #expect(!userAgent.isEmpty)
    }

    @Test("Vendor predicate combined with browser", .enabled(if: false))
    func vendorAndBrowserPredicate() async throws {
        // Note: This test requires regenerated data with vendor field populated
        let userAgent = try await UserAgent.random(
            matching: .vendor("Google Inc.") && .browser(.chrome)
        )

        #expect(!userAgent.isEmpty)
    }
}

@Suite("Entry Field Tests")
struct EntryFieldTests {

    @Test(
        "Safari browser labels preserve the device category",
        arguments: [
            ("Mobile Safari", Device.Category.mobile),
            ("Mobile Safari", .tablet),
            ("Safari", .desktop),
        ]
    )
    func safariBrowserLabels(label: String, category: Device.Category) throws {
        let json = """
            {
                "user_agent": "fixture", "percent": 1, "type": "\(category.rawValue)", "platform": "test",
                "browser": "\(label)", "browser_version": "17.2", "browser_version_major_minor": 17.2
            }
            """
        let entry = try JSONDecoder().decode(Entry.self, from: Data(json.utf8))

        #expect(entry.browser.kind == .safari)
        #expect(entry.device.category == category)
    }

    @Test("Entry contains all required fields")
    func entryRequiredFields() async throws {
        let store = Store()
        let userAgent = try await store.random(matching: nil)

        #expect(!userAgent.isEmpty)
    }

    @Test("Entry fields are accessible via custom predicate")
    func entryFieldAccess() async throws {
        let userAgent = try await UserAgent.random(
            matching: .custom { entry in
                #expect(entry.userAgent.count > 0)
                #expect(entry.percent >= 0)
                #expect(entry.platform.count > 0)
                return true
            }
        )

        #expect(!userAgent.isEmpty)
    }

    @Test("Connection field structure")
    func connectionFieldStructure() async throws {
        let userAgent = try await UserAgent.random(
            matching: .custom { entry in
                if let connection = entry.connection {
                    _ = connection.downlink
                    _ = connection.effectiveType
                    _ = connection.rtt
                    return true
                }
                return true
            }
        )

        #expect(!userAgent.isEmpty)
    }

    @Test("Screen and viewport dimensions")
    func screenAndViewportDimensions() async throws {
        let userAgent = try await UserAgent.random(
            matching: .custom { entry in
                if let screenSize = entry.screenSize {
                    #expect(screenSize.width > 0)
                    #expect(screenSize.height > 0)
                }
                if let viewportSize = entry.viewportSize {
                    #expect(viewportSize.width > 0)
                    #expect(viewportSize.height > 0)
                }
                return true
            }
        )

        #expect(!userAgent.isEmpty)
    }

    @Test("Optional fields are properly typed")
    func optionalFieldsTyping() async throws {
        let userAgent = try await UserAgent.random(
            matching: .custom { entry in
                _ = entry.appName as String?
                _ = entry.connection as Entry.Connection?
                _ = entry.cpuClass as String?
                _ = entry.vendor as String?
                _ = entry.pluginsLength as Int?
                _ = entry.os.oscpu as String?
                return true
            }
        )

        #expect(!userAgent.isEmpty)
    }

    @Test("OS oscpu field")
    func osOscpuField() async throws {
        let userAgent = try await UserAgent.random(
            matching: .custom { entry in
                _ = entry.os.oscpu as String?
                return true
            }
        )

        #expect(!userAgent.isEmpty)
    }

    @Test("Browser version structure")
    func browserVersionStructure() async throws {
        let userAgent = try await UserAgent.random(
            matching: .custom { entry in
                let version = entry.browser.version
                #expect(version.major >= 0)
                #expect(version.minor >= 0)
                #expect(!version.string.isEmpty)
                return true
            }
        )

        #expect(!userAgent.isEmpty)
    }

    @Test("Version comparison")
    func versionComparison() {
        let v100_0 = Version("100.0")!
        let v100_5 = Version("100.5")!
        let v100_12 = Version("100.12")!
        let v101_0 = Version("101.0")!

        // Test proper lexicographic ordering
        #expect(v100_5 < v100_12)  // 100.5 < 100.12 (correct!)
        #expect(v100_0 < v100_5)
        #expect(v100_12 < v101_0)
        #expect(v100_0 < v101_0)
    }

    @Test("Version parsing")
    func versionParsing() {
        // Valid versions
        let v1 = Version("121.0.6167.85")
        #expect(v1?.major == 121)
        #expect(v1?.minor == 0)
        #expect(v1?.string == "121.0.6167.85")

        let v2 = Version("17.2.1")
        #expect(v2?.major == 17)
        #expect(v2?.minor == 2)

        let v3 = Version("100")
        #expect(v3?.major == 100)
        #expect(v3?.minor == 0)

        // Invalid versions
        #expect(Version("invalid") == nil)
        #expect(Version("") == nil)
        #expect(Version("abc.def") == nil)
    }

    @Test("OS version is Version type")
    func osVersionType() async throws {
        let userAgent = try await UserAgent.random(
            matching: .custom { entry in
                if let osVersion = entry.os.version {
                    #expect(osVersion.major >= 0)
                    #expect(osVersion.minor >= 0)
                    #expect(!osVersion.string.isEmpty)
                }
                return true
            }
        )

        #expect(!userAgent.isEmpty)
    }
}
