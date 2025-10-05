# UserAgent

A Swift package that generates user agent strings for various browsers.

## Requirements

- Swift 6.0+

## Installation

### Swift Package Manager

Add the following dependency to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/mattt/UserAgent.git", from: "1.0.0")
]
```

## Usage

### Basic Usage

```swift
import UserAgent

// Get a random user agent
let userAgent = try await UserAgent.random()
print(userAgent) // e.g. "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.6 Safari/605.1.15"
```

### Filtering with Predicates

Get user agents matching specific criteria using predicates:

```swift
// Get a random user agent for a specific browser
let chrome = try await UserAgent.random(matching: .browser(.chrome))

// Get a mobile user agent
let mobile = try await UserAgent.random(matching: .mobile)

// Get a desktop user agent
let desktop = try await UserAgent.random(matching: .desktop)

// Filter by OS
let windows = try await UserAgent.random(matching: .os("windows"))

// Filter by platform (navigator.platform-style values)
let mac = try await UserAgent.random(matching: .platform("MacIntel"))
let windows = try await UserAgent.random(matching: .platform("Win32"))
let linuxX64 = try await UserAgent.random(matching: .platform("Linux x86_64"))
let linuxArm = try await UserAgent.random(matching: .platform("Linux armv81"))
```

### Combining Predicates

Predicates can be combined using logical operators:

```swift
// Mobile Safari
let mobileSafari = try await UserAgent.random(
    matching: .mobile && .browser(.safari)
)

// Chrome on Windows
let chromeWindows = try await UserAgent.random(
    matching: .browser(.chrome) && .os("windows")
)

// Desktop Chrome or Firefox
let desktopBrowsers = try await UserAgent.random(
    matching: .desktop && (.browser(.chrome) || .browser(.firefox))
)

// Not Chrome
let notChrome = try await UserAgent.random(matching: !.browser(.chrome))
```

### Getting Multiple User Agents

```swift
// Get multiple random user agents
let userAgents = try await UserAgent.randomSample(count: 10)

// Get multiple user agents matching a predicate
let chromeUAs = try await UserAgent.randomSample(
    count: 5,
    matching: .browser(.chrome)
)

// Multiple mobile Safari user agents
let mobileSafariUAs = try await UserAgent.randomSample(
    count: 10,
    matching: .mobile && .browser(.safari)
)
```

### Custom Predicates

For advanced filtering, use custom predicates:

```swift
// Filter by custom logic (uses rejection sampling)
let customUA = try await UserAgent.random(
    matching: .custom { entry in
        entry.browser.version >= Version("120.0")!
    }
)

// Combine custom predicates with built-in ones
let recentChrome = try await UserAgent.random(
    matching: .browser(.chrome) && .custom { entry in
        entry.browser.version >= Version("120.0")!
    }
)
```

> Note: OS strings often mirror browser `Navigator.oscpu` values. See MDN: `https://developer.mozilla.org/en-US/docs/Web/API/Navigator/oscpu`.

## Updating Browser Data

The package includes a Swift Package Manager command plugin to download and process
the latest browser user agent data from
[github.com/intoli/user-agents](https://github.com/intoli/user-agents).

### Quick Update

```shell
swift package \
    --allow-writing-to-package-directory \
    --allow-network-connections all \
    update-browser-data
```

Running the plugin does the following:

1. Downloads the latest browser data from the fake-useragent repository
2. Converts it to JSON Lines format
3. Compresses it using [LZFSE](https://developer.apple.com/documentation/compression/algorithm/lzfse)
4. Saves it to `Sources/UserAgent/Resources/browsers.jsonl.lzfse`

> [!NOTE]
> Why the Flags?
> The plugin requires two permissions:
>
> - `--allow-writing-to-package-directory`: To write the updated data file
> - `--allow-network-connections all`: To download data from GitHub
>
> These are security features built into Swift Package Manager to ensure plugins can't perform unexpected actions.

### Data Format

The browser data is stored as a compressed JSON Lines (JSONL) file.
Each line represents a browser entry:

```json
{"browser":"chrome","user_agent":"Mozilla/5.0...","version":"120.0","os":"Windows","platform":"desktop"}
{"browser":"firefox","user_agent":"Mozilla/5.0...","version":"121.0","os":"macOS","platform":"desktop"}
```

## License

UserAgent is available under the MIT license.
See the [LICENSE](LICENSE) file for more info.

## Credits

This package's browser data is derived from
[User-Agents](https://github.com/intoli/user-agents),
which is licensed under a BSD 2-Clause License and is copyright Intoli, LLC.
