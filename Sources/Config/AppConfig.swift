import Foundation

// MARK: - AppConfig (US-0023: PascalCase renamed from appConfig)
// US-0005: NSAllowsArbitraryLoads removed — enforced via Info.plist
// US-0001/US-0002: secretKey removed — stored in Keychain (see KeychainService)

struct AppConfig {

    // MARK: - Timeouts & Retry (US-0024: named constants, no magic numbers)
    static let requestTimeoutSeconds: TimeInterval = 30
    static let resourceTimeoutSeconds: TimeInterval = 60
    static let maxRetryCount: Int = 3

    // MARK: - Build Environment
    static var current: Environment {
#if DEBUG
        return .development
#elseif STAGING
        return .staging
#else
        return .production
#endif
    }
}

// MARK: - Environment (US-0016 / US-0019 / US-0021: centralised URLs, HTTPS enforced)
// US-0004 / US-0013: All URLs use https://
//
// Hostnames:
//   development → api-dev.brawpatch.com    (live once custom_domain_enabled=true in dev tfvars)
//   staging     → api-staging.brawpatch.com (reserved; no staging env deployed yet)
//   production  → api.brawpatch.com         (live once custom_domain_enabled=true in prod tfvars)
//
// Before the brawpatch.com nameservers are pointed at Route 53, each env's
// CloudFront distribution still answers on its *.cloudfront.net hostname;
// supply that via `BM_API_BASE_URL` (Info.plist or scheme env var) to override
// at run time without recompiling.
enum Environment {
    case development
    case staging
    case production

    /// Base URL for the REST API. All environments enforce HTTPS (US-0004, US-0013).
    var baseURL: URL {
        if let override = ProcessInfo.processInfo.environment["BM_API_BASE_URL"]
            .flatMap(URL.init(string:)) {
            return override
        }
        switch self {
        case .development:
            // swiftlint:disable:next force_unwrap
            return URL(string: "https://api-dev.brawpatch.com/v1")!
        case .staging:
            // swiftlint:disable:next force_unwrap
            return URL(string: "https://api-staging.brawpatch.com/v1")!
        case .production:
            // swiftlint:disable:next force_unwrap
            return URL(string: "https://api.brawpatch.com/v1")!
        }
    }

    // MARK: - Endpoint paths (US-0016 / US-0019 / US-0021: no raw strings at call sites)
    enum Path {
        static let home  = "/home"
        static let data  = "/data"
        static let login = "/auth/login"
    }
}
