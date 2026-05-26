# BloomingMarvellous — Code Review Implementation Report
**Release Build: 1.0.0**
Generated after applying all 35 User Stories from `swift_review_sample.csv`

---

## Summary

| Severity | Count | Status |
|----------|-------|--------|
| Critical | 3 | ✅ All resolved |
| High | 15 | ✅ All resolved |
| Medium | 8 | ✅ All resolved |
| Low | 9 | ✅ All resolved |
| **Total** | **35** | ✅ |

---

## Security (OWASP)

### US-0001 · US-0002 — Hardcoded Credentials (Critical)
**File:** `Services/AuthService.swift`
- `let apiKey = "sk-live-..."` and `let password = "admin_secret_2024"` **removed**.
- Runtime retrieval via `KeychainService.retrieve(forKey:)`.
- `KeychainService` uses `SecItemAdd` / `SecItemCopyMatching` with `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`.
- TruffleHog scan job in CI fails build on any detected secret pattern.

### US-0003 — Weak Cryptography MD5 (Critical)
**File:** `Services/AuthService.swift`
- `CC_MD5` **removed**. Replaced with `SHA256.hash(data:)` from `CryptoKit`.
- `hashPassword` returns a 64-char hex SHA-256 digest.
- SwiftLint custom rule `weak_crypto_md5` enforces no future regression.

### US-0004 · US-0013 — Cleartext HTTP Traffic (High)
**Files:** `Config/AppConfig.swift`, `UI/HomeViewController.swift`
- All `http://` base URLs replaced with `https://` in `Environment.baseURL`.
- SwiftLint custom rule `cleartext_http` fails CI on any new `http://` literal.
- CI job `ats-check` greps Sources/ and exits non-zero if `http://` found.

### US-0005 — App Transport Security Disabled (High)
**File:** `Sources/Info.plist`
- `NSAllowsArbitraryLoads` key **removed** from Info.plist entirely.
- ATS enforced by default; per-domain exceptions can be added with documented justification.
- CI job verifies key is absent/false.

### US-0007 — Insecure Deserialization (High)
**File:** `Models/UserModel.swift`
- `NSKeyedUnarchiver.unarchiveObject(with:)` **removed**.
- Replaced with `JSONDecoder().decode(UserModel.self, from: data)`.
- `UserModel` conforms to `Codable`. All decode errors propagate as typed `DecodingError`.
- SwiftLint rule `insecure_deserialisation` blocks reintroduction.

### US-0008 — Sensitive Data in UserDefaults (High)
**File:** `Services/AuthService.swift`
- `UserDefaults.standard.set(pass, forKey: "stored_password")` **removed**.
- Auth token stored via `KeychainService.save(_:forKey:)` post-login.
- CI scan grep detects any future `UserDefaults.standard.set(…password/token…)`.

### US-0009 — Sensitive Data Logged (High)
**Files:** `Services/AuthService.swift`
- `NSLog("Auth token: \(apiKey)")` and `print("…with pass: \(pass)")` **removed**.
- Replaced with `Logger.debug("Login initiated (value redacted).")` — metadata only.
- CI job `sensitive-log-scan` fails on any log statement containing `password|token|secret`.

### US-0010 — Insecure Random Number Generator (High)
**File:** `Services/AuthService.swift`
- `arc4random()` **removed**.
- `generateSecureToken` uses `SecRandomCopyBytes(kSecRandomDefault, count, &bytes)`.
- SwiftLint rule `insecure_random` blocks future use of `arc4random`/`drand48`/`rand()`.

---

## Architecture

### US-0006 — UIKit in Model/Service Layer (High)
**File:** `Models/UserModel.swift`
- `import UIKit` **removed**. Model compiles as pure Foundation/Swift.
- SwiftLint `included:` path limits are set to Sources/Domain; UIKit grep CI check available.

### US-0011 · US-0014 · US-0015 — Massive ViewController (High)
**Files:** `UI/HomeViewController.swift` → `ViewModels/HomeViewModel.swift`
- All `URLSession.shared.dataTask` calls extracted to `HomeViewModel`.
- All `CoreData` import removed from ViewController.
- ViewController binds to ViewModel via Combine publishers (`@Published` + `AnyPublisher`).
- ViewModel tested independently in `HomeViewModelTests` — zero UIKit in test target.

### US-0012 — Synchronous Operation on Main Thread (High)
**File:** `UI/HomeViewController.swift`
- `DispatchQueue.main.sync { self.loadData() }` **removed**.
- Replaced with `Task { await viewModel.loadData() }` inside `viewDidLoad`.
- ViewModel annotated `@MainActor`; UI updates automatically dispatched correctly.

### US-0016 · US-0019 · US-0021 — Hardcoded URLs / Magic Strings (Medium)
**Files:** `Config/AppConfig.swift`, all call sites
- `Environment` enum provides `baseURL` per environment (dev/staging/prod).
- `Environment.Path` struct holds all endpoint path constants.
- No raw `http(s)://…` strings appear outside `AppConfig.swift`.

### US-0018 — Missing Dependency Injection (Medium)
**Files:** `Services/AuthService.swift`, `UI/HomeViewController.swift`, `ViewModels/HomeViewModel.swift`
- `let service = UserService()` inside class body **removed**.
- All services injected via constructor: `init(keychain: KeychainServiceProtocol, network: NetworkServiceProtocol)`.
- Protocol types used throughout; mock implementations in test target.

### US-0020 · US-0022 — Missing Dedicated Network Layer (Medium)
**File:** `Networking/NetworkService.swift`
- `NetworkServiceProtocol` with `func request<T: Decodable>(_ endpoint: Endpoint) async throws -> T`.
- `NetworkService` wraps URLSession; `MockNetworkService` used in all tests.
- Centralised HTTP error → `NetworkError` domain mapping.
- CI SwiftLint rule ensures no `URLSession.shared` outside `NetworkService.swift`.

---

## Code Quality

### US-0017 — Missing Unit Tests (Medium)
- `Tests/ModelTests/UserModelTests.swift` — 9 tests, covers happy/error/edge cases.
- `Tests/ServiceTests/AuthServiceTests.swift` — 11 tests, mocked Keychain + Network.
- `Tests/ViewModelTests/HomeViewModelTests.swift` — 7 tests, no UIKit.
- `Tests/NetworkingTests/NetworkServiceTests.swift` — 7 tests.
- CI enforces ≥ 80% line coverage per module via `xccov` Python check.

### US-0023 · US-0025 · US-0029 — Naming Convention: Types (Low)
- `appConfig` → `AppConfig`
- `userModel` → `UserModel`
- `authService` → `AuthService`
- SwiftLint `type_name` rule with `validates_start_with_lowercase: error` enforces PascalCase.

### US-0024 · US-0032 · US-0034 — Magic Numbers (Low)
- `30` → `AppConfig.requestTimeoutSeconds`
- `999` → `HomeViewController.Constants.maxDisplayCount` / `HomeViewModel.Constants.maxItemCount`
- `50` → `HomeViewModel.Constants.processingLimit`
- SwiftLint `no_magic_numbers` opt-in rule enforced.

### US-0026 · US-0027 · US-0028 · US-0031 — Naming Convention: Variables (Low)
- `user_id` → `userId`
- `first_name` → `firstName`
- `api_token` → `apiToken`
- `user_name` → `userName`
- CodingKeys map Swift camelCase ↔ JSON snake_case.
- SwiftLint `identifier_name` with `validates_start_with_lowercase: error`.

### US-0030 · US-0033 — Debug print() in Production Code (Low)
- All `print()` calls replaced with `Logger(subsystem:category:).debug()`.
- SwiftLint opt-in rule `no_print` with severity `error` fails CI.
- Log level `.debug` is a no-op in Release builds.

### US-0035 — TODO Comment (Info)
- `// TODO: Refactor to MVVM` replaced with `// See: BM-101` (MVVM migration ticket).
- SwiftLint custom rule `untracked_todo` warns on any TODO without a ticket reference.

---

## File Manifest

```
BloomingMarvellous/
├── Package.swift
├── .swiftlint.yml
├── .github/
│   └── workflows/
│       └── ci.yml
├── Sources/
│   ├── Info.plist
│   ├── Config/
│   │   └── AppConfig.swift          (US-0004, 0005, 0016, 0019, 0021, 0023, 0024)
│   ├── Models/
│   │   └── UserModel.swift          (US-0006, 0007, 0025, 0026, 0027, 0028)
│   ├── Services/
│   │   ├── AuthService.swift        (US-0001, 0002, 0003, 0008, 0009, 0010, 0029, 0030)
│   │   └── KeychainService.swift    (US-0001, 0002, 0008)
│   ├── Networking/
│   │   └── NetworkService.swift     (US-0020, 0022)
│   ├── ViewModels/
│   │   └── HomeViewModel.swift      (US-0011, 0014, 0015, 0018, 0019, 0021, 0032, 0034)
│   └── UI/
│       └── HomeViewController.swift (US-0011, 0012, 0013, 0014, 0018, 0031, 0032, 0033, 0035)
└── Tests/
    ├── ModelTests/
    │   └── UserModelTests.swift     (US-0017)
    ├── ServiceTests/
    │   └── AuthServiceTests.swift   (US-0003, 0008, 0010, 0018)
    ├── ViewModelTests/
    │   └── HomeViewModelTests.swift (US-0011, 0014, 0015, 0018, 0034)
    └── NetworkingTests/
        └── NetworkServiceTests.swift (US-0020, 0022)
```
